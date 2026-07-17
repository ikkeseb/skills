---
name: orchestrate
description: Delegation posture — the main loop keeps everything critical (design, spec, review, integration) and routes mechanical execution to worker models, primarily through dynamic Workflow scripts, across Claude and Codex lanes. Single-task or sustained for the session.
disable-model-invocation: true
---

# orchestrate

Posture for how the main loop spends itself. Main-loop attention is the
scarce premium resource — spend it on judgment, never on labor. What stays
senior and what delegates is defined in The split below; mechanical execution
routes to worker models per `references/model-map.md` (read it once before
the first delegation of a run).

## The instrument

**Dynamic Workflow scripts are the primary instrument.** Invoking
`/orchestrate` is the explicit opt-in the Workflow tool requires. One-off
subagents or agent teams are a judgment call for work a workflow fits poorly
(e.g. a single delegated stage with nothing to fan out). And when delegation
itself is a poor fit, push back: say so and propose running sequentially in
the main loop instead of forcing the ceremony.

Worker invocations run inside delegated stages (Workflow `agent()` calls or
subagents) — main-loop worker runs are legitimate only as that explicitly
declared sequential fallback, never silent drift. Every delegated call pins
`{model, effort}` explicitly and returns typed data — Workflow stages via
the `schema` option — not prose to re-parse.

## Two worker lanes

- **Claude lane**: Workflow `agent()` calls — opus at high effort is the
  default workhorse.
- **Codex lane**: OpenAI models through the Codex CLI. All invocation
  mechanics live in `scripts/codex-worker.sh` — the single source of truth;
  never hand-roll `codex` commands in prompts. Read
  `references/codex-exec.md` before authoring the first Codex-lane stage.

Codex-lane preflight: run `scripts/codex-worker.sh probe` once per session
before first use. If it fails, run Claude-only and say so — degradation is
always loud. Done when: the response states which lanes were available.

## Verification coverage

For risk-triggered cross-provider verification (what qualifies, how to report
coverage) follow the routing rules in `references/model-map.md`.

## Modes

- `/orchestrate <task>` — single-task.
- `/orchestrate sustained` — session posture. Only an explicit user signal
  drops it (`orchestrate off`, `stop orchestrate`, or any unambiguous stop
  signal in any language); mid-session questions or redirects don't. New
  session starts fresh.

Open the first response with the marker `[orchestrate]` /
`[orchestrate sustained]`. No prescribed output format beyond that.

## The split

**Delegate** what can be specced tightly enough that a wrong interpretation
gets caught by review or tests: implementation against a written spec,
migrations, repetitive edits, test-writing against defined behavior,
recon/search sweeps, boilerplate. Frontend is no exception — the main loop
designs and specs it, then the mechanical build-out delegates like anything
else.

**Keep** anything where the decision ripples: design, architecture,
API/schema shape, naming, tradeoffs, ambiguous requirements,
security-sensitive calls — and always final review and integration.

**Floor:** if writing the spec takes longer than doing the work, do it in the
main loop. Small edits are not delegated.

## The contract

- **Good instructions are the senior deliverable.** Every delegated stage
  carries its spec and acceptance criteria in the prompt. Workers start empty
  — pass the skills, project context, and prior decisions they need, or they
  drift.
- **Senior review is mandatory.** Check every result against its acceptance
  criteria — read the diff, not the worker's summary. "Done" from a worker is
  a claim, not evidence. Never relay raw worker output.
- **One job, one delivery owner — chosen at dispatch, never switched.**
  A wrapper may deliver a result only while it stays strictly foreground:
  one blocking call, no interim "waiting" turn, until the worker exits. Any
  job that outlives its wrapper's turn (backgrounded, server-tracked,
  detached) is main-loop-harvest from the start: the main loop records a
  durable locator (run dir, task id) *before* dispatch and owns polling,
  terminal-state detection, harvest, and stray cleanup. Wrappers never
  babysit, and idle is never an ownership-transfer event.
- **Idle is not done — idle routes to evidence.** Agent and teammate idle
  notifications are scheduler state, not completion evidence. A stage is
  complete only when it has returned a result and the relevant diff or
  on-disk artifact has been inspected. On idle without a result, go straight
  to ground truth (the recorded locator, job state, workspace diff) — never
  ping the wrapper to resume delivery. The inverse guard stays: a state
  file claiming "running" is not liveness either — verify the PID and log
  freshness before waiting on it.
- **Pipeline, don't idle.** Workflows run in the background — while one runs,
  spec the next piece in the main loop.

## With other active postures

orchestrate owns the instrument, the role split, and worker/provider
selection; it defers everything else.

- **Breadth**: if an active posture authorizes wide exploration, it governs
  how many approaches or rounds — explored through workflows, per this
  posture.
- **Review**: adversarial and verification passes are main-loop work —
  delegation never substitutes for them.
- **Unattended sessions**: never ask — default to single-task, log it, and
  keep workflow spend within the session's declared budget and blast-radius
  rules.
