# Codex lane: worker contract

Read this before authoring the first Codex-lane stage in a workflow. The
invocation itself (flags, environment, concurrency, validation) lives in
`scripts/codex-worker.sh` — this file documents how to call it and what comes
back. Never hand-roll `codex` commands in prompts; shells may wrap `codex` in
functions that inject extra profile or config flags, and the helper bypasses
all of that by invoking the binary directly with a pinned flag set.

The recipe's dependency on the CLI is a **flag surface, not a version**. The
helper checks that `codex exec --help` still advertises every flag it passes
and ignores the version number entirely. That replaced a pinned-series gate
whose failure mode was backwards: a routine release blocked every write-capable
worker (the 0.144 pin did exactly that), while a same-series release that
dropped a flag sailed through.

## Preflight

`"$HELPER"` throughout this file is the helper path resolved by the candidate
list in `SKILL.md` § Two worker lanes. Never write the path as a bare relative
`scripts/…`: it would resolve against the session's cwd, which is the repo
being worked on, not the one shipping this skill.

Run once per session before the first Codex-lane stage:

```bash
"$HELPER" probe                      # auth + flag contract, no model call
```

Returns `{ok, codex_version, authenticated, contract_ok, missing_flags}`. On
`ok: false` the lane is down: route everything to the Claude lane and say so in
the response — never degrade silently. `contract_ok: false` names the flags that
disappeared; read-only workers may proceed (state it), and the helper refuses
write-capable runs until the invocation is fixed.

Flag presence proves the CLI still *accepts* the invocation, not that it still
*behaves* the same. After a Codex upgrade you care about, close that gap:

```bash
"$HELPER" verify                     # one tiny billed read-only run, ~20s
```

It exercises the real `run` path and asserts the whole envelope — contract,
`ok`, and schema conformance. That is the re-verification; there is no manual
recipe ritual to perform.

## Running a worker

```bash
"$HELPER" run \
  [--model gpt-5.6-terra]              # omit to take the CLI's built-in
                                       #   default — note runs pass
                                       #   --ignore-user-config, so this is
                                       #   NOT your config.toml model. Omit
                                       #   when "current provider default" is
                                       #   what you want; name one when the
                                       #   tier or reproducibility matters
                                       #   (the envelope records model:"" for
                                       #   unpinned runs)
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
  [--timeout 3600]                     # TOTAL wall-clock deadline, worker-
                                       #   slot queue wait included
  [--run-dir "$RUN_DIR"]               # orchestrator-minted empty dir; the
                                       #   durable result locator (see
                                       #   Delivery ownership)
```

Schema files run under OpenAI **strict mode**: every object level needs
`additionalProperties: false` and a `required` array listing *every* key in
`properties` — optional keys are expressed as required-but-nullable, never
omitted. The helper lints this locally and fails fast (`usage`) instead of
letting it surface as a 400 `invalid_json_schema` after a full worker startup.
The lint is a fast filter, not a validator: it walks `properties`, `items`,
`anyOf`, `allOf`, `$defs`, and `definitions`, so a violation hiding under
`oneOf`, `not`, `if`/`then`/`else`, or a `$ref` pointing outside `$defs`
passes locally and is caught only by the server. Keep schemas to that plain
shape and the local gate is meaningful.

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
and harvest `RUN_DIR/result.json` — the helper's full envelope, written
atomically at termination — accepting the payload only on `ok: true` (the
verdict lives in the envelope, never in `final.json`, which is just the raw
model payload). The main loop owns delivery from the start; no adapter agent
is involved. This is the primary delivery path, not a recovery mode — the
foreground relay's timing contract structurally cannot hold for long runs.

**Foreground adapter relay — short runs only.** The Bash tool's timeout
parameter is hard-capped at 600000 ms and the call auto-backgrounds past it,
which silently breaks a foreground relay: the invariant "tool timeout
outlives helper deadline" is only satisfiable under 600 s. So relay through
an adapter only when the run is confidently short (small prompt, low/medium
effort), with helper `--timeout 540` and Bash timeout 600000. The helper's
`--timeout` is a total deadline including any worker-slot queue wait, so 540
genuinely bounds the whole call under 600 s even when slots are contended. A
run that would need more time is a background-dispatch case, full stop — do
not raise the relay numbers.

