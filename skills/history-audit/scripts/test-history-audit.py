#!/usr/bin/env python3
"""Provider-free tests for the history-audit scripts, on synthetic transcripts.

Run: python3 skills/history-audit/scripts/test-history-audit.py
Exits non-zero when a check fails. Stdlib only; writes only to a temp dir and
runs the scanners against an isolated HOME.
"""
import datetime as dt
import json
import os
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from redact import redact  # noqa: E402

FAILS = []
TOKEN = "ghp_ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
TOKEN_TAIL = "GHIJKLMNOPQRSTUVWXYZ0123456789"  # what a cut before masking would leave


def check(name, cond, detail=""):
    print(("ok    " if cond else "FAIL  ") + name + ("" if cond else f"  [{str(detail)[:300]}]"))
    if not cond:
        FAILS.append(name)


def iso(t, offset_h=0):
    return t.astimezone(dt.timezone(dt.timedelta(hours=offset_h))).isoformat()


# --- redaction -------------------------------------------------------------
JWT = "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.dozjgNryP4J3jVmNHl0w5N_XgL0n3I9PlFUP0THsR8U"
leaks = {
    "openai": ("key sk-proj-abcdefghijklmnop1234", "abcdefghijklmnop1234"),
    "github": (TOKEN, "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"),
    "slack app": ("xapp-1-A0123456789-abcdef", "A0123456789-abcdef"),
    "jwt": (f"token {JWT}", "dozjgNryP4J3jVmNHl0w5N"),
    "json password": ('"password": "lowercase-password!"', "lowercase-password!"),
    "json escaped quote": ('"password": "first\\"remaining-secret!"', "remaining-secret"),
    "quoted spaces": ('password="secret with spaces"', "secret with spaces"),
    "env letters only": ("API_KEY=abcdefghijklmnopqrstuv", "abcdefghijklmnopqrstuv"),
    "env lowercase": ("password=lowercasepassword", "lowercasepassword"),
    "env prefixed name": ("DB_PASSWORD=hunter2", "hunter2"),
    "export": ("export GITHUB_TOKEN=plainvalue", "plainvalue"),
    "yaml line": ("db:\n  password: hunter2 again", "hunter2"),
    "bearer": ("Authorization: Bearer abcdefghijklmnopqrstuvwxyz", "abcdefghijklmnopqrstuvwxyz"),
    "url userinfo": ("https://user:hunter2@example.com/x", "hunter2"),
    "aws": ("AKIAABCDEFGHIJKLMNOP", "AKIAABCDEFGHIJKLMNOP"),
    "pem": ("-----BEGIN PRIVATE KEY-----\nMIIEvQIBADANBgkqhkiG9w0BAQEFAASC\n-----END PRIVATE KEY-----",
            "MIIEvQIBADANBgkqhkiG9w0BAQEFAASC"),
    "multiline quoted": ('PASSWORD="line1\nremaining-secret"', "remaining-secret"),
    "cli option": ("Use --password hunter2 to connect.", "hunter2"),
    "basic auth": ("Authorization: Basic YTpi", "YTpi"),
    "json header": ('{"headers": {"Authorization": "Basic YTpi"}}', "YTpi"),
    "python header": ("{'Authorization': 'Basic YTpi'}", "YTpi"),
    "camelCase key": ('githubToken="ghx-plain-value"', "ghx-plain-value"),
}
for name, (text, secret) in leaks.items():
    out = redact(text)
    check(f"redact masks {name}", secret not in out, out)
prose = ["The secret: implementation details should stay local.",
         "The secret: implementation-details should stay local.",
         "Use token = current word", "Use token = current_word in the parser.",
         "the password prompt appeared twice", "token usage was high today",
         "see src/ParseUserMessagesVersion2Implementation.py",
         '{"input_tokens": 1200, "output_tokens": 300, "tokenizer": "cl100k_base"}',
         "token_count = 4096 was the expected usage.",
         "Token: the parser produced the wrong node.",
         "a basic understanding of the parser"]
for p in prose:
    check(f"redact keeps prose: {p[:40]}", redact(p) == p, redact(p))

