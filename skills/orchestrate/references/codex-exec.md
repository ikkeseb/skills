# Codex lane: worker contract

Read this before dispatching the first Codex-lane stage. The invocation
itself (flags, environment, concurrency, validation) lives in
`scripts/codex-worker.sh`; this file says how to call it and what comes
back. Never hand-roll `codex` commands: shells may wrap `codex` in
functions that inject profile or config flags, and the helper invokes the
binary directly with a pinned flag set. The helper depends on a flag
surface, not a version: it checks that `codex exec --help` still
advertises every flag it passes.

`"$HELPER"` throughout is the helper path resolved by the candidate list in
`SKILL.md` § Instrument, never a bare relative `scripts/…` path.

Platform lanes (native Windows read allowlist, the WSL bridge), the failure
class catalog and lost-delivery recovery live in
`codex-troubleshooting.md`; read it on any failure envelope, and before the
first dispatch on a Windows machine.

## Preflight

Once per session before the first Codex-lane stage:

```bash
"$HELPER" probe                      # auth + flag contract, no model call
```

Returns `{ok, codex_version, authenticated, contract_ok, missing_flags,
dependencies, read_mode, lane, sandbox_write, write_ready}`. Needs Bash and
`jq`; write runs also need Git and `shasum` or `sha256sum`. `read_mode` is
`full-shell` on macOS, Linux and WSL, `allowlisted-single-command` on
native Windows. `sandbox_write` is measured (one unbilled write inside the
real OS sandbox), so `true`/`false` are verdicts and `null` means the test
could not run; a passing probe is necessary, never sufficient, for a write
dispatch, because the sandbox has degraded underneath a green probe within
the minute.

- Missing Codex, `authenticated: false` or an empty `codex_version`: the
  lane is down. Route everything to the Claude lane and say so; never
  degrade silently.
- `contract_ok: false` alone is not an outage: name the missing flags and
  let read-only workers proceed; the helper refuses write runs until the
  invocation is fixed.
- `write_ready: false` leaves the read lane open: route write stages to
  the Claude lane and say so. On native Windows that verdict is policy
  (troubleshooting § Platform lanes).

After a Codex upgrade you care about, `"$HELPER" verify` runs one small
billed read-only run and asserts the whole envelope: contract, `ok`,
schema conformance, and a read canary (the worker must report a token
`verify` just wrote into its workspace). Flag presence proves the CLI still
accepts the invocation; only verify proves it still behaves.

## Running a worker

```bash
"$HELPER" run \
  --model gpt-5.6-terra                # REQUIRED; exact Codex model ID
  --prompt-file "$DIR/prompt.md" \
  [--effort high]                      # default high
  [--sandbox read-only]                # or workspace-write (git workspace only)
  [--workspace "$PWD"]                 # the checkout/worktree the worker sees
  [--expected-base-sha "$SHA"]         # REQUIRED for workspace-write
  [--schema-file "$DIR/schema.json"]   # JSON Schema the result must satisfy
  [--timeout 3600]                     # total deadline, queue wait included
  [--run-dir "$RUN_DIR"]               # orchestrator-minted empty dir
```

Runs pass `--ignore-user-config`, so the literal model `default` selects
the CLI's built-in model, not `config.toml`.

**Run dir.** Mint it in the orchestrator before dispatch
(`RUN_DIR="$(mktemp -d)"`) and pass it with `--run-dir`, so the result
location is known even if the dispatching agent never reports back. Fresh
dir per attempt: the helper refuses a non-empty dir. Suffix an attempt
counter into both the run-dir path and the prompt; the prompt edit also
busts the Workflow resume cache. The run dir is helper-owned: keep prompt
and schema files elsewhere.

**Schema.** Files run under OpenAI strict mode: every object level needs
`additionalProperties: false` and a `required` array listing every key in
`properties`; optional keys are required-but-nullable. The helper lints
plain composition locally and fails fast as `usage`; a violation under
`oneOf`, `not`, `if`/`then`/`else` or a `$ref` outside `$defs` reaches the
server, so keep schemas to the plain shape.

**Sandbox.** `read-only` denies writes but does not block process
spawning. A read-only worker still cannot usefully run tests, linters or
builds (they write caches), so a stage that must run anything uses
`workspace-write` in a throwaway worktree; keep `read-only` for pure
read-and-reason work.

**Worker prompts.** Workers read only through shell commands; never
forbid shell reads (a prompt that did so bricked its retry). A worker
reviewing uncommitted state must be told to fail loudly rather than fall
back to a remote copy of the repo. The worker is not a blank slate:
`$CODEX_HOME/AGENTS.md` still loads under `--ignore-user-config`, so an
inherited output ceiling or house style can narrow a result with nothing
in the envelope to show for it; prompts for exhaustive work state their
own volume expectation. Image-generation stages read
`references/imagegen.md` before the prompt is written; their pin is
`model-map.md` § Routing rules, relay-stage exception.