For the relay, prefer the `codex-worker` agent type when it appears in the
session's agent list — plugin installs namespace it as
`ikkeseb-skills:codex-worker`. Otherwise (e.g. skills installed by symlink,
which carries no agents) spawn a default agent as the adapter — sonnet at
low effort is right for the relay — with this verified prompt (fill the
UPPERCASE slots; keep the rules verbatim, each guards an observed failure
mode; for write workers swap in the write-gate flags below). `HELPER_ABS_PATH`
is `"$HELPER"` expanded — the adapter is a separate session that resolves
nothing for itself, so substitute the literal path, never the variable:

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
  1. Terminal-state check: `RUN_DIR/result.json` exists → the helper
     finished and that file is the authoritative envelope; parse it and gate
     on `ok: true` exactly as if it had arrived on stdout (`result` holds
     the payload). Done — skip the remaining steps.
  2. No `result.json`: the helper itself died mid-run. Establish death first
     — the helper (and codex) processes are gone. Then `events.jsonl` is the
     evidence: with a `turn.completed` event (`jq -Rrse '[split("\n")[] |
     fromjson? | .type] | index("turn.completed") != null'
     RUN_DIR/events.jsonl`), `RUN_DIR/final.json` holds the model payload —
     usable, but degraded: no helper verdict exists, so apply the stage's
     schema expectations yourself and say the envelope was lost. For write
     runs, the workspace diff is the artifact — inspect it as usual.
  3. No `result.json`, no `turn.completed`, no live process → the run died;
     treat as `codex_failed` with `events.jsonl` + `stderr.log` as evidence.
     A live process with a quiet log is NOT dead — log staleness is
     suspicion, never kill authority; recheck the PID before any cleanup.
  4. Cleanup is identity-scoped: kill only processes traceable to this run
     (children of the recorded helper PID / processes whose cwd or args
     reference RUN_DIR), never by broad name-matching.

Done when: every dispatched worker ends in exactly one of — adapter-relayed
JSON, a main-loop harvest from its `--run-dir` with the evidence above, or a
recorded failure with `run_dir` evidence. No job is closed off an idle
notification, and no adapter is ever pinged to deliver.

## Result contract