# --- fixtures --------------------------------------------------------------
now = dt.datetime.now(dt.timezone.utc)
tmp = tempfile.mkdtemp(prefix="ha-test-")
home = os.path.join(tmp, "home")
root1 = os.path.join(tmp, "p1", ".claude")
root2 = os.path.join(tmp, "p2", ".claude")  # same basename: labels must stay distinct
root3 = os.path.join(tmp, "p3", ".claude-" + TOKEN)  # a credential in the dir name
secret_cwd = "/work/sk-proj-abcdefghijklmnop1234/proj"
proj1 = os.path.join(root1, "projects", "-work-proj")
proj2 = os.path.join(root2, "projects", "-work-other")
proj3 = os.path.join(root3, "projects", "-work-third")
codex_dir = os.path.join(home, ".codex", "sessions", "2026", "10", "01")
for d in (os.path.join(proj1, "sessA", "subagents"), proj2, proj3, codex_dir):
    os.makedirs(d)


def u(uuid, parent, t, content, **kw):
    rec = {"type": "user", "uuid": uuid, "parentUuid": parent, "timestamp": t, "cwd": secret_cwd,
           "message": {"role": "user", "content": content}}
    rec.update(kw)
    return rec


def asst(uuid, parent, t, text, model="model-x", tool=None):
    content = [{"type": "text", "text": text}]
    if tool:
        content.append({"type": "tool_use", "id": "tu-" + uuid, "name": tool, "input": {}})
    return {"type": "assistant", "uuid": uuid, "parentUuid": parent, "timestamp": t,
            "message": {"id": "m-" + uuid, "model": model, "content": content,
                        "usage": {"input_tokens": 5, "output_tokens": 7}}}


def write(path, records, raw_lines=()):
    with open(path, "w", encoding="utf-8") as f:
        for r in records:
            f.write(json.dumps(r) + "\n")
        for line in raw_lines:
            f.write(line + "\n")


t0 = now - dt.timedelta(hours=10)
T = lambda m, off=0: iso(t0 + dt.timedelta(minutes=m), off)  # noqa: E731
split_msg = "x" * 1740 + TOKEN + "y" * 1500       # the 2500-char cap would cut the token
split_agent = "z " * 250 + TOKEN + " ." * 135     # the 300-char agent tail would cut it
sessA = [
    u("u1", None, T(0), "first ask"),
    asst("a1", "u1", T(1), split_agent, tool="Bash"),
    u("u2", "a1", T(2), "second ask, original wording"),
    u("u2b", "a1", T(3, 2), "second ask, rewound and re-sent"),  # same parent: re-send, with an offset
    asst("a2", "u2b", T(4), "agent reply two"),
    u("u3", "a2", T(5), "[Request interrupted by user]"),
    u("u4", "u3", T(6), "<command-name>/orchestrate</command-name>\n<command-args>do the thing</command-args>"),
    u("u5", "u4", T(7), split_msg),
    u(None, "u5", T(8), 'uuid-less one {"headers": {"Authorization": "Basic YTpiQUTH"}}'),
    u(None, "a9", T(9), [{"type": "text", "text": None}, {"type": "text", "text": "uuid-less two"}]),
    u("u6", "u5", 12345, "numeric timestamp, skipped"),
    {"type": "user", "uuid": "u7", "timestamp": T(10), "message": ["list", "message"]},
    asst("a3", "u5", "9999-12-31T23:59:59-23:59", "overflowing timestamp, skipped"),
]
write(os.path.join(proj1, "sessA.jsonl"), sessA, raw_lines=["[1, 2, 3]", "not json"])
# fork B shares u1, u2 with A and adds one unique message
write(os.path.join(proj1, "sessB.jsonl"), sessA[:3] + [u("b1", "u2", T(20), "unique fork correction")])
# C: one message, earlier, shares u1; ineligible, so it must not consume A's prefix
write(os.path.join(proj1, "sessC.jsonl"), [u("u1", None, iso(t0 - dt.timedelta(minutes=30)), "first ask")])
# legacy subagent file at project level and a nested subagent file: never extracted
write(os.path.join(proj1, "agent-legacy.jsonl"), [u("x1", None, T(0), "brief one"), u("x2", "x1", T(1), "brief two")])
write(os.path.join(proj1, "sessA", "subagents", "agent-new.jsonl"), [
    asst("s1", None, T(2), "sub", tool="Edit"),
    {"type": "user", "uuid": "s2", "timestamp": T(3), "message": {"role": "user", "content": [
        {"type": "tool_result", "tool_use_id": "tu-s1", "is_error": True,
         "content": "Exit code 1\nAuthorization: Bearer abcdefghijklmnopqrstuvwxyz"}]}},
    asst("s3", "s2", T(4), "sub again", tool="Bash"),
    {"type": "user", "uuid": "s4", "timestamp": T(5), "message": {"role": "user", "content": [
        {"type": "tool_result", "tool_use_id": "tu-s3", "is_error": True,
         "content": "Exit code 1\nOutput: -----BEGIN PRIVATE KEY-----\nMIIBshortbodyXYZ\n"}]}},
    asst("s6", "s4", T(5), "sub three", tool="Bash"),
    {"type": "user", "uuid": "s7", "timestamp": T(5), "message": {"role": "user", "content": [
        {"type": "tool_result", "tool_use_id": "tu-s6", "is_error": True,
         "content": "Exit code 7\n{'Authorization': 'Basic YTpiSCAN'}"}]}},
    {"type": "assistant", "timestamp": T(6), "message": {"model": ["list"], "content": [
        {"type": "tool_use", "id": "tu-s5", "name": "Bash"}]}},
    {"type": "user", "timestamp": T(7), "message": {"content": [
        {"type": "tool_result", "tool_use_id": "tu-s5", "is_error": True,
         "content": [{"type": "text", "text": None}]}]}},
    {"type": "assistant", "timestamp": T(8), "message": {"model": "m", "content": [
        {"type": "tool_use", "id": ["list-id"], "name": ["list-name"]}]}},
    {"type": "user", "timestamp": T(9), "message": {"content": [
        {"type": "tool_result", "tool_use_id": {"dict": "ref"}, "is_error": True, "content": "Exit code 2"}]}},
])
# E: explicit null-parent re-send at the root
write(os.path.join(proj1, "sessE.jsonl"), [
    u("e1", None, T(30), "root ask, first wording"), u("e2", None, T(31), "root ask, re-sent"),
    asst("ea", "e2", T(32), "ok"), u("e3", "ea", T(33), "follow-up")])
