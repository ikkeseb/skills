# Codex lane: worker contract

Read this before authoring the first Codex-lane stage in a workflow. The
invocation itself (flags, environment, concurrency, validation) lives in
`scripts/codex-worker.sh` — this file documents how to call it and what comes
back. Never hand-roll `codex` commands: shells may wrap `codex` in functions
that inject extra profile or config flags, and the helper bypasses all of
that by invoking the binary directly with a pinned flag set.

The recipe's dependency on the CLI is a **flag surface, not a version**: the
helper checks that `codex exec --help` still advertises every flag it passes
and ignores the version number entirely.

## Preflight

`"$HELPER"` throughout this file is the helper path resolved by the candidate
list in `SKILL.md` § Instrument — never a bare relative `scripts/…` path,
which would resolve against the session's cwd.

Run once per session before the first Codex-lane stage:

```bash
"$HELPER" probe                      # auth + flag contract, no model call
```

The helper requires Bash and `jq`; write-capable runs additionally require Git
and either `shasum` or `sha256sum`. `probe` makes no model call and returns
`{ok, codex_version, authenticated, contract_ok, missing_flags, dependencies,
sandbox_write, write_ready}`. A missing `jq` returns `missing_dependency`
immediately. `sandbox_write` is measured, not inferred: probe performs one
unbilled write inside the real OS sandbox (`codex sandbox`), because
dependency presence does not prove write capability — every write can be
rejected while git, jq and the hash tool all pass. On native Windows the
write lane is unsupported by default (see Write-worker gates), so probe
reports `sandbox_write: false` deterministically without engaging any
sandbox implementation — preflight never raises UAC, read-only sessions
included. A passing probe does not clear the lane
for later runs: the Windows sandbox has been observed degrading underneath a
`sandbox_write: true` probe within the minute (2026-08-11), so treat probe as
necessary, never sufficient, for write dispatch. `true`/`false` are verdicts and `false`
gates `write_ready`; `null` means the test could not run and gates nothing.
`write_ready: false` leaves the read-only lane available: route write stages
to the Claude lane and say so — except on native Windows, where that verdict
is policy, not a measurement: if the machine has a WSL VM, probe inside it
over the bridge first (§ Write-worker gates, WSL bullet); a green VM-side
probe makes the bridge the write route. Missing write dependencies fail closed as
`missing_dependency`; a write run dispatched despite a denying sandbox fails
closed as `sandbox_denied` at harvest.

Missing Codex, `authenticated: false`, or an empty `codex_version` means the
lane is down: route everything to the Claude lane and say so in the response —
never degrade silently. `contract_ok: false` alone is not an outage: name the
flags that disappeared and let read-only workers proceed; the helper refuses
write-capable runs until the invocation is fixed.

Flag presence proves the CLI still *accepts* the invocation, not that it still
*behaves* the same. After a Codex upgrade you care about, close that gap:

```bash
"$HELPER" verify                     # one tiny billed read-only run, ~20s
```

It exercises the real `run` path and asserts the whole envelope — contract,
`ok`, and schema conformance.

## Running a worker

