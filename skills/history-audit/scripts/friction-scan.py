#!/usr/bin/env python3
"""Count failed tool calls in this machine's agent-session history.

Deterministic, stdlib only, no model reads anything. Scans Claude Code
transcripts in every Claude Code config dir (`~/.claude*` with a `projects/`
folder, plus $CLAUDE_CONFIG_DIR; main sessions and subagent files) and Codex
rollouts (~/.codex/sessions/**/rollout-*.jsonl) for tool results the harness
marked as failures, buckets them by cause, and prints a markdown report with
counts per harness (one row group per Claude config dir), lane
(main/subagent) and model, plus a few dated pointers per bucket so a reader
can open the source. Error text is truncated to its first line and
credential-shaped strings are masked before printing.

Usage: friction-scan.py [--days N] [--examples N] [--claude-dir PATH]... [--exclude REGEX]
  --days        window, counted back from now on content timestamps (default 14)
  --examples    pointers printed per bucket (default 3)
  --claude-dir  a Claude Code config dir to scan; repeatable; replaces the default discovery
  --exclude     skip Claude project dirs whose name matches (case-insensitive)

A corpus that does not exist is reported as absent, never as zero failures.
Codex has no is_error flag: a call output whose first line is "Script failed"
or "exit=<nonzero>" counts, everything else does not (heuristic, stated in
the report). Hooks that fired without blocking leave no error in transcripts
and are not counted.
"""
import argparse
import collections
import datetime as dt
import glob
import json
import os
import re
import hashlib
import socket
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from redact import redact  # noqa: E402

HOME = os.path.expanduser("~")
UTC = dt.timezone.utc

CC_BUCKETS = [
    ("hook-block", re.compile(r"^(PreToolUse|PostToolUse|Stop|UserPromptSubmit):?\w* hook error")),
    ("automode-denied", re.compile(r"denied by the Claude Code auto mode")),
    ("user-denied", re.compile(r"The user doesn't want to proceed")),
    ("read-before-edit", re.compile(r"(File has not been read yet|File must be read first)")),
    ("edit-mismatch", re.compile(r"(String to replace not found|Found \d+ matches of the string)")),
    ("modified-since-read", re.compile(r"File has been modified since read")),
    ("read-directory", re.compile(r"EISDIR")),
    ("file-not-found", re.compile(r"(File does not exist|ENOENT)")),
    ("schema-mismatch", re.compile(r"Output does not match required schema")),
    ("blocked-command", re.compile(r"<tool_use_error>Blocked:")),
    ("worktree-isolation", re.compile(r"This session is isolated in the worktree")),
    ("symlink-refused", re.compile(r"Refusing to write through symlink")),
    ("exit-code", re.compile(r"^Exit code (\d+)")),
]
HOOK_NAME = re.compile(r"hooks/([\w-]+)\.sh")


NOISE = ("Script failed", "Script error:", "Wall time", "Output:")


def first_line(text, n=110):
    """First non-empty line, masked over the whole text before the line is chosen."""
    for line in redact(text).split("\n"):
        line = line.strip()
        if line:
            return line[:n]
    return ""


def context_line(text, n=110):
    """First line plus the next informative one, for exit codes and script failures."""
    lines = [l.strip() for l in redact(text).split("\n") if l.strip() and not l.startswith(NOISE)]
    return " | ".join(lines[:2])[:n]


def tool_result_text(block):
    content = block.get("content")
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        return "\n".join(x["text"] for x in content
                         if isinstance(x, dict) and isinstance(x.get("text"), str))
    return ""


def bucket_cc(text):
    for name, rx in CC_BUCKETS:
        m = rx.search(text)
        if m:
            if name == "hook-block":
                h = HOOK_NAME.search(text)
                return "hook-block:" + (h.group(1) if h else "unknown")
            if name == "exit-code":
                return "exit-code:" + m.group(1)
            return name
    return "other:" + first_line(text, 60)


def parse_ts(value):
    if not isinstance(value, str):
        return None
    try:
        t = dt.datetime.fromisoformat(value.replace("Z", "+00:00"))
        return (t if t.tzinfo else t.replace(tzinfo=UTC)).astimezone(UTC)
    except (ValueError, OverflowError):
        return None


def claude_dirs(given):
    """(label, path) per distinct Claude Code config dir holding projects/; labels made unique."""
    candidates = list(given) or sorted(glob.glob(os.path.join(HOME, ".claude*"))) + (
        [os.environ["CLAUDE_CONFIG_DIR"]] if os.environ.get("CLAUDE_CONFIG_DIR") else [])
    seen, out, labels = set(), [], collections.Counter()
    for d in candidates:
        real = os.path.realpath(os.path.expanduser(d))
        if real in seen or not os.path.isdir(os.path.join(real, "projects")):
            continue
        seen.add(real)
        out.append([os.path.basename(os.path.normpath(real)).lstrip(".") or "claude", real])
        labels[out[-1][0]] += 1
    for item in out:
        if labels[item[0]] > 1:
            item[0] += "-" + hashlib.sha1(item[1].encode()).hexdigest()[:6]
    return [tuple(x) for x in out]


