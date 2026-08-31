#!/usr/bin/env python3
"""Count failed tool calls in this machine's agent-session history.

Deterministic, stdlib only, no model reads anything. Scans Claude Code
transcripts (~/.claude/projects/*/*.jsonl, main and agent-* files) and Codex
rollouts (~/.codex/sessions/**/rollout-*.jsonl) for tool results the harness
marked as failures, buckets them by cause, and prints a markdown report with
counts per harness, lane (main/subagent) and model, plus a few dated pointers
per bucket so a reader can open the source. Error text is truncated to its
first line and credential-shaped strings are masked before printing.

Usage: friction-scan.py [--days N] [--examples N]
  --days      window, counted back from now on content timestamps (default 14)
  --examples  pointers printed per bucket (default 3)

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
import socket
import sys

HOME = os.path.expanduser("~")
SECRET = re.compile(
    r"(sk-[A-Za-z0-9_-]{8,}|gh[pousr]_[A-Za-z0-9]{20,}|xox[abp]-[A-Za-z0-9-]{10,}"
    r"|AKIA[A-Z0-9]{12,}|eyJ[A-Za-z0-9_-]{20,}|-----BEGIN [A-Z ]*PRIVATE KEY-----"
    r"|(?i:password|passwd|token|secret)\s*[=:]\s*\S+)"
)

CC_BUCKETS = [
    ("hook-block", re.compile(r"^(PreToolUse|PostToolUse|Stop|UserPromptSubmit):?\w* hook error")),
    ("automode-denied", re.compile(r"denied by the Claude Code auto mode")),
    ("user-denied", re.compile(r"The user doesn't want to proceed")),
    ("read-before-edit", re.compile(r"(File has not been read yet|File must be read first)")),
    ("edit-mismatch", re.compile(r"(String to replace not found|Found \d+ matches of the string)")),
    ("modified-since-read", re.compile(r"File has been modified since read")),
    ("file-not-found", re.compile(r"(File does not exist|ENOENT|EISDIR)")),
    ("schema-mismatch", re.compile(r"Output does not match required schema")),
    ("blocked-command", re.compile(r"<tool_use_error>Blocked:")),
    ("worktree-isolation", re.compile(r"This session is isolated in the worktree")),
    ("symlink-refused", re.compile(r"Refusing to write through symlink")),
    ("exit-code", re.compile(r"^Exit code (\d+)")),
]
HOOK_NAME = re.compile(r"hooks/([\w-]+)\.sh")


def redact(text):
    return SECRET.sub("<masked>", text)


NOISE = ("Script failed", "Script error:", "Wall time", "Output:")


def first_line(text, n=110):
    for line in text.split("\n"):
        line = line.strip()
        if line:
            return redact(line)[:n]
    return ""


def context_line(text, n=110):
    """First line plus the next informative one, for exit codes and script failures."""
    lines = [l.strip() for l in text.split("\n") if l.strip() and not l.startswith(NOISE)]
    return redact(" | ".join(lines[:2]))[:n]


def tool_result_text(block):
    content = block.get("content")
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        return "\n".join(x.get("text", "") for x in content if isinstance(x, dict))
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


def scan_cc(since, stats):
    root = os.path.join(HOME, ".claude", "projects")
    files = glob.glob(os.path.join(root, "**", "*.jsonl"), recursive=True)
    if not files:
        return None
    for path in files:
        base = os.path.basename(path)
        lane = "subagent" if base.startswith("agent-") else "main"
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
                ts = d.get("timestamp", "")
                if not ts or ts[:10] < since:
                    continue
                m = d.get("message")
                if not isinstance(m, dict) or not isinstance(m.get("content"), list):
                    continue
                if m.get("model"):
                    model = m["model"]
                for b in m["content"]:
                    if not isinstance(b, dict):
                        continue
                    if b.get("type") == "tool_use":
                        tool_by_id[b.get("id")] = b.get("name", "?")
                        stats["calls"][("claude-code", lane, model)] += 1
                        stats["sessions"][("claude-code", lane, model)].add(path)
                    elif b.get("type") == "tool_result" and b.get("is_error"):
                        text = tool_result_text(b)
                        tool = tool_by_id.get(b.get("tool_use_id"), "?")
                        key = bucket_cc(text)
                        stats["errors"][key][("claude-code", lane, model)] += 1
                        stats["tools"][key][tool] += 1
                        ex = stats["examples"][key]
                        if len(ex) < 50:
                            ex.append((ts[:16], project, lane, base[:20], context_line(text)))
    return len(files)


CODEX_FAIL = re.compile(r"^(Script failed|exit=[1-9]\d*|Process exited with code [1-9]\d*)")


def scan_codex(since, stats):
    root = os.path.join(HOME, ".codex", "sessions")
    files = glob.glob(os.path.join(root, "**", "rollout-*.jsonl"), recursive=True)
    if not files:
        return None
    for path in files:
        base = os.path.basename(path)
        day = base[len("rollout-"):len("rollout-") + 10]
        if day < since:
            continue
        lane, model, project = "main", "?", "?"
        with open(path, encoding="utf-8", errors="ignore") as fh:
            for line in fh:
                try:
                    d = json.loads(line)
                except ValueError:
                    continue
                t = d.get("type")
                p = d.get("payload") or {}
                if t == "session_meta":
                    src = p.get("source")
                    if isinstance(src, dict) and src.get("subagent"):
                        lane = "subagent"
                    project = os.path.basename(p.get("cwd") or "") or "?"
                elif t == "turn_context":
                    model = p.get("model") or model
                elif t == "response_item" and p.get("type") in ("function_call", "custom_tool_call"):
                    stats["calls"][("codex", lane, model)] += 1
                    stats["sessions"][("codex", lane, model)].add(path)
                elif t == "response_item" and p.get("type") in ("function_call_output", "custom_tool_call_output"):
                    o = p.get("output")
                    text = o if isinstance(o, str) else "".join(
                        x.get("text", "") for x in (o or []) if isinstance(x, dict))
                    head = first_line(text, 200)
                    if not CODEX_FAIL.match(head):
                        continue
                    lines = [l.strip() for l in text.split("\n") if l.strip()]
                    detail = next((l for l in lines[1:] if not l.startswith(NOISE)), "")
                    key = "codex-fail:" + redact(detail)[:60]
                    stats["errors"][key][("codex", lane, model)] += 1
                    stats["tools"][key][p.get("name") or p.get("type")] += 1
                    ex = stats["examples"][key]
                    if len(ex) < 50:
                        ex.append((day, project, lane, base[8:27], redact(detail)[:110]))
    return len(files)


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--days", type=int, default=14)
    ap.add_argument("--examples", type=int, default=3)
    a = ap.parse_args()
    since = (dt.datetime.now(dt.timezone.utc) - dt.timedelta(days=a.days)).strftime("%Y-%m-%d")
    stats = {
        "calls": collections.Counter(),
        "sessions": collections.defaultdict(set),
        "errors": collections.defaultdict(collections.Counter),
        "tools": collections.defaultdict(collections.Counter),
        "examples": collections.defaultdict(list),
    }
    found = {"claude-code": scan_cc(since, stats), "codex": scan_codex(since, stats)}

    out = []
    out.append(f"# Friction scan — {socket.gethostname()} — since {since} ({a.days} days)")
    out.append("")
    for h, n in found.items():
        out.append(f"- {h}: " + ("corpus absent (unknown, not zero)" if n is None else f"{n} transcript files on disk"))
    out.append("- Codex failures are heuristic (first output line `Script failed` / nonzero `exit=`); "
               "hooks that fired without blocking are not visible here.")
    out.append("")
    out.append("## Tool calls in window (denominator)")
    out.append("")
    out.append("| harness | lane | model | sessions | tool calls | failed | fail % |")
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
    out.append("## Failure buckets")
    out.append("")
    ranked = sorted(stats["errors"].items(), key=lambda kv: -sum(kv[1].values()))
    for key, per in ranked:
        total = sum(per.values())
        by_lane = collections.Counter()
        for (h, lane, model), v in per.items():
            by_lane[f"{h}/{lane}"] += v
        tools = ", ".join(f"{t}×{n}" for t, n in stats["tools"][key].most_common(3))
        out.append(f"### {key} — {total}")
        out.append("")
        out.append("- by lane: " + ", ".join(f"{k} {v}" for k, v in by_lane.most_common()))
        out.append("- by model: " + ", ".join(
            f"{m} {v}" for m, v in sorted(collections.Counter(
                {model: v for (h, lane, model), v in per.items()}).items(), key=lambda kv: -kv[1])))
        out.append(f"- tools: {tools}")
        for ts, project, lane, fname, line in stats["examples"][key][:a.examples]:
            out.append(f"- `{ts}` {project} {lane} `{fname}` — {line}")
        out.append("")
    sys.stdout.write("\n".join(out) + "\n")


if __name__ == "__main__":
    main()