```bash
"$HELPER" run \
  --model gpt-5.6-terra                # REQUIRED. Literal `default` selects
                                       #   the CLI's built-in model (runs pass
                                       #   --ignore-user-config, so this is
                                       #   NOT config.toml)
  --prompt-file "$DIR/prompt.md" \
  [--effort high]                      # default high
  [--sandbox read-only]                # or workspace-write (git workspace only)
  [--workspace "$PWD"]                 # the checkout/worktree the worker sees
  [--expected-base-sha "$SHA"]         # REQUIRED for workspace-write; refuses
                                       #   to run unless HEAD matches
  [--schema-file "$DIR/schema.json"]   # JSON Schema the result must satisfy;
                                       #   OpenAI strict-mode valid (below) —
                                       #   linted locally before dispatch
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
letting it surface as a 400 `invalid_json_schema` after a full worker
startup. The lint walks plain composition only — a violation hiding under
`oneOf`, `not`, `if`/`then`/`else`, or a `$ref` pointing outside `$defs`
passes locally and is caught only by the server — so keep schemas to that
plain shape and the local gate is meaningful.

Mint the run dir in the orchestrator before dispatch (`RUN_DIR="$(mktemp -d)"`
— pass a path that does not exist yet or is empty) and pass it with
`--run-dir`, so the result location is known even if the dispatching agent
never reports back. **Fresh run dir per attempt, always**: the helper refuses
a non-empty dir (mixed evidence). Suffix an attempt counter into both the
run-dir path and the dispatch prompt — the prompt edit also busts the
Workflow resume cache (see the resume notes in the orchestrate skill).
The run dir is helper-owned: adapters keep prompt and schema files elsewhere
and never create or write `RUN_DIR` themselves.

Sandbox choice is a write barrier, not an execution barrier: `read-only`
denies all writes but does not reliably block process spawning (verified in
upstream source, 2026-08-17). A read-only worker still cannot usefully run
tests, linters, or builds — they write caches and artifacts — so if the task
must *run* anything, use `workspace-write` in a throwaway worktree; keep
`read-only` for pure read-and-reason work, and don't ask a read-only worker
to execute gates.

Workers have no native file-read tool — every read is a shell command, so
never instruct a worker to avoid shell for reading; it has nothing else (a
corrective prompt that forbade shell reads bricked its retry outright).
Prompts for read-heavy stages steer reads to simple commands: `cat`,
read-only `git` subcommands, `rg`.

On native Windows the read lane needs a one-time machine setup. Codex ≥0.149
spawns every exec command through `pwsh.exe -Command`, and on read-only runs
(no OS sandbox, approvals `never`) its exec policy forbids every command that
no execpolicy allow-rule matches — the whole read lane fails
deterministically, independent of model and prompt wording (measured
2026-08-24 on 0.149.1; upstream main carries the same logic). Install the
bundled read allowlist once per machine:
`cp scripts/worker-read.rules "${CODEX_HOME:-$HOME/.codex}/rules/"`. Rules
files do load in worker runs (`--ignore-user-config` covers only
`config.toml`) and are evaluated against the pwsh-lowered inner commands, so
the allowlisted reads (`git status/diff/log/show/rev-parse/ls-files/grep`,
`cat`, `rg`, `ls`, `Get-Content`, `Get-ChildItem`, `Select-String`) run while
everything else stays forbidden. Before dispatching a read-heavy stage on
native Windows, check that file exists; without it, embed all material in the
prompt (bounded diffs) or route the stage to the Claude lane.

Two result-side guards, earned by a field run (2026-08-24) where a blocked
sol @ max review returned `ok: true` with zero findings: a read-only worker's
empty-but-valid result with `blocked by policy` rejections in its stderr is a
lane failure — retry with embedded material or the Claude lane, never accept
it as a clean "no findings" — and workers reviewing uncommitted state must be
told to fail loudly rather than fall back to a remote (GitHub/MCP/web) copy
of the repo, which silently reviews the wrong code.

The worker is not a blank slate, and no flag makes it one:
`--ignore-user-config` scopes to `config.toml` (its own help text says so),
so `$CODEX_HOME/AGENTS.md` is still loaded (measured 2026-07-28);
`project_doc_max_bytes=0` does not suppress it, and repointing `CODEX_HOME`
breaks auth. An inherited output ceiling or house style can therefore narrow
a stage's result with nothing in the envelope to show for it — prompts for
exhaustive work state their own volume expectation.

## Image-generation relay stages

For any stage that generates or edits an image (`$imagegen` or plain
"generate an image/photo/drawing" phrasing, edits of an existing raster
included), read `references/imagegen.md` before authoring the stage prompt —
it owns the relay contract: what to send (context and intent, not a pre-baked
prompt), output collection, and edit-instruction shape. Model/effort pin:
`model-map.md` § Routing rules, relay-stage exception.

Transparency is an output property, not a prompt claim. When the result needs
a transparent background, inspect the returned PNG for an alpha channel with
at least one non-opaque pixel before accepting it. An RGB image, a fully
opaque alpha channel, or checkerboard painted into the pixels is a failed
result; route the request to a generation path that can produce alpha instead
of prompting this relay again.

## Adapter stages and dispatch patterns

Three patterns. Pick by expected runtime and by whether a workflow is
running — at dispatch, never switching owners mid-job. Worker runtime is
task-shaped and not reliably predictable — a max-effort verification mandate
has run 86 tool steps over 14+ minutes — so don't tune `--timeout` per role:
leave headroom (the 3600 default is fine under background dispatch) and, for
verification-heavy prompts, state a time/effort budget in the prompt itself
(e.g. "recon facts are already verified; spend your run on judgment; finish
within 30 minutes").

Every `--schema-file` an adapter passes is authored by the orchestrator
before dispatch: write it to the strict-mode contract under Running a
worker, or the helper fails the stage fast as `usage` (field, 2026-08-29:
one adapter round lost to a schema missing `additionalProperties: false`).

**Active-wait adapter stage — the default for long runs inside a workflow.**
Any run that *may* exceed ~8 minutes (max-effort work, verification mandates,
real repo audits — in practice most substantive Codex-lane stages) runs as a
Workflow stage whose adapter agent starts the helper with the Bash tool's
`run_in_background`, then **holds its own turn open** by running bounded
foreground wait commands on `RUN_DIR/result.json` — each under the 600 s
Bash cap, repeated until the envelope lands — and relays it verbatim. The
adapter must never end its turn to "wait to be re-invoked":
re-invocation-on-background-exit exists only for the main loop, never for
subagents or Workflow stages (mechanism probes, 2026-08-25 — a stage that
ends its turn has its turn-end text recorded as the stage result and its
background job killed at workflow teardown; an earlier revision of this
recipe prescribed exactly that and lost a live worker, and its "field-
verified" claim was misattributed). The wait-loop pattern is probe-verified
including a timed-out cycle followed by delivery on the next. The
orchestrator still mints the run dir before dispatch: it stays the durable
locator and ground truth, and an adapter that dies or goes idle is recovered
from it exactly as under Delivery ownership below. Verified adapter prompt —
a default agent pinned per the relay-seat rule in `model-map.md` (fill the
UPPERCASE slots; substitute the literal helper path):

```
You are a one-shot Codex-lane adapter using BACKGROUND dispatch with an
ACTIVE WAIT. Do exactly this:
1. Create a private temp dir with mktemp -d. Write the worker prompt below
   to prompt.md in it, and (if given) the JSON schema below to schema.json.
   Never write either file into RUN_DIR; it is reserved for helper output.