def scan_cc(harness, config_dir, cutoff, stats, exclude):
    """(files on disk, files scanned after --exclude), or None when no transcript exists."""
    root = os.path.join(config_dir, "projects")
    on_disk = glob.glob(os.path.join(root, "**", "*.jsonl"), recursive=True)
    if not on_disk:
        return None
    files = [f for f in on_disk
             if not (exclude and exclude.search(os.path.relpath(f, root).split(os.sep)[0]))]
    for path in files:
        base = os.path.basename(path)
        sub = base.startswith("agent-") or f"{os.sep}subagents{os.sep}" in path
        lane = "subagent" if sub else "main"
        project = os.path.relpath(path, root).split(os.sep)[0].split("-")[-1] or "?"
        model = "?"
        tool_by_id = {}
        with open(path, encoding="utf-8", errors="ignore") as fh:
            for line in fh:
                if '"tool_use"' not in line and '"tool_result"' not in line:
                    continue
                try:
                    d = json.loads(line)
                except ValueError:
                    continue
                if not isinstance(d, dict):
                    continue
                t = parse_ts(d.get("timestamp"))
                if t is None or t < cutoff:
                    continue
                ts = t.strftime("%Y-%m-%dT%H:%M")
                m = d.get("message")
                if not isinstance(m, dict) or not isinstance(m.get("content"), list):
                    continue
                if isinstance(m.get("model"), str) and m["model"]:
                    model = m["model"]
                for b in m["content"]:
                    if not isinstance(b, dict):
                        continue
                    if b.get("type") == "tool_use":
                        stats["parsed"][harness].add(path)
                        tid, name = b.get("id"), b.get("name")
                        if not isinstance(name, str):
                            stats["rejected"]["tool name"] += 1
                            name = "?"
                        if isinstance(tid, str):
                            tool_by_id[tid] = name
                        else:
                            stats["rejected"]["tool id"] += 1
                        stats["calls"][(harness, lane, model)] += 1
                        stats["sessions"][(harness, lane, model)].add(path)
                    elif b.get("type") == "tool_result" and b.get("is_error"):
                        text = tool_result_text(b)
                        ref = b.get("tool_use_id")
                        if not isinstance(ref, str):
                            stats["rejected"]["tool_use_id"] += 1
                        tool = tool_by_id.get(ref, "?") if isinstance(ref, str) else "?"
                        key = bucket_cc(text)
                        stats["errors"][key][(harness, lane, model)] += 1
                        stats["tools"][key][tool] += 1
                        ex = stats["examples"][key]
                        if len(ex) < 50:
                            ex.append((ts[:16], project, lane, base[:20], context_line(text)))
    return (len(on_disk), len(files))


CODEX_FAIL = re.compile(r"^(Script failed|exit=[1-9]\d*|Process exited with code [1-9]\d*)")


def scan_codex(cutoff, stats):
    """Session metadata is read whatever its time; only timestamped activity in the window counts."""
    root = os.path.join(HOME, ".codex", "sessions")
    files = glob.glob(os.path.join(root, "**", "rollout-*.jsonl"), recursive=True)
    if not files:
        return None
    for path in files:
        base = os.path.basename(path)
        lane, model, project = "main", "?", "?"
        with open(path, encoding="utf-8", errors="ignore") as fh:
            for line in fh:
                try:
                    d = json.loads(line)
                except ValueError:
                    continue
                if not isinstance(d, dict):
                    continue
                rt = parse_ts(d.get("timestamp"))
                in_window = rt is not None and rt >= cutoff
                day = rt.strftime("%Y-%m-%d") if rt else "?"
                t = d.get("type")
                p = d.get("payload") if isinstance(d.get("payload"), dict) else {}
                if t == "session_meta":
                    src = p.get("source")
                    if isinstance(src, dict) and src.get("subagent"):
                        lane = "subagent"
                    project = os.path.basename(p["cwd"]) if isinstance(p.get("cwd"), str) else "?"
                elif t == "turn_context":
                    model = p["model"] if isinstance(p.get("model"), str) else model
                elif not in_window:
                    continue
                elif t == "response_item" and p.get("type") in ("function_call", "custom_tool_call"):
                    stats["parsed"]["codex"].add(path)
                    stats["calls"][("codex", lane, model)] += 1
                    stats["sessions"][("codex", lane, model)].add(path)
                elif t == "response_item" and p.get("type") in ("function_call_output", "custom_tool_call_output"):
                    o = p.get("output")
                    text = o if isinstance(o, str) else "".join(
                        x["text"] for x in (o if isinstance(o, list) else [])
                        if isinstance(x, dict) and isinstance(x.get("text"), str))
                    head = first_line(text, 200)
                    if not CODEX_FAIL.match(head):
                        continue
                    lines = [l.strip() for l in redact(text).split("\n") if l.strip()]
                    detail = next((l for l in lines[1:] if not l.startswith(NOISE)), "")
                    key = "codex-fail:" + detail[:60]
                    stats["errors"][key][("codex", lane, model)] += 1
                    ex = stats["examples"][key]
                    if len(ex) < 50:
                        ex.append((day, project, lane, base[8:27], detail[:110]))
    return len(files)