# F: the same record written twice must not supersede itself or vanish
write(os.path.join(proj1, "sessF.jsonl"), [
    u("f1", None, T(40), "f first"), asst("fa", "f1", T(41), "ok"),
    u("f2", "fa", T(42), "f second"), u("f2", "fa", T(42), "f second")])
# G: a null-parent turn after a compaction does not supersede an earlier one
write(os.path.join(proj1, "sessG.jsonl"), [
    u("g1", None, T(50), "before compaction"), asst("ga", "g1", T(51), "ok"),
    {"type": "system", "subtype": "compact_boundary", "timestamp": T(52)},
    u("g2", None, T(53), "after compaction"), asst("gb", "g2", T(54), "ok"), u("g3", "gb", T(55), "later")])
# H: one message plus its re-send is one effective message: excluded
write(os.path.join(proj1, "sessH.jsonl"), [
    u("h1", "hx", T(60), "only ask"), u("h2", "hx", T(61), "only ask, re-sent")])
# window edges with offsets: string comparison would get both wrong
days = 1
cut = now - dt.timedelta(days=days)
write(os.path.join(proj2, "sessD.jsonl"), [
    u("d0", None, iso(cut - dt.timedelta(hours=1), 5), "outside the window"),
    u("d1", None, iso(cut + dt.timedelta(hours=1), -5), "inside one"),
    u("d2", "d1", iso(cut + dt.timedelta(hours=2), -5), "inside two"),
])
# I in root2 shares A's first messages at the same first timestamp: ownership must not follow argument order
write(os.path.join(proj2, "sessI.jsonl"), sessA[:3] + [u("i1", "u2", T(70), "unique in I")])
# K: the same session file name in two config dirs, sharing a prefix at the same first timestamp
kmsgs = [u("k1", None, T(90), "k first"), asst("ka", "k1", T(91), "ok"), u("k2", "ka", T(92), "k second")]
write(os.path.join(proj1, "sessK.jsonl"), kmsgs + [u("k3", "k2", T(93), "k in root1")])
write(os.path.join(proj2, "sessK.jsonl"), kmsgs + [u("k4", "k2", T(94), "k in root2")])
# J: credentials in metadata (model, version, entrypoint) and in the config dir name
jrec = asst("ja", "j1", T(81), "ok", model="sk-proj-zzzzzzzzzzzzzzzz9", tool="Bash")
jrec.update(version="sk-proj-versionversion1", entrypoint="sk-proj-entrypointentry2")
write(os.path.join(proj3, "sessJ.jsonl"), [u("j1", None, T(80), "j ask"), jrec, u("j2", "ja", T(82), "j again")])


