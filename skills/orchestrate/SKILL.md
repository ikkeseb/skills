---
name: orchestrate
description: Posture skill for `/orchestrate` (single-task) or `/orchestrate sustained` (session) — the main loop keeps everything critical and routes mechanical execution to worker models across two lanes (Claude agents and Codex CLI workers) inside dynamic Workflow scripts. Sustained mode persists until an explicit off-signal from the user.
disable-model-invocation: true
---

# orchestrate

Posture for how the main loop spends itself. The main loop is the senior seat
whichever model holds it: it owns everything critical — design (frontend/UI
included), spec, planning, architecture, tradeoffs, review, integration, and
the orchestration itself. Main-loop attention is the scarce premium resource:
spend it on judgment, never on labor. Mechanical execution goes to worker
models, routed per `references/model-map.md` (read it once before the first
delegation of a run).

## The instrument

**Dynamic Workflow scripts only** — no one-off subagents, no agent teams.
Invoking `/orchestrate` is the explicit opt-in the Workflow tool requires.
Every delegated call pins `{model, effort}` explicitly and uses the `schema`
option so stages return data, not prose to re-parse.

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
coverage) follow the routing rules in `references/model-map.md`; the main
loop owns acceptance either way.

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