def main():
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--days", type=int, default=14)
    ap.add_argument("--examples", type=int, default=3)
    ap.add_argument("--claude-dir", action="append", default=[])
    ap.add_argument("--exclude")
    a = ap.parse_args()
    exclude = re.compile(a.exclude, re.I) if a.exclude else None
    cutoff = dt.datetime.now(UTC) - dt.timedelta(days=a.days)
    since = cutoff.strftime("%Y-%m-%d %H:%M UTC")
    stats = {
        "calls": collections.Counter(),
        "sessions": collections.defaultdict(set),
        "errors": collections.defaultdict(collections.Counter),
        "tools": collections.defaultdict(collections.Counter),
        "examples": collections.defaultdict(list),
        "parsed": collections.defaultdict(set),
        "rejected": collections.Counter(),
    }
    found = {}
    roots = claude_dirs(a.claude_dir)
    for label, config_dir in roots:
        h = f"claude-code:{label}"
        found[h] = scan_cc(h, config_dir, cutoff, stats, exclude)
    if not roots:
        found["claude-code"] = None
    found["codex"] = scan_codex(cutoff, stats)

    out = []
    out.append(f"# Friction scan — {socket.gethostname()} — since {since} ({a.days} days)")
    out.append("")
    for h, n in found.items():
        if n is None:
            out.append(f"- {h}: corpus absent (unknown, not zero)")
            continue
        parsed = len(stats["parsed"][h])
        if isinstance(n, tuple):
            n, scanned = n
            if scanned == 0:
                out.append(f"- {h}: {n} transcript files on disk, all excluded by --exclude (not scanned)")
                continue
            files_txt = f"{n} transcript files on disk" + (f" ({scanned} after --exclude)" if scanned < n else "")
        else:
            files_txt = f"{n} transcript files on disk"
        line = f"- {h}: {files_txt}, {parsed} with recognised tool calls in window"
        if parsed == 0:
            line += " — FORMAT UNKNOWN: files exist but no expected records parsed; treat every count below as unknown"
        out.append(line)
    out.append("- Codex failures are heuristic (first output line `Script failed` / nonzero `exit=`); "
               "hooks that fired without blocking are not visible here.")
    if stats["rejected"]:
        out.append("- odd fields skipped: " + ", ".join(f"{k} {v}" for k, v in sorted(stats["rejected"].items())))
    out.append("")
    out.append("## Tool calls in window (denominator)")
    out.append("")
    out.append("| harness | lane | model | sessions | tool calls | failed | observed fail % |")
    out.append("|---|---|---|---|---|---|---|")
    fails = collections.Counter()
    for key, per in stats["errors"].items():
        for k, v in per.items():
            fails[k] += v
    for (h, lane, model), calls in sorted(stats["calls"].items()):
        f = fails[(h, lane, model)]
        pct = f"{100 * f / calls:.1f}" if calls else "-"
        out.append(f"| {h} | {lane} | {model} | {len(stats['sessions'][(h, lane, model)])} | {calls} | {f} | {pct} |")
    out.append("")
    out.append("fail % is observed failed-result share: task mix differs per lane and model, small "
               "denominators swing, and Claude Code (`is_error` flag) is not comparable with Codex "
               "(text heuristic). Population is every raw transcript; the correction audit's "
               "exclusions (automated sessions, forked prefixes) are not applied here.")
    out.append("")
    out.append("## Failure buckets")
    out.append("")
    ranked = sorted(stats["errors"].items(), key=lambda kv: -sum(kv[1].values()))
    for key, per in ranked:
        total = sum(per.values())
        by_lane = collections.Counter()
        for (h, lane, model), v in per.items():
            by_lane[f"{h}/{lane}"] += v
        tools = ", ".join(f"{t}×{n}" for t, n in stats["tools"][key].most_common(3)) or "n/a (Codex outputs carry no tool name)"
        out.append(f"### {key} — {total}")
        out.append("")
        out.append("- by lane: " + ", ".join(f"{k} {v}" for k, v in by_lane.most_common()))
        by_model = collections.Counter()
        for (h, lane, model), v in per.items():
            by_model[model] += v
        out.append("- by model: " + ", ".join(f"{m} {v}" for m, v in by_model.most_common()))
        out.append(f"- tools: {tools}")
        for ts, project, lane, fname, line in stats["examples"][key][:a.examples]:
            out.append(f"- `{ts}` {project} {lane} `{fname}` — {line}")
        out.append("")
    # every emitted string, labels and model names included, goes through the mask
    sys.stdout.write(redact("\n".join(out)) + "\n")


if __name__ == "__main__":
    main()