One JSON object on stdout, mirrored atomically to `RUN_DIR/result.json` so
background harvests read the identical envelope. `ok: true` means all of: exit
0, a `turn.completed` event observed, and a final message that parses as
exactly one JSON document (when a schema was given) or is non-empty (when it
wasn't). Note what that does *not* mean: the helper performs no JSON-Schema
instance validation. Conformance to `--schema-file` is enforced server-side by
`--output-schema` — so a schema-shaped result is the model's compliance, not a
local guarantee, and a stage that must not act on malformed data checks the
shape itself. Fields: `result` (the parsed final message — the payload),
`base_sha` / `dirty_before` (git state when the run started), `run_dir`
(events.jsonl + stderr.log for diagnosis), and on failure `error_class` /
`error` / `api_error`.

**The mirror has two holes, and background dispatch must cover them.** The run
dir is only known to the helper once it exists and passes its gates, so
failures *before* that point — `usage` (bad flags, unreadable prompt or schema,
strict-mode lint rejection, non-empty run dir) and `codex_missing` — emit their
envelope on **stdout only**, with no `run_dir` field and no `result.json`. The
`interrupted` class (the runner took a termination signal) is likewise
stdout-only. So a background dispatch always redirects stdout to a file and
reads it when `result.json` is absent; a missing `result.json` alone does not
mean the run died.

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
- `contract_mismatch` — the CLI no longer advertises a flag the runner passes,
  and a write run was refused. The message names the missing flags; fix the
  invocation, then `verify`. Not a lane outage and not retryable.
- `base_sha_mismatch`, `git_error`, `workspace_locked` — the workspace isn't
  in the expected state; fix the orchestration, not the worker.
- `timeout`, `codex_failed`, `schema`, `slots_exhausted` — judgment call;
  read `run_dir` evidence before deciding.
- `dirty_worktree` — a write run against a dirty tree was refused; see gates.
  Untracked files count: an untracked file the worker overwrites is invisible
  in the after-diff, so there is no attribution to recover.
- `unsafe_git_state` — the tree reads clean but the repo cannot be written to
  safely: an in-progress merge/rebase/cherry-pick/revert/bisect, or index
  entries marked `skip-worktree` / `assume-unchanged`, which hide changes from
  the clean check. Not retryable and not a lane outage; finish or abort the
  git operation, or give the worker a throwaway worktree.
- `usage` — the dispatch itself is malformed (bad flag, unreadable prompt or
  schema, strict-mode lint rejection, non-empty run dir). Fix the call. Never
  retried: nothing ran, and no `run_dir` evidence exists.
- `slot_root_hijacked` — the lock directory is a symlink or owned by another
  user. A local integrity problem, not a lane outage: do not degrade to the
  Claude lane and do not retry. Stop and surface it.
- `interrupted` — the runner took a termination signal. Whether the worker
  itself survived is unknown; establish ground truth from the run dir before
  redispatching, and for write runs inspect the worktree first.

**Provider content filtering is a lane-selection input, not an outage.**
OpenAI's cybersecurity classifier kills a run mid-flight — `api_error`, no
result — and it reacts to the prompt's framing, not to the artifact. Measured
across three runs on 2026-07-26: hunting bypasses in a blocking hook died;
the same hook reviewed as parser correctness ran clean; so did a security
review of a path-resolution fix framed as "argue the strongest case against
this". Red-teaming a security control belongs in the Claude lane — or reframe
it as a correctness review of the artifact, with the cooperative context
stated and no attack vocabulary. Do not degrade the whole lane over it.

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
- That worktree isolates the working tree, not the repository: `.git` is
  shared, so hooks and `--local` config stay common state — `git worktree add`
  runs the repo's own `post-checkout` hook before any worker starts — and a
  tracked symlink pointing outside the repo is materialized verbatim, so a
  write through it reaches live state with nothing in the worktree's `status`
  or `diff`. Isolation bounds the blast radius; it is not a sandbox.
- The helper refuses `workspace-write` on a dirty tree and on non-git
  workspaces, and re-reads git state (and the CLI version) after any queue
  wait, immediately before launch. `--expected-base-sha` is mandatory for
  write runs so a moved HEAD fails closed (`base_sha_mismatch`) instead of
  running against the wrong state.
- The result JSON proves the worker finished, not that the changes survive:
  read the actual `git diff` (and untracked files) in the worktree before the
  workflow's worktree cleanup can discard it, and let the main loop apply or
  merge changes sequentially.
- A *lossy* clean filter (`.gitattributes` `filter=`, e.g. one stripping
  volatile keys from a config file) breaks both the gate and that after-diff,
  reproducibly. Git compares *filtered* content, so `git diff` never shows a
  write inside the stripped region, and `git status` shows it only when the
  byte length changes — a bare ` M` against an empty diff. That `M` is what
  the gate refuses on, so such a repo blocks every write run until someone
  `git add`s the file. It looks like stale stat data and is not: git takes a
  size shortcut and never runs the filter.
- The length-preserving case is the dangerous one — invisible to gate and
  after-diff alike, and it survives `checkout`, `restore`, `stash` and
  `reset --hard`, so the worker's change is discarded with the worktree
  rather than merged. To see it, neutralise the driver
  (`git -c filter.<name>.clean=cat diff`, sound only where the filter has no
  smudge side) or compare the file against `git show HEAD:<path>`. Injective
  filters, `filter=lfs` among them, never do this: the blindness needs a
  many-to-one clean transform.

## Billing guard

Workers authenticate via the Codex login (subscription quota). `CODEX_API_KEY`
/ `CODEX_ACCESS_TOKEN` in the orchestrator's environment are NOT forwarded
unless `CODEX_WORKER_ALLOW_API_KEY=1` is set explicitly — a stray key must
never silently move worker traffic onto metered API billing.

## Concurrency

The helper holds a semaphore of 4 concurrent workers (override:
`CODEX_WORKER_MAX_SLOTS`); extra workers queue up to 30 minutes, then fail as
`slots_exhausted`. Workflow concurrency is higher than 4, so batch Codex-lane
stages in groups of ≤4 — queued workers burn workflow agent slots doing
nothing.

The semaphore is not machine-global: its lock tree lives under `$TMPDIR` and is
scoped per uid, so orchestrators running with different `TMPDIR` values (or as
different users) do not see each other and the real concurrency can exceed 4.
Treat 4 as a per-orchestrator budget. The 30-minute queue wait is also bounded
by each run's own `--timeout`, which is a *total* deadline — a short-timeout run
that sits in the queue fails as `timeout`, not `slots_exhausted`, so don't read
the class as proof the queue was clear.

Done when: every Codex-lane stage returns the helper's JSON (typed via the
Workflow `schema` option), and every failure path either degrades loudly or
surfaces evidence — no silent fallback.
