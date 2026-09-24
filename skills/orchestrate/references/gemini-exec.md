# Gemini lane: worker contract

Read this before dispatching the first Gemini-lane stage. The lane runs
Google models through the Antigravity CLI (`agy`) as **read-only** workers.
The invocation (flags, isolation, permission rules, validation) lives in
`scripts/gemini-worker.sh`; never hand-roll `agy` commands.

Resolve the helper from this skill's deployment locations only, never from
the session repository:

```bash
GEMINI_HELPER="${CLAUDE_PLUGIN_ROOT}/skills/orchestrate/scripts/gemini-worker.sh"
[ -x "$GEMINI_HELPER" ] || GEMINI_HELPER="$HOME/.claude/skills/orchestrate/scripts/gemini-worker.sh"
[ -x "$GEMINI_HELPER" ] || GEMINI_HELPER="$HOME/skills/skills/orchestrate/scripts/gemini-worker.sh"
```

## Preflight

Once per session before the first Gemini stage, `"$GEMINI_HELPER" probe`
(no model call) returns `{ok, agy_version, authenticated, models}`.
`ok: false` means the lane is down: route to Luna or the Claude lane and say
so. `authenticated: false` needs one interactive `agy` login on that
machine, which only the user can do. After an `agy` upgrade,
`"$GEMINI_HELPER" verify` runs one small billed run and asserts a read
canary, a denied write and an unchanged workspace. Probe proves the login;
only verify proves the read-only boundary still holds.

## What a worker can do

Every run gets a throwaway HOME whose `settings.json` denies file writes,
shell commands, web, browser and MCP. The login survives: Windows keeps it
in the OS credential store, macOS in the login keychain (the helper links
`~/Library/Keychains` in, since macOS resolves it under HOME), and WSL in
agy's token file, which the helper copies in. The run checks the login
before the prompt leaves: a logged-out agy would start its own login flow
and read the prompt as the authorization code. The user's own agy settings,
plugins and grants never load; instructions do: the helper copies
`~/.gemini/GEMINI.md` into the throwaway HOME, and agy reads the workspace's
`AGENTS.md` itself.

- It reads files with its own file tools, in `--workspace` and, like a
  Codex read-only worker, anywhere else the user can read. Brief only
  content that may leave the machine; never point it near secrets.
- It cannot run anything: no tests, builds, `git` or `wc`. Never ask it
  to. Counts, line numbers and inventories are unreliable (every line
  count off by one in a 2026-09-24 check), so reconcile them against a
  deterministic inventory the seat produced.
- It cannot write. The helper also compares a workspace fingerprint (paths,
  mtimes, git HEAD) before and after the run and fails on any difference,
  including the seat's own edits, so leave the workspace alone meanwhile.

## Running a worker

```bash
"$GEMINI_HELPER" run \
  --model gemini-3.8-flash-medium      # REQUIRED; exact id from probe, effort included
  --prompt-file "$DIR/prompt.md" \
  [--workspace "$PWD"]                 # the directory it reads
  [--schema-file "$DIR/schema.json"]   # JSON Schema for the final answer
  [--timeout 900]                      # total deadline in seconds
  [--run-dir "$RUN_DIR"]               # empty, outside the workspace
```

The prompt travels on stdin, so its size has no command-line limit. The
model id carries the effort (`-low`, `-medium`, `-high`); there is no
separate effort flag. Prompts follow `SKILL.md` § Delegation contract, header
lines included.

**Dispatch** is seat dispatch only, exactly as in `codex-exec.md`
§ Dispatch patterns: background Bash call labeled with the stage, stdout
redirected to a file, harvest `RUN_DIR/result.json` when the harness reports
the exit. No Workflow adapter. At most four Gemini runs in flight; the
subscription quota behind them is shared and its depth is unknown.

## Result contract

One JSON object on stdout, mirrored to `RUN_DIR/result.json`. `ok: true`
means: exit 0, status `SUCCESS`, no soft-denied tool, an unchanged workspace,
and a non-empty answer (with a schema: a `structured_output` object).
Schema conformance is the model's compliance; check the shape before use.

Fields: `result` (the structured object with a schema, otherwise the answer
text), `status`, `denied_actions`, `workspace_changed` / `changed_files`,
`conversation_id`, `spend` (`input_tokens`, `cache_read_tokens` counted
separately from input, `output_tokens`, `thinking_tokens`, `total_tokens`,
`wall_seconds`), `run_dir` (`events.jsonl`, `stderr.log`, `cli.log`), and on
failure `error_class`, `error` and `detail`. Failures still carry the
worker's answer and spend. In the stage line, fresh is `input_tokens` and
cached is `cache_read_tokens`; command count is not reported.

| `error_class` | Meaning | Move |
|---|---|---|
| `usage` | bad arguments | fix the call |
| `agy_missing` | no `agy` binary | lane down |
| `auth` | not logged in | lane down; the user logs in once |
| `model_unknown` | id not offered | pick an id from probe |
| `quota` | subscription quota or capacity exhausted | lane down for now; route to Luna |
| `timeout` | deadline hit; agy reports its own as `SUCCESS` with partial output | narrow the task or raise `--timeout` once |
| `tool_denied` | it needed a tool or path outside its grant | the result may be incomplete; rebrief without that need |
| `schema_missing` / `empty_result` | no usable answer | one rebrief, then Luna |
| `workspace_changed` | files changed during the run | check `changed_files`; unexplained changes are a stop |
| `agy_failed` | anything else | read `detail` and `stderr.log` |

## Billing and platforms

Runs use the subscription login; `GEMINI_API_KEY` and `GOOGLE_API_KEY` are
stripped from the worker environment. Verified on native Windows, WSL and
macOS; elsewhere, run probe and verify on the machine before relying on it.
On macOS over SSH, agy reported no login while a local terminal had one, so
the lane reads `auth` there; run it from a local session.