# --- extract-user-messages -------------------------------------------------
def extract(out, dirs):
    cmd = [sys.executable, os.path.join(HERE, "extract-user-messages.py"), "--out", out, "--days", str(days)]
    for d in dirs:
        cmd += ["--claude-dir", d]
    return cmd, subprocess.run(cmd, capture_output=True, text=True, env=dict(os.environ, HOME=home))


out = os.path.join(tmp, "out")
cmd, r = extract(out, [root1, root2, root3])
check("extract runs", r.returncode == 0, r.stderr[-400:])
check("stdout masks a credential in a config dir name", TOKEN_TAIL not in r.stdout, r.stdout)
idx = json.load(open(os.path.join(out, "index.json"), encoding="utf-8"))
labels = [d["label"] for d in idx["claude_dirs"]]
check("same-basename config dirs get distinct labels", len(set(labels)) == 3, labels)
by_sid = {s["session"]: s for s in idx["sessions"]}
check("legacy agent file excluded", "agent-legacy" not in by_sid and idx["excluded"].get("subagent-file") == 1,
      idx["excluded"])
check("ineligible C excluded", "sessC" not in by_sid)
check("message plus its re-send only (H) excluded", "sessH" not in by_sid, list(by_sid))
A = by_sid.get("sessA", {})
check("A keeps its prefix (C did not consume it)", A.get("fork_prefix_dropped") == 0, A)
check("A user_msgs excludes the superseded message", A.get("user_msgs") == 5, A.get("user_msgs"))
check("A counts one re-send and one superseded", A.get("resends") == 1 and A.get("superseded") == 1, A)
check("A counts the interrupt", A.get("interrupts") == 1, A)
check("A keeps slash-command arguments", A.get("commands") == ["[/orchestrate do the thing]"], A.get("commands"))
check("malformed records counted, overflow included", idx["malformed"].get("bad-timestamp", 0) >= 2
      and idx["malformed"].get("non-object-record", 0) >= 1 and idx["malformed"].get("non-object-message", 0) >= 1,
      idx["malformed"])
B = by_sid.get("sessB", {})
check("fork B keeps only its unique suffix", B.get("user_msgs") == 1 and B.get("fork_prefix_dropped") == 2, B)
E = by_sid.get("sessE", {})
check("explicit null-parent re-send marked", E.get("resends") == 1 and E.get("superseded") == 1
      and E.get("user_msgs") == 2, E)
F = by_sid.get("sessF", {})
check("a repeated record neither supersedes nor vanishes", F.get("user_msgs") == 2 and F.get("superseded") == 0, F)
G = by_sid.get("sessG", {})
check("no re-send across a compaction", G.get("superseded") == 0 and G.get("user_msgs") == 3, G)
D = by_sid.get("sessD", {})
check("window compares instants, not strings", D.get("user_msgs") == 2, D)
textA = open(os.path.join(out, "extracts", A["file"]), encoding="utf-8").read() if A else ""
check("A marks superseded and re-send", "USER SUPERSEDED: second ask, original wording" in textA
      and "USER RESEND: second ask, rewound" in textA)
