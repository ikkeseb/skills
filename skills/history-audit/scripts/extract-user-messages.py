#!/usr/bin/env python3
"""Index Claude Code sessions and extract the user's own messages, redacted.

Deterministic, stdlib only, no model reads anything. Covers pipeline steps 1
and 2 for Claude Code: discovers Claude Code config dirs (every `~/.claude*`
dir with a `projects/` folder, plus $CLAUDE_CONFIG_DIR, or the dirs named
with --claude-dir), reads main-session transcripts (never subagent files,
whose "user" turns are briefs from a parent agent), keeps the user turns
inside the window, and writes one text file per session plus `index.json`
into a fresh output directory.

Each extract (named NNNN_<config dir>_<project>.txt) has a header (session,
config dir, cwd, project, main model, local start time, active minutes,
counts) and, in order:
  [MM-DD HH:MM] USER: <text>                  a typed message
  [MM-DD HH:MM] USER COMMAND: [/name args]     a slash command with arguments
  [MM-DD HH:MM] USER INTERRUPT: [interrupted]  the user stopped the agent
  [MM-DD HH:MM] USER RESEND: <text>            a rewound re-send: same parent
                                               as an earlier typed message
  [MM-DD HH:MM] USER SUPERSEDED: <text>        the message a re-send replaced
  (agent before: ...)                          tail of the agent's text right
                                               before that message
Skipped: tool results, meta lines, command output, reminders and
environment blocks, compaction summaries, and a record repeated with the
same id. A re-send never reaches across a compaction. user_msgs counts
typed messages and re-sends, not superseded ones. Sessions with at most one
such message and no slash command are excluded as automated or trivial.
Eligible sessions are ordered by first timestamp, then path; a message id
already kept by an earlier session (a fork or branch prefix) is dropped, so
a shared prefix counts once and a fork keeps its own suffix. Credential-
shaped strings are masked in every written string, metadata and file names
included, before any cut. Timestamps are compared as instants; one without
an offset is read as UTC.

Usage: extract-user-messages.py --out DIR [--days N] [--claude-dir PATH]...
                                [--exclude REGEX] [--msg-cap N] [--prev-cap N]
  --out         new or empty directory for extracts/ and index.json
  --days        window, counted back from now (default 14)
  --claude-dir  a Claude Code config dir to read; repeatable; replaces discovery
  --exclude     skip project dirs whose name matches (case-insensitive)
  --msg-cap     characters kept per message, middle cut (default 2500)
  --prev-cap    characters kept from the agent's text before a message (default 300; 0 = none)

Extracts stay on this machine.
"""
import argparse
import collections
import datetime as dt
import glob
import hashlib
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from redact import dumps, redact  # noqa: E402

UTC = dt.timezone.utc
MISSING = object()
WRAPPER = re.compile(r"<(system-reminder|local-command-caveat|local-command-stdout|local-command-stderr|"
                     r"task-notification|command-message|bash-stdout|bash-stderr|environment_context)>"
                     r"[\s\S]*?</\1>")
CMD_NAME = re.compile(r"<command-name>([\s\S]*?)</command-name>")
CMD_ARGS = re.compile(r"<command-args>([\s\S]*?)</command-args>")


def cap(text, n):
    if len(text) <= n:
        return text
    head, tail = text[: int(n * 0.7)], text[-int(n * 0.2):]
    return f"{head}\n[...{len(text) - len(head) - len(tail)} chars cut...]\n{tail}"


