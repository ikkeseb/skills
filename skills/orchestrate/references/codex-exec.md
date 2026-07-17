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
  [--schema-file "$DIR/schema.json"]   # JSON Schema the result must satisfy
  [--timeout 3600]
  [--run-dir "$RUN_DIR"]               # orchestrator-minted empty dir; the
                                       #   durable receipt for lost-adapter
                                       #   recovery (see Delivery ownership)
```

Mint the run dir in the orchestrator before dispatch (`RUN_DIR="$(mktemp -d)"`
— pass a path that does not exist yet or is empty) and pass it with
`--run-dir`, so the result location is known even if the adapter never
reports back.

Prefer dispatching through the `codex-worker` agent type when it appears in
the session's agent list — plugin installs namespace it as
`ikkeseb-skills:codex-worker`. Otherwise (e.g. skills installed by symlink,
which carries no agents) spawn a default agent as the adapter — sonnet at
low effort is right for the relay — with this verified prompt (fill the
UPPERCASE slots; keep the rules verbatim, each guards an observed failure
mode; for write workers swap in the write-gate flags below):

```
You are a one-shot Codex-lane adapter. Do EXACTLY this, nothing else:
1. Run this exact command with Bash in a SINGLE FOREGROUND invocation, with
   the Bash tool's timeout parameter set to 900000 — it may legitimately
   take several minutes (including a worker-slot queue wait); do NOT kill,
   re-run, or modify it:
   HELPER_ABS_PATH run --model MODEL --effort EFFORT \
     --sandbox read-only --workspace WORKSPACE \
     --prompt-file PROMPT_FILE --schema-file SCHEMA_FILE \
     --run-dir RUN_DIR --timeout 840
2. Return the helper's ENTIRE stdout verbatim as your result.
Rules: strictly one-shot — never retry, never interpret or summarize the
result, never touch the repo. Foreground means foreground: never set
run_in_background, never append `&`, never end your turn with a "started,
waiting" style status while the command runs — an idle adapter is a lost
delivery. If you cannot keep the single blocking call open, do not start
it; return the raw error text instead.
```

Either way the adapter relays the helper's JSON verbatim as its final
message — pair it with a matching Workflow `schema` so the orchestrator
gets typed data.

## Delivery ownership and lost-adapter recovery

One job, one delivery owner, fixed at dispatch:

- **Foreground-relay** (the default above): the adapter blocks on the single
  helper call and relays stdout. This is legitimate delivery *only* because
  the call stays foreground for the whole run — the tool timeout (900s)
  exceeds the helper deadline (840s), so the helper always emits terminal
  JSON before the adapter's call can die.
- **Main-loop harvest** (fallback, not a mode to design for): if an adapter
  goes idle or dies without returning JSON, ownership does NOT bounce back
  through the adapter. Never ping or re-invoke it — an idle adapter is
  evidence of a lost delivery, not a paused one. Recover from ground truth
  in the orchestrator-minted `--run-dir`:
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
