# Codex lane: worker contract

Read this before authoring the first Codex-lane stage in a workflow. The
invocation itself (flags, environment, concurrency, validation) lives in
`scripts/codex-worker.sh` — this file documents how to call it and what comes
back. Never hand-roll `codex` commands in prompts; shells may wrap `codex` in
functions that inject extra profile or config flags, and the helper bypasses
all of that by invoking the binary directly with a pinned flag set.

The recipe is verified against codex-cli 0.144.5. `probe` reports
`version_matches`; after a major Codex upgrade, re-verify before trusting the
lane.

## Preflight

Run once per session before the first Codex-lane stage:

```bash
scripts/codex-worker.sh probe
```

Returns `{ok, codex_version, authenticated, version_matches, ...}`. On
`ok: false`, the lane is down: route everything to the Claude lane and say so
in the response — never degrade silently. On `version_matches: false` the
CLI has drifted from the series the recipe was verified against: read-only
workers may proceed (state the mismatch in the response), and the helper
itself refuses write-capable runs until the recipe is re-verified and its
pinned series bumped.

## Running a worker

```bash
scripts/codex-worker.sh run \
  --model gpt-5.6-terra \
  --prompt-file "$DIR/prompt.md" \
  [--effort high]                      # default high; server rejects values a
                                       #   model doesn't support (clear api_error)
  [--sandbox read-only]                # or workspace-write (git workspace only)
  [--workspace "$PWD"]                 # the checkout/worktree the worker sees
  [--expected-base-sha "$SHA"]         # refuse to run unless HEAD matches;
                                       #   REQUIRED for workspace-write
  [--schema-file "$DIR/schema.json"]   # JSON Schema the result must satisfy;
                                       #   must be OpenAI strict-mode valid
                                       #   (see below) — the helper lints it
                                       #   locally before dispatch
  [--timeout 3600]
  [--run-dir "$RUN_DIR"]               # orchestrator-minted empty dir; the
                                       #   durable result locator (see
                                       #   Delivery ownership)
```

Schema files run under OpenAI **strict mode**: every object level needs
`additionalProperties: false` and a `required` array listing *every* key in
`properties` — optional keys are expressed as required-but-nullable, never
omitted. The helper lints this locally and fails fast (`usage`) instead of
letting it surface as a 400 `invalid_json_schema` after a full worker
startup.

Mint the run dir in the orchestrator before dispatch (`RUN_DIR="$(mktemp -d)"`
— pass a path that does not exist yet or is empty) and pass it with
`--run-dir`, so the result location is known even if the dispatching agent
never reports back. **Fresh run dir per attempt, always**: the helper refuses
a non-empty dir (mixed evidence), and a retry that reuses the previous
attempt's path — which is exactly what a Workflow resume replays — fails on
that guard. Suffix an attempt counter into both the run-dir path and the
dispatch prompt (the prompt edit also busts the resume cache; see the resume
notes in the orchestrate skill).

Sandbox choice is about execution, not just writes: `read-only` blocks **all
process spawning**, so a read-only worker cannot run tests, linters, or even
`node --check` — it can only read and reason. If the task must *run* anything,
use `workspace-write` in a throwaway worktree; keep `read-only` for pure
read-and-reason work, and don't ask a read-only worker to execute gates.