check("A keeps both uuid-less messages", "uuid-less one" in textA and "uuid-less two" in textA)
check("extract masks a quoted Authorization header", "YTpiQUTH" not in textA)
check("user text masked before the cap", TOKEN_TAIL not in textA and "ghp_ABCDEF" not in textA)
check("agent tail masked before the cut", "(agent before: ..." in textA and TOKEN_TAIL[-20:] not in textA)
everything = json.dumps(idx) + "".join(os.listdir(os.path.join(out, "extracts")))
for f in os.listdir(os.path.join(out, "extracts")):
    everything += open(os.path.join(out, "extracts", f), encoding="utf-8").read()
for secret in ("abcdefghijklmnop1234", "zzzzzzzzzzzzzzzz9", "versionversion1", "entrypointentry2", TOKEN_TAIL):
    check(f"metadata, names and index mask {secret[:12]}", secret not in everything)
r2 = subprocess.run(cmd, capture_output=True, text=True, env=dict(os.environ, HOME=home))
check("refuses a non-empty --out", r2.returncode != 0)
_, r3 = extract(os.path.join(tmp, "out-rev"), [root3, root2, root1])
idx_rev = json.load(open(os.path.join(tmp, "out-rev", "index.json"), encoding="utf-8"))
own = lambda ix: sorted((s["config_dir"], s["session"], s["fork_prefix_dropped"]) for s in ix["sessions"])  # noqa: E731
check("prefix ownership does not follow --claude-dir order", own(idx) == own(idx_rev), (own(idx), own(idx_rev)))

# --- friction-scan ---------------------------------------------------------
old = now - dt.timedelta(days=3)
write(os.path.join(codex_dir, "rollout-2026-10-01T00-00-00-x.jsonl"), [
    {"timestamp": iso(old), "type": "session_meta", "payload": {"cwd": "/work/cx", "source": {"subagent": "x"}}},
    {"timestamp": iso(old), "type": "turn_context", "payload": {"model": "gpt-test"}},
    {"timestamp": T(1), "type": "response_item", "payload": {"type": "function_call"}},
    {"timestamp": T(2), "type": "response_item", "payload": {"type": "function_call_output",
                                                           "output": "Script failed\npassword=hunter2 here"}},
    {"type": "response_item", "payload": {"type": "function_call"}},           # no timestamp: not counted
    {"timestamp": T(3), "type": "response_item", "payload": ["odd", "payload"]},
])
fs = [sys.executable, os.path.join(HERE, "friction-scan.py"), "--days", "2", "--claude-dir", root1]
r = subprocess.run(fs, capture_output=True, text=True, env=dict(os.environ, HOME=home))
check("friction-scan runs on odd input", r.returncode == 0, r.stderr[-400:])
check("friction-scan counts a nested subagent file as subagent", "| subagent |" in r.stdout, r.stdout[:600])
check("friction-scan masks bearer values", "abcdefghijklmnopqrstuvwxyz" not in r.stdout)
check("friction-scan masks a key body before choosing lines", "MIIBshortbodyXYZ" not in r.stdout)
check("friction-scan masks a quoted Authorization header", "YTpiSCAN" not in r.stdout
      and "exit-code:7" in r.stdout, r.stdout[:900])
check("codex: in-window call in an older-named file keeps its subagent lane and model",
      "| codex | subagent | gpt-test | 1 | 1 | 1 |" in r.stdout, r.stdout)
check("codex: failure text masked", "hunter2" not in r.stdout)
check("friction-scan counts odd tool fields instead of crashing", "odd fields skipped:" in r.stdout
      and "tool id 1" in r.stdout and "tool_use_id 1" in r.stdout, r.stdout[:800])
r = subprocess.run([sys.executable, os.path.join(HERE, "friction-scan.py"), "--days", "2", "--claude-dir", root3],
                   capture_output=True, text=True, env=dict(os.environ, HOME=home))
check("friction-scan masks a credential in a config dir label and a model name",
      r.returncode == 0 and TOKEN_TAIL not in r.stdout and "zzzzzzzzzzzzzzzz9" not in r.stdout, r.stdout[:600])
r = subprocess.run(fs + ["--exclude", "."], capture_output=True, text=True, env=dict(os.environ, HOME=home))
check("friction-scan reports fully excluded, not absent", "all excluded by --exclude" in r.stdout, r.stdout[:400])

print(("FAILED: " + ", ".join(FAILS)) if FAILS else "all history-audit checks passed")
sys.exit(1 if FAILS else 0)