## Dispatch patterns

Seat dispatch is the default for every Codex stage; the foreground adapter
is the Workflow exception. Pick at dispatch and never switch owners
mid-job. Worker runtime is task-shaped (a max-effort verification has run
86 tool steps over 14 minutes), so leave `--timeout` at its default; the
prompt's `budget:` line (SKILL.md § Delegation contract) bounds the run and
the timeout only catches a hang. Every `--schema-file` is authored by the
orchestrator before dispatch.

**Seat dispatch and run-dir harvest.** The seat writes the stage's prompt
and schema to a private dir, mints the run dir, and starts the helper with
the Bash tool's `run_in_background`, `description` set to the stage label.
The command opens with the same label as a no-op line (the shell UI lists a
background job by its first line) and redirects stdout to a file, because
some failures emit their envelope on stdout only:

```bash
: "r1 authority — gpt-5.6-terra @ high"
"$HELPER" run --model gpt-5.6-terra --effort high --sandbox read-only \
  --workspace "$PWD" --prompt-file "$DIR/prompt.md" \
  --schema-file "$DIR/schema.json" --run-dir "$RUN_DIR" > "$DIR/stdout.json"
```

One call per stage, at most four in flight (§ Concurrency); the seat keeps
specifying the next piece while they run. Claude Code re-invokes the seat
when a background command exits: harvest `RUN_DIR/result.json` (the full
envelope, written atomically at termination), accept the payload only on
`ok: true`, and print the stage line from `spend` (SKILL.md § Modes and
reporting). A harness without an exit signal waits on the run dir in
bounded foreground calls instead:
`sh -c 'i=0; until [ -f "$RUN_DIR/result.json" ] || [ $i -ge 108 ]; do sleep 5; i=$((i+1)); done'`
(540 s per call, repeated).

**Foreground adapter.** Only a per-item pipeline that must mix lanes puts
a Codex stage inside a Workflow, because every Workflow stage is a Claude
agent that replays its own context (~25k tokens) on every tool call. Keep
it to one call: the seat writes the prompt and schema files before the
workflow starts and passes their paths in the briefing. The Bash tool's
timeout is hard-capped at 600000 ms and auto-backgrounds past it, which
silently breaks a foreground relay, so the helper runs with `--timeout
540` and the stage must be confidently short; a run that may need more is
seat dispatch, full stop. Never let an adapter end its turn to wait for
re-invocation: that signal exists only for the seat.

Prefer the `codex-worker` agent type when the session's agent list has it
(plugin installs namespace it as `ikkeseb-skills:codex-worker`). Otherwise
spawn a default agent as the adapter, sonnet at low effort, with this
prompt (fill the UPPERCASE slots; keep the rules verbatim, each guards an
observed failure; `HELPER_ABS_PATH` is `"$HELPER"` expanded, since the
adapter resolves nothing for itself; for write workers add the write-gate
flags):

```
You are a one-shot Codex-lane adapter. Do EXACTLY this, nothing else:
1. Run this exact command with Bash in a SINGLE FOREGROUND invocation, with
   the Bash tool's timeout parameter set to 600000 — it may legitimately
   take several minutes (including a worker-slot queue wait); do NOT kill,
   re-run, or modify it:
   HELPER_ABS_PATH run --model MODEL --effort EFFORT \
     --sandbox read-only --workspace WORKSPACE \
     --prompt-file PROMPT_FILE --schema-file SCHEMA_FILE \
     --run-dir RUN_DIR --timeout 540
2. Return the helper's ENTIRE stdout verbatim as your result.
Rules: strictly one-shot — never retry, never interpret or summarize the
result, never touch the repo. Foreground means foreground: never set
run_in_background, never append `&`, never end your turn with a "started,
waiting" style status while the command runs — an idle adapter is a lost
delivery. If you cannot keep the single blocking call open, do not start
it; return exactly this instead, with the reason substituted, so the
result stays machine-readable:
{"ok": false, "error_class": "codex_failed", "error": "adapter could not
hold a foreground call: REASON", "run_dir": "RUN_DIR"}
```

Pair the adapter with a matching Workflow `schema` so the orchestrator gets
typed data, and treat the run dir as ground truth even on success:
adapters have wrapped the JSON in fences or prose despite the instruction,
so when the relayed text is off, parse `RUN_DIR/result.json` and gate on
its `ok`.

**Delivery ownership** is fixed at dispatch. A seat dispatch is seat-owned
by construction. A foreground adapter owns delivery only while its single
call stays foreground; its turn ending without an envelope is a lost
delivery, never a pause: never ping or re-invoke it, recover from the run
dir (troubleshooting § Lost delivery).

## Result contract