Worker runtime is task-shaped and not reliably predictable — a max-effort
verification mandate has been observed running 86 tool steps over 14+
minutes. Don't tune `--timeout` per role; leave headroom (the 3600 default is
fine under background dispatch) and, for verification-heavy prompts, state a
time/effort budget in the prompt itself (e.g. "recon facts are already
verified; spend your run on judgment; finish within 30 minutes").

## Two dispatch patterns

Pick by expected runtime, at dispatch, and never switch owners mid-job:

**Background dispatch + run-dir harvest — the default.** Any run that *may*
exceed ~8 minutes (max-effort work, verification mandates, real repo audits —
in practice most Codex-lane stages) is dispatched by the main loop itself:
mint the run dir, start the helper with the Bash tool's `run_in_background`,
and harvest `RUN_DIR/final.json` on `turn.completed` (terminal-state check
below). The main loop owns delivery from the start; no adapter agent is
involved. This is the primary delivery path, not a recovery mode — the
foreground relay's timing contract structurally cannot hold for long runs.

**Foreground adapter relay — short runs only.** The Bash tool's timeout
parameter is hard-capped at 600000 ms and the call auto-backgrounds past it,
which silently breaks a foreground relay: the invariant "tool timeout
outlives helper deadline" is only satisfiable under 600 s. So relay through
an adapter only when the run is confidently short (small prompt, low/medium
effort), with helper `--timeout 540` and Bash timeout 600000. A run that
would need more time is a background-dispatch case, full stop — do not raise
the relay numbers.

For the relay, prefer the `codex-worker` agent type when it appears in the
session's agent list — plugin installs namespace it as
`ikkeseb-skills:codex-worker`. Otherwise (e.g. skills installed by symlink,
which carries no agents) spawn a default agent as the adapter — sonnet at
low effort is right for the relay — with this verified prompt (fill the
UPPERCASE slots; keep the rules verbatim, each guards an observed failure
mode; for write workers swap in the write-gate flags below):

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
it; return the raw error text instead.
```

The adapter relays the helper's JSON verbatim as its final message — pair it
with a matching Workflow `schema` so the orchestrator gets typed data. But
treat the run-dir as ground truth even on success: adapters have been
observed wrapping the JSON in code fences or prose despite the verbatim
instruction, so when anything about the relayed text is off, parse
`RUN_DIR/final.json` instead of fighting the relay.

## Delivery ownership and lost-adapter recovery

One job, one delivery owner, fixed at dispatch. Background dispatches are
main-loop-owned by construction. For foreground relays, the adapter blocks
on the single helper call and relays stdout — legitimate only while the call
stays foreground for the whole run. If an adapter goes idle or dies without
returning JSON, ownership does NOT bounce back through the adapter. Never
ping or re-invoke it — an idle adapter is evidence of a lost delivery, not a
paused one. Recover from ground truth in the orchestrator-minted
`--run-dir`, using the same terminal-state check as a normal background
harvest:
  1. Terminal-state check: the helper (and codex) processes are gone AND
     `events.jsonl` contains a `turn.completed` event. `jq -Rrse
     '[split("\n")[] | fromjson? | .type] | index("turn.completed") != null'
     RUN_DIR/events.jsonl`
  2. Harvest: `RUN_DIR/final.json` is the worker's final message (parse it;
     apply the same schema expectations as the stage). For write runs, the
     workspace diff is the artifact — inspect it as usual.
  3. No `turn.completed` and no live process → the run died; treat as
     `codex_failed` with `events.jsonl` + `stderr.log` as evidence. A live
     process with a quiet log is NOT dead — log staleness is suspicion,
     never kill authority; recheck the PID before any cleanup.
  4. Cleanup is identity-scoped: kill only processes traceable to this run
     (children of the recorded helper PID / processes whose cwd or args
     reference RUN_DIR), never by broad name-matching.

Done when: every dispatched worker ends in exactly one of — adapter-relayed
JSON, a main-loop harvest from its `--run-dir` with the evidence above, or a
recorded failure with `run_dir` evidence. No job is closed off an idle
notification, and no adapter is ever pinged to deliver.

## Result contract

One JSON object on stdout. `ok: true` means all of: exit 0, a
`turn.completed` event observed, and a parseable (schema-valid, if given)
final message. Fields: `result` (the parsed final message — the payload),
`base_sha` / `dirty_before` (git state when the run started), `run_dir`
(events.jsonl + stderr.log for diagnosis), and on failure `error_class` /
`error` / `api_error`.

Failure classes and what to do. This is the single retry/fallback policy —
the adapter agent is strictly one-shot, and every decision below belongs to
the orchestrator:

- `rate_limit` — transient. Read-only stages: either retry once with backoff
  or route the stage to the Claude lane (the lanes bill separately, so the
  other lane is usually still open); pick one, don't stack both.
- `auth`, `codex_missing`, `missing_dependency` — lane is down; degrade to
  Claude lane, report it.
- `config` — the invocation itself is wrong (bad model name, unsupported
  effort — see `api_error`); fix the call, don't retry blindly.
- `version_mismatch` — the CLI drifted from the verified series and a write
  run was refused; re-verify the recipe before write-capable work.
- `base_sha_mismatch`, `git_error`, `workspace_locked` — the workspace isn't
  in the expected state; fix the orchestration, not the worker.
- `timeout`, `codex_failed`, `schema`, `slots_exhausted` — judgment call;
  read `run_dir` evidence before deciding.
- `dirty_worktree` — a write run against a dirty tree was refused; see gates.

Never blind-retry a `workspace-write` failure of any class: the tree may hold
a partial change that must be inspected, not overwritten.

Known signals when reading `stderr.log` on 0.144.x:

- `failed to load/renew models cache: missing field supports_reasoning_summaries`
  recurring on every run is harmless noise (stale `~/.codex` models cache vs
  a newer CLI schema) — don't let it mask the real failure line.
- On Windows, repeated `code-mode host closed its stdout` with exit code
  `-1073741502` (0xC0000142, STATUS_DLL_INIT_FAILED) is an intermittent
  Codex-CLI runtime crash, observed under heavy `max`-effort runs. It is an
  availability failure, not a quality miss: re-route the stage to the Claude
  lane instead of retrying the crash lottery.

## Write-worker gates

- One dedicated git worktree per writing worker — in Workflow scripts, spawn
  the wrapper agent with `isolation: 'worktree'` and run the helper with
  `--workspace` pointing at that worktree. Never share a writing checkout;
  the helper also holds an exclusive per-workspace lock during write runs as
  a backstop.
- The helper refuses `workspace-write` on a dirty tree and on non-git
  workspaces, and re-reads git state (and the CLI version) after any queue
  wait, immediately before launch. `--expected-base-sha` is mandatory for
  write runs so a moved HEAD fails closed (`base_sha_mismatch`) instead of
  running against the wrong state.
- The result JSON proves the worker finished, not that the changes survive:
  read the actual `git diff` (and untracked files) in the worktree before the
  workflow's worktree cleanup can discard it, and let the main loop apply or
  merge changes sequentially.

## Billing guard

Workers authenticate via the Codex login (subscription quota). `CODEX_API_KEY`
/ `CODEX_ACCESS_TOKEN` in the orchestrator's environment are NOT forwarded
unless `CODEX_WORKER_ALLOW_API_KEY=1` is set explicitly — a stray key must
never silently move worker traffic onto metered API billing.

## Concurrency

The helper holds a machine-global semaphore of 4 concurrent workers (override:
`CODEX_WORKER_MAX_SLOTS`); extra workers queue up to 30 minutes, then fail as
`slots_exhausted`. Workflow concurrency is higher than 4, so batch Codex-lane
stages in groups of ≤4 — queued workers burn workflow agent slots doing
nothing.

Done when: every Codex-lane stage returns the helper's JSON (typed via the
Workflow `schema` option), and every failure path either degrades loudly or
surfaces evidence — no silent fallback.