def claude_dirs(given):
    """(label, path) per distinct Claude Code config dir; labels made unique."""
    candidates = list(given) or sorted(glob.glob(os.path.join(os.path.expanduser("~"), ".claude*"))) + (
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


def parse_ts(value):
    if not isinstance(value, str):
        return None
    try:
        t = dt.datetime.fromisoformat(value.replace("Z", "+00:00"))
        return (t if t.tzinfo else t.replace(tzinfo=UTC)).astimezone(UTC)
    except (ValueError, OverflowError):
        return None


def user_text(message):
    """(kind, full text) for a user turn the user typed, else None."""
    content = message.get("content")
    if isinstance(content, list):
        parts, images = [], 0
        for block in content:
            if not isinstance(block, dict):
                continue
            if block.get("type") == "tool_result":
                return None
            if block.get("type") == "text" and isinstance(block.get("text"), str):
                parts.append(block["text"])
            elif block.get("type") == "image":
                images += 1
        content = "\n".join(parts) + (f"\n[{images} image(s)]" if images else "")
    if not isinstance(content, str) or not content.strip():
        return None
    s = content.strip()
    if s.startswith("[Request interrupted by user"):
        return ("interrupt", "[interrupted]")
    name = CMD_NAME.search(s)
    if name:
        args = CMD_ARGS.search(s)
        arg_text = args.group(1).strip() if args else ""
        return ("command", f"[{name.group(1).strip()}{(' ' + arg_text) if arg_text else ''}]")
    if s.startswith(("<local-command", "<task-notification", "<bash-")):
        return None
    if "This session is being continued from a previous conversation" in s[:300]:
        return None
    s = WRAPPER.sub("", s).strip()
    return ("text", s) if s else None


def assistant_text(message):
    content = message.get("content")
    if isinstance(content, list):
        return "\n".join(b["text"] for b in content if isinstance(b, dict)
                         and b.get("type") == "text" and isinstance(b.get("text"), str)).strip()
    return content.strip() if isinstance(content, str) else ""


def load_session(path, cutoff, malformed):
    """Parse one transcript; no cross-session dedupe here."""
    msgs, models, tools, usage = [], collections.Counter(), collections.Counter(), collections.Counter()
    seen_mid, stamps, prev_agent, seen_uuid, epoch = set(), [], "", set(), 0
    meta = {"cwd": None, "version": None, "entrypoint": None, "compactions": 0}
    with open(path, encoding="utf-8", errors="ignore") as fh:
        for line in fh:
            try:
                d = json.loads(line)
            except ValueError:
                malformed["unparseable-line"] += 1
                continue
            if not isinstance(d, dict):
                malformed["non-object-record"] += 1
                continue
            t = parse_ts(d.get("timestamp"))
            if d.get("type") == "system" and d.get("subtype") == "compact_boundary":
                epoch += 1  # a re-send never reaches across a compaction
                if t and t >= cutoff:
                    meta["compactions"] += 1
            if d.get("type") not in ("user", "assistant"):
                continue
            if t is None:
                malformed["bad-timestamp"] += 1
                continue
            if t < cutoff:
                continue
            m = d.get("message")
            if not isinstance(m, dict):
                malformed["non-object-message"] += 1
                continue
            stamps.append(t)
            for k in ("cwd", "version", "entrypoint"):
                if isinstance(d.get(k), str):
                    meta[k] = meta[k] if (k == "cwd" and meta[k]) else d[k]
            if d["type"] == "assistant":
                if isinstance(m.get("model"), str) and m["model"] != "<synthetic>":
                    models[m["model"]] += 1
                mid = m.get("id")
                if isinstance(mid, str) and mid not in seen_mid and isinstance(m.get("usage"), dict):
                    seen_mid.add(mid)
                    for k in ("input_tokens", "cache_creation_input_tokens",
                              "cache_read_input_tokens", "output_tokens"):
                        v = m["usage"].get(k)
                        usage[k] += v if isinstance(v, int) else 0
                for b in m.get("content") if isinstance(m.get("content"), list) else []:
                    if isinstance(b, dict) and b.get("type") == "tool_use":
                        tools[str(b.get("name", "?"))] += 1
                text = assistant_text(m)
                if text:
                    prev_agent = text
                continue
            if d.get("isMeta") or d.get("isCompactSummary"):
                continue
            r = user_text(m)
            if not r:
                continue
            uuid = d.get("uuid") if isinstance(d.get("uuid"), str) else None
            if uuid and uuid in seen_uuid:
                malformed["repeated-uuid"] += 1  # the same record written twice
                continue
            if uuid:
                seen_uuid.add(uuid)
            parent = d.get("parentUuid", MISSING)
            parent_key = None if parent is MISSING or not (parent is None or isinstance(parent, str)) \
                else (epoch, parent if parent is not None else "<root>")
            msgs.append({"ts": t, "kind": r[0], "text": r[1], "uuid": uuid,
                         "parent": parent_key, "prev": prev_agent, "superseded": False})
            prev_agent = ""
    # rewound re-sends: a typed message whose parent equals an earlier typed message's parent
    last_by_parent = {}
    for i, msg in enumerate(msgs):
        if msg["kind"] != "text" or msg["parent"] is None:
            continue
        j = last_by_parent.get(msg["parent"])
        if j is not None:
            msg["kind"] = "resend"
            msgs[j]["superseded"] = True
        last_by_parent[msg["parent"]] = i
    return {"msgs": msgs, "models": models, "tools": tools, "usage": usage,
            "stamps": sorted(stamps), "meta": meta}


def prepare_out(out):
    if os.path.islink(out) or (os.path.exists(out) and (not os.path.isdir(out) or os.listdir(out))):
        sys.exit(f"--out must be a new or empty directory (not a symlink): {out}")
    os.makedirs(os.path.join(out, "extracts"))


def main():
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--out", required=True)
    ap.add_argument("--days", type=int, default=14)
    ap.add_argument("--claude-dir", action="append", default=[])
    ap.add_argument("--exclude")
    ap.add_argument("--msg-cap", type=int, default=2500)
    ap.add_argument("--prev-cap", type=int, default=300)
    a = ap.parse_args()
    cutoff = dt.datetime.now(UTC) - dt.timedelta(days=a.days)
    exclude = re.compile(a.exclude, re.I) if a.exclude else None
    prepare_out(a.out)
    roots = claude_dirs(a.claude_dir)
    excluded, malformed, candidates = collections.Counter(), collections.Counter(), []
    for label, root in roots:
        for path in glob.glob(os.path.join(root, "projects", "*", "*.jsonl")):
            pdir = os.path.basename(os.path.dirname(path))
            if os.path.basename(path).startswith("agent-"):
                excluded["subagent-file"] += 1
                continue
            if exclude and exclude.search(pdir):
                excluded["excluded-project"] += 1
                continue
            s = load_session(path, cutoff, malformed)
            if not s["stamps"]:
                excluded["no-activity-in-window"] += 1
                continue
            effective = sum(1 for x in s["msgs"] if x["kind"] in ("text", "resend") and not x["superseded"])
            if effective <= 1 and not any(x["kind"] == "command" for x in s["msgs"]):
                excluded["automated-or-trivial"] += 1
                continue
            s.update(label=label, path=path, pdir=pdir, sid=os.path.basename(path)[:-6])
            candidates.append(s)
    candidates.sort(key=lambda s: (s["stamps"][0], os.path.realpath(s["path"])))
    seen_uuid, index = set(), []
    for s in candidates:
        kept = []
        for msg in s["msgs"]:
            if msg["uuid"] and msg["uuid"] in seen_uuid:
                continue
            if msg["uuid"]:
                seen_uuid.add(msg["uuid"])
            kept.append(msg)
        dropped = len(s["msgs"]) - len(kept)
        if not kept:
            excluded["fork-duplicate-only"] += 1
            continue
        stamps, meta = s["stamps"], s["meta"]
        active = sum(g for g in ((b - x).total_seconds() for x, b in zip(stamps, stamps[1:])) if g < 600)
        project = redact(os.path.basename(meta["cwd"] or s["pdir"]))
        main_model = redact(s["models"].most_common(1)[0][0]) if s["models"] else "?"
        safe = lambda v: re.sub(r"[^A-Za-z0-9._-]+", "_", redact(v))[:60]  # noqa: E731
        fname = f"{len(index) + 1:04d}_{safe(s['label'])}_{safe(project)}.txt"
        counts = collections.Counter(("superseded" if m["superseded"] else m["kind"]) for m in kept)
        user_msgs = counts["text"] + counts["resend"]
        rec = {
            "file": fname, "config_dir": s["label"], "session": s["sid"], "project": project,
            "cwd": redact(meta["cwd"]), "entrypoint": meta["entrypoint"], "version": meta["version"],
            "start_local": stamps[0].astimezone().strftime("%Y-%m-%d %H:%M %z"),
            "end_utc": stamps[-1].strftime("%Y-%m-%dT%H:%M:%SZ"),
            "active_min": round(active / 60), "user_msgs": user_msgs,
            "superseded": counts["superseded"], "interrupts": counts["interrupt"],
            "resends": counts["resend"],
            "commands": [cap(redact(m["text"]), a.msg_cap) for m in kept if m["kind"] == "command"],
            "models": dict(s["models"]), "tools": dict(s["tools"].most_common(15)),
            "subagent_files": len(glob.glob(os.path.join(s["path"][:-6], "subagents", "*.jsonl"))),
            "compactions": meta["compactions"], "fork_prefix_dropped": dropped, "usage": dict(s["usage"]),
        }
        with open(os.path.join(a.out, "extracts", fname), "x", encoding="utf-8") as fo:
            fo.write(redact(f"# session {s['sid']} | config dir {s['label']} | cwd {meta['cwd']} | "
                            f"project {project} | model {main_model} | start {rec['start_local']} | "
                            f"active {rec['active_min']} min | user msgs {user_msgs} | "
                            f"interrupts {counts['interrupt']} | resends {counts['resend']}") + "\n\n")
            for m in kept:
                prev = redact(m["prev"])[-a.prev_cap:] if (m["prev"] and a.prev_cap > 0) else ""
                if prev:
                    fo.write(f"  (agent before: ...{prev.replace(chr(10), ' ')})\n")
                kind = "superseded" if m["superseded"] else m["kind"]
                tag = "" if kind == "text" else " " + kind.upper()
                fo.write(f"[{m['ts'].astimezone().strftime('%m-%d %H:%M')}] USER{tag}: "
                         f"{cap(redact(m['text']), a.msg_cap)}\n\n")
        index.append(rec)
    summary = {"since_utc": cutoff.strftime("%Y-%m-%dT%H:%M:%SZ"),
               "claude_dirs": [{"label": l, "path": redact(r)} for l, r in roots],
               "excluded": excluded, "malformed": malformed, "sessions": index}
    with open(os.path.join(a.out, "index.json"), "x", encoding="utf-8") as fo:
        fo.write(dumps(summary, indent=1, ensure_ascii=False))
    if not roots:
        print("claude-code: corpus absent (unknown, not zero)")
        return
    print(f"window since {summary['since_utc']}; {len(index)} sessions; excluded {dict(excluded)}"
          + (f"; malformed {dict(malformed)}" if malformed else ""))
    for label, _ in roots:
        rs = [r for r in index if r["config_dir"] == label]
        print(redact(f"  {label}: {len(rs)} sessions, {sum(r['user_msgs'] for r in rs)} user messages"))
    print(f"index: {os.path.join(a.out, 'index.json')}")


if __name__ == "__main__":
    main()