One JSON object on stdout, mirrored atomically to `RUN_DIR/result.json`.
`ok: true` means all of: exit 0, a `turn.completed` event observed, and a
final message that parses as exactly one JSON document (with a schema) or
is non-empty (without). The helper performs no JSON-Schema instance
validation; conformance is enforced server-side by `--output-schema`, so a
schema-shaped result is the model's compliance, not a local guarantee, and
a stage that must not act on malformed data checks the shape itself.

Fields: `result` (the parsed final message, the payload), `read_mode`,
`lane` (`native`, or `wsl-bridge` with `run_dir_wsl` beside `run_dir`),
`base_sha` / `dirty_before` (git state at start), `workspace_changed`
(write runs: whether the tree differs after the run; `ok: true` with
`workspace_changed: false` is an empty-handed worker whose summary must
not be trusted as work done; `null` on read-only runs), `spend` (command
items, token usage, wall seconds: the per-stage cost the final report
lists), `run_dir` (`events.jsonl` and `stderr.log` for diagnosis), and on
failure `error_class` / `error` / `api_error`.

Every retry and fallback decision belongs to the orchestrator; the adapter
is strictly one-shot. Never blind-retry a `workspace-write` failure of any
class: the tree may hold a partial change to inspect. The failure classes
and the move each one earns: troubleshooting § Failure classes.

**Provider content filtering is a lane-selection input, not an outage.**
OpenAI's cybersecurity classifier kills a run mid-flight (`api_error`, no
result) on the prompt's framing, not the artifact: the same hook died
framed as bypass-hunting and ran clean reviewed as parser correctness.
Delegate only explicitly source-only vulnerability recon to this lane;
route binary scanning, penetration testing, exploit generation and
genuine red-teaming of a security control to the Claude lane or report
them unsupported. Dispatch a correctness review as one: state the
cooperative context plainly and leave out attack vocabulary the task does
not need, and never disguise an adversarial task as cooperative. The
filter firing on a genuinely adversarial prompt is lane selection working;
do not degrade the whole lane over it, and treat a suspected reroute as
unverified without evidence.

## Write-worker gates

- A writing worker's workspace follows its write set (`SKILL.md` owns the
  isolation rule): the main tree when nothing else writes there, a
  dedicated worktree otherwise, passed with `--workspace`. The helper holds
  an exclusive per-workspace lock during write runs as a backstop.
- A worktree isolates the working tree, not the repository: `.git`, hooks
  and `--local` config are shared, and a tracked symlink pointing outside
  the repo is materialized verbatim, so a write through it reaches live
  state with nothing in the worktree's `status` or `diff`. Isolation
  bounds the blast radius; it is not a sandbox.
- The helper refuses `workspace-write` on a dirty tree (untracked files
  count: a file the worker overwrites is invisible in the after-diff) and
  on non-git workspaces, and re-reads git state and the CLI version after
  any queue wait. `--expected-base-sha` is mandatory so a moved HEAD fails
  closed as `base_sha_mismatch`.
- Native Windows: `workspace-write` is an unsupported lane and fails closed
  as `unsupported_lane`. A machine with a verified WSL VM routes write
  stages over the WSL bridge; otherwise to the Claude lane or a verified
  macOS/Linux worker. Details, the elevated opt-in and the bridge's traps:
  troubleshooting § Platform lanes.
- The result JSON proves the worker finished, not that the changes
  survive: read the actual `git diff` and untracked files in the worktree
  before any worktree cleanup, and let the main loop apply or merge
  changes sequentially. If the repo uses `.gitattributes` `filter=`
  drivers, read troubleshooting § Lossy clean filters before trusting the
  gate or the after-diff.

## Billing guard

Workers authenticate via the Codex login (subscription quota);
`CODEX_API_KEY` / `CODEX_ACCESS_TOKEN` in the orchestrator's environment
are not forwarded unless `CODEX_WORKER_ALLOW_API_KEY=1` is set explicitly.

## Concurrency

The helper holds a semaphore of 4 concurrent workers
(`CODEX_WORKER_MAX_SLOTS`); extra workers queue up to 30 minutes, then
fail as `slots_exhausted`. Start at most four seat dispatches at a time
and launch the next as one harvests; in a Workflow, batch adapter stages
in groups of at most four, since queued workers burn agent slots doing
nothing. The semaphore is per-orchestrator (its lock tree lives under
`$TMPDIR`), not machine-global. Queue wait counts against each run's own
`--timeout`, so a short-timeout run that sits in the queue fails as
`timeout`, not `slots_exhausted`.

Done when: every dispatched worker ends in exactly one of a seat harvest
from its `--run-dir`, adapter-relayed JSON typed via the Workflow `schema`,
or a recorded failure with `run_dir` evidence; every failure path degrades
loudly; no job is closed off an idle notification, and no adapter is ever
pinged to deliver.