2. Start this command with the Bash tool with run_in_background set to true:
   HELPER_ABS_PATH run --model MODEL --effort EFFORT --sandbox SANDBOX \
     --workspace WORKSPACE --prompt-file <tempdir>/prompt.md \
     --schema-file <tempdir>/schema.json --run-dir RUN_DIR --timeout 1500
3. Then IMMEDIATELY run this FOREGROUND command with the Bash tool's
   timeout parameter set to 600000. Never end your turn while the run is
   in progress — you will NOT be woken up again; an ended turn kills the
   worker:
   timeout 540 sh -c 'until [ -f RUN_DIR/result.json ]; do sleep 5; done;
     echo FOUND'
4. If it exits without printing FOUND, that is a normal wait-cycle timeout,
   not an error: run the same command again, up to 4 times total. Do not
   poll the background task, do not kill it, do not re-run the helper.
5. When FOUND prints, read RUN_DIR/result.json and return its ENTIRE
   content verbatim as your final message - no commentary, no code fences,
   no summary. If all 4 cycles pass without FOUND, return exactly:
   {"ok": false, "error_class": "codex_failed", "error": "adapter wait
   cycles exhausted before result.json appeared", "run_dir": "RUN_DIR"}
Rules: strictly one-shot, never retry, never touch the repo, never solve
the task yourself.
```

Four 540 s cycles bound the stage at ~36 minutes, which outlives the
helper's 1500 s deadline; a run sized beyond that belongs to main-loop
background dispatch below.

**Main-loop background dispatch + run-dir harvest — when no workflow is
running, and the recovery baseline always.** The main loop itself mints the
run dir, starts the helper with the Bash tool's `run_in_background`
(begin the command with a no-op label line — `: "STAGE MODEL@EFFORT — TOPIC"` —
the shell UI lists a background job by its command's first line, so name the
job there instead of leading with a temp-path assignment), and harvests
`RUN_DIR/result.json` — the helper's full envelope, written
atomically at termination — accepting the payload only on `ok: true` (the
verdict lives in the envelope, never in `final.json`, which is just the raw
model payload). Always redirect the helper's stdout to a file: some failures
emit their envelope on stdout only (see recovery step 2). The main loop owns
delivery from the start; no adapter agent is involved.

**Foreground adapter relay — short runs only.** The Bash tool's timeout
parameter is hard-capped at 600000 ms and the call auto-backgrounds past it,
which silently breaks a foreground relay: the invariant "tool timeout
outlives helper deadline" is only satisfiable under 600 s. So relay through
an adapter only when the run is confidently short (small prompt, low/medium
effort), with helper `--timeout 540` and Bash timeout 600000 — 540 is a
total deadline (queue wait included), so it genuinely bounds the whole call
under 600 s even when slots are contended. A run that may need more time is a
background-dispatch case, full stop — do not raise the relay numbers.

For the relay, prefer the `codex-worker` agent type when it appears in the
session's agent list — plugin installs namespace it as
`ikkeseb-skills:codex-worker`. Otherwise (e.g. skills installed by symlink,
which carries no agents) spawn a default agent as the adapter — sonnet at
low effort, the same pin the `codex-worker` agent carries — with this verified prompt (fill the
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
with a matching Workflow `schema` so the orchestrator gets typed data. Treat
the run dir as ground truth even on success: adapters have been observed
wrapping the JSON in code fences or prose despite the verbatim instruction,
so when anything about the relayed text is off, parse `RUN_DIR/result.json`
and gate on its `ok` verdict instead of fighting the relay; anything beyond
that follows Delivery ownership below.

## Delivery ownership and lost-adapter recovery

Delivery ownership is fixed at dispatch (`SKILL.md` § Delegation contract);
the pattern specifics: main-loop dispatches are main-loop-owned by
construction; a foreground adapter owns delivery by blocking on the single
helper call and relaying stdout — legitimate only while the call stays
foreground for the whole run; an active-wait adapter owns delivery by
holding its turn open through bounded wait cycles until the envelope lands —
its turn ending without a relayed envelope is a lost delivery, never a pause
(no harness wakes it back up). If an adapter dies, returns no
JSON, or sits idle after its run is terminal, it is evidence of a lost
delivery, not a paused one: never ping or re-invoke it. Recover from ground
truth in the orchestrator-minted `--run-dir`, using the same terminal-state
check as a normal background harvest:
  1. Terminal-state check: `RUN_DIR/result.json` exists → the helper
     finished and that file is the authoritative envelope; parse it and gate
     on `ok: true` exactly as if it had arrived on stdout (`result` holds
     the payload). Done — skip the remaining steps.
  2. No `result.json`: check the captured stdout before inferring death.
     Failures *before* the run dir exists and passes its gates — `usage`
     (bad flags, unreadable prompt or schema, strict-mode lint rejection,
     non-empty run dir), `codex_missing`, `missing_dependency` — and the
     `interrupted` class emit their envelope on **stdout only**, with no
     `run_dir` field and no `result.json`. A stdout envelope is the verdict.
  3. No `result.json`, no stdout envelope: the helper itself died mid-run.
     Establish death first — the helper (and codex) processes are gone. Then
     `events.jsonl` is the evidence: with a `turn.completed` event
     (`jq -Rrse '[split("\n")[] | fromjson? | .type] |
     index("turn.completed") != null' RUN_DIR/events.jsonl`),
     `RUN_DIR/final.json` holds the model payload — usable, but degraded: no
     helper verdict exists, so apply the stage's schema expectations yourself
     and say the envelope was lost. For write runs, the workspace diff is the
     artifact — inspect it as usual.
  4. No `result.json`, no `turn.completed`, no live process → the run died;
     treat as `codex_failed` with `events.jsonl` + `stderr.log` as evidence.
     A live process with a quiet log is NOT dead — log staleness is
     suspicion, never kill authority; recheck the PID before any cleanup.
  5. Cleanup is identity-scoped: kill only processes traceable to this run
     (children of the recorded helper PID / processes whose cwd or args
     reference RUN_DIR), never by broad name-matching.

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
`base_sha` / `dirty_before` (git state when the run started),
`workspace_changed` (write runs: whether the tree differs after the run,
taken before the workspace lock is released — `ok: true` with
`workspace_changed: false` is an empty-handed worker whose summary must not
be trusted as work done; `null` on read-only runs or when the after-status
itself failed), `run_dir` (events.jsonl + stderr.log for diagnosis), and on
failure `error_class` / `error` / `api_error`.

Failure classes and what to do. This is the single retry/fallback policy —
the adapter agent is strictly one-shot, and every decision below belongs to
the orchestrator. Never blind-retry a `workspace-write` failure of any
class: the tree may hold a partial change that must be inspected, not
overwritten.

- `rate_limit` — transient. Read-only stages: either retry once with backoff
  or route the stage to the Claude lane (the lanes bill separately, so the
  other lane is usually still open); pick one, don't stack both.
- `auth`, `codex_missing`, `missing_dependency` — lane is down; degrade to
  Claude lane, report it.
- `config` — the invocation itself is wrong (bad model name, unsupported
  effort — see `api_error`); fix the call, don't retry blindly.
- `contract_mismatch` — the CLI no longer advertises a flag the runner passes,
  and a write run was refused. The message names the missing flags; read-only
  workers may proceed; fix the invocation, then `verify`. Not a lane outage
  and not retryable.
- `base_sha_mismatch`, `git_error`, `workspace_locked` — the workspace isn't
  in the expected state; fix the orchestration, not the worker.
- `timeout`, `codex_failed`, `schema`, `slots_exhausted` — judgment call;
  read `run_dir` evidence before deciding. On `codex_failed` or suspicious
  stderr, check `references/codex-troubleshooting.md` § Known stderr signals
  first — one known Windows crash signature must re-route to the Claude
  lane, never retry.
- `dirty_worktree` — a write run against a dirty tree was refused (untracked
  files count); see Write-worker gates.
- `sandbox_denied` — the OS sandbox degraded underneath a write run and
  rejected every write, while the CLI still exited 0 with a completed turn.
  A deterministic environment failure, never a model miss: not retryable on
  this machine at any tier. Check probe's `sandbox_write`, fix the machine's
  sandbox setup, or route write stages to the Claude lane.
- `unsupported_lane` — the requested lane does not exist on this platform
  (today: native Windows workspace-write, see Write-worker gates). Policy,
  not an outage: never retryable at any tier; route the stage over a
  verified WSL VM's bridge when the machine has one, otherwise to the
  Claude lane or a verified worker host, and say so.
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
result — and it reacts to the prompt's framing, not to the artifact
(measured 2026-07-26: the same blocking hook died framed as bypass-hunting
and ran clean reviewed as parser correctness). Delegate only explicitly
source-only vulnerability recon to this lane; route binary scanning,
penetration testing, exploit generation, and genuine red-teaming of a
security control to the Claude lane or report them unsupported. A task that
truly is a correctness review should be dispatched as one — state the
cooperative context plainly and leave out attack vocabulary the task doesn't
need. Never disguise an adversarial task as cooperative to get it past the
filter; the filter firing on a genuinely adversarial prompt is lane
selection working. Do not degrade the whole lane over it, and treat a
suspected reroute as unverified without evidence.

## Write-worker gates

- A writing worker's workspace follows its write set (`SKILL.md` owns the
  isolation rule): the main tree when nothing else writes there, a dedicated
  worktree when the rule calls for one — pass it with `--workspace`. The
  helper also holds an exclusive per-workspace lock during write runs as a
  backstop.
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
  running against the wrong state. An untracked file the worker overwrites is
  invisible in the after-diff, so there is no attribution to recover — the
  dirty-tree refusal counts untracked files for exactly that reason.
