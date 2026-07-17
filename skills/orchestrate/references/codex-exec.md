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
```

Prefer dispatching through the `codex-worker` agent type when it appears in
the session's agent list — plugin installs namespace it as
`ikkeseb-skills:codex-worker`; otherwise (e.g. skills installed by symlink,
which carries no agents) give any default agent the helper's absolute path
and parameters. Either way the agent relays
the helper's JSON verbatim as its final message — pair it with a matching
Workflow `schema` so the orchestrator gets typed data.

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