- Native Windows: workspace-write workers are an **unsupported lane** and
  fail closed as `unsupported_lane` before dispatch. No sandbox
  implementation is a valid substitute there: the elevated sandbox turns
  multi-CODEX_HOME machines into a logon-failure → UAC-setup loop
  (openai/codex#36865), the unelevated token crashes MSYS/Cygwin child
  processes, and unpinned — `--ignore-user-config` drops the user's
  `[windows]` sandbox choice — leaves exec with no OS sandbox, so
  workspace-write silently degrades to read-only + approvals=never,
  rejecting every write behind an `ok` envelope. When the machine has a
  WSL VM whose write lane has passed per-machine verification (next
  bullet — a VM-side probe over the bridge is the runtime check), prefer
  bridging write stages through it over degrading them to the Claude
  lane; otherwise route them to the Claude lane or a verified
  macOS/Linux worker. Read-only runs stay unpinned
  and CLI-policy-enforced rather than OS-enforced — a deliberate trust
  downgrade for the read lane, measured working. No worker lane may raise
  UAC. Escape hatch: `CODEX_WORKER_NATIVE_WINDOWS_WRITE=elevated` restores
  the elevated pin on write runs for a deliberately repaired
  single-CODEX_HOME machine — an explicit human choice, never a default.
  Under that opt-in `.git` stays write-denied inside the sandbox, so a write
  worker edits files but cannot stage or commit — integration is main-loop
  work anyway; do not ask a Windows write worker to commit.
- A WSL VM on a Windows machine is **not** the native Windows lane: inside
  the VM `uname` reports Linux, the landlock sandbox applies, and
  workspace-write follows the supported Linux lane. Per-machine runner
  verification (probe plus one write e2e) still applies before trusting a
  new VM's write lane, as for any Linux host. The lane is also reachable
  *from* a native-Windows orchestrator: invoke the helper inside the VM
  (`wsl.exe -e bash -c '…'`) with the run dir minted on the VM side, and
  harvest the same envelope; workspaces under `/mnt/c` work, so the VM can
  write into checkouts the Windows session is orchestrating (git over drvfs
  is slow — prefer VM-side checkouts for heavy repos). A VM-side worktree can
  be registered under a `/home/...` path Windows Git cannot resolve. While
  any are registered, never run `git worktree prune` from Windows or use
  Windows Git to remove them; list and clean them inside the VM, and limit
  Windows-side removal to Windows paths. A bridged run that may be harvested
  after a VM restart uses a persistent VM-local run dir instead of `/tmp`,
  then removes it after harvest. Two other measured traps:
  a non-interactive WSL shell may lack the codex binary on PATH (PATH
  exports often live in interactive-only rc files) — export it explicitly
  in the bridge command or the run fails as `codex_missing`; and keep the
  whole payload as one quoted string so the Windows-side shell cannot
  path-mangle `/mnt/c/...` arguments (MSYS path conversion). A stopped VM
  auto-starts on the first call, adding seconds of latency.
- The result JSON proves the worker finished, not that the changes survive:
  read the actual `git diff` (and untracked files) in the worktree before the
  workflow's worktree cleanup can discard it, and let the main loop apply or
  merge changes sequentially. If the repo uses `.gitattributes` `filter=`
  drivers, read `references/codex-troubleshooting.md` § Lossy clean filters
  before trusting the gate or the after-diff — a lossy filter can blind both,
  and the length-preserving case silently discards the worker's change with
  the worktree.

## Billing guard

Workers authenticate via the Codex login (subscription quota); `CODEX_API_KEY`
/ `CODEX_ACCESS_TOKEN` in the orchestrator's environment are not forwarded
unless `CODEX_WORKER_ALLOW_API_KEY=1` is set explicitly.

## Concurrency

The helper holds a semaphore of 4 concurrent workers (override:
`CODEX_WORKER_MAX_SLOTS`); extra workers queue up to 30 minutes, then fail as
`slots_exhausted`. Workflow concurrency is higher than 4, so batch Codex-lane
stages in groups of ≤4 — queued workers burn workflow agent slots doing
nothing. The semaphore is per-orchestrator, not machine-global (its lock tree
lives under `$TMPDIR`, scoped per uid). Queue wait is bounded by each run's
own `--timeout` — a *total* deadline — so a short-timeout run that sits in
the queue fails as `timeout`, not `slots_exhausted`; don't read the class as
proof the queue was clear.

Done when: every dispatched worker ends in exactly one of — adapter-relayed
JSON (typed via the Workflow `schema` option), a main-loop harvest from its
`--run-dir` with the evidence above, or a recorded failure with `run_dir`
evidence; every failure path degrades loudly or surfaces evidence — no
silent fallback, no job closed off an idle notification, and no adapter ever
pinged to deliver.
