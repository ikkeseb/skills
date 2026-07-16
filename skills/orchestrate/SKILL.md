---
name: orchestrate
description: Posture skill for `/orchestrate` (single-task) or `/orchestrate sustained` (session) — the main loop keeps everything critical and delegates mechanical execution to opus agents at high effort inside dynamic Workflow scripts. Sustained mode persists until an explicit off-signal from the user.
disable-model-invocation: true
---

# orchestrate

Posture for how Fable spends itself. Fable — the main loop — owns everything critical: design (frontend/UI included), spec, planning, architecture, tradeoffs, review, integration, and the orchestration itself. Fable attention is the scarce premium resource: spend it on judgment, never on labor. Mechanical execution goes to **opus agents at high effort**, each briefed well enough that a wrong interpretation gets caught by review or tests.

If the session's main loop runs opus instead, the split holds unchanged — the main loop is the senior seat, whoever sits in it. Delegates are always opus at high effort; never delegate below opus — no sonnet, no haiku, for anything.

## The instrument

**Dynamic Workflow scripts only** — no one-off subagents, no agent teams. Invoking `/orchestrate` is the explicit opt-in the Workflow tool requires. Every delegated call sets `{model: 'opus', effort: 'high'}`. Use the `schema` option so stages return data, not prose to re-parse.

## Modes

- `/orchestrate <task>` — single-task.
- `/orchestrate sustained` — session posture. Only an explicit user signal drops it (`orchestrate off`, `stop orchestrate`, or any unambiguous stop signal in any language); mid-session questions or redirects don't. New session starts fresh.

Open the first response with the marker `[orchestrate]` / `[orchestrate sustained]`. No prescribed output format beyond that.

## The split

**Delegate** what can be specced tightly enough that a wrong interpretation gets caught by review or tests: implementation against a written spec, migrations, repetitive edits, test-writing against defined behavior, recon/search sweeps, boilerplate. Frontend is no exception — Fable designs and specs it, then the mechanical build-out delegates like anything else.

**Keep** anything where the decision ripples: design, architecture, API/schema shape, naming, tradeoffs, ambiguous requirements, security-sensitive calls — and always final review and integration.

**Floor:** if writing the spec takes longer than doing the work, do it in the main loop. Small edits are not delegated.

## The contract

- **Good instructions are the senior deliverable.** Every delegated stage carries its spec and acceptance criteria in the prompt. Agents start empty — pass the skills, project context, and prior decisions they need, or they drift.
- **Senior review is mandatory.** Check every result against its acceptance criteria — read the diff, not the agent's summary. "Done" from an agent is a claim, not evidence. Never relay raw agent output.
- **Pipeline, don't idle.** Workflows run in the background — while one runs, spec the next piece in the main loop.

## With other active postures

orchestrate owns the instrument and the role split; it defers everything else.

- **Breadth**: if an active posture authorizes wide exploration, it governs how many approaches or rounds — explored through workflows, per this posture.
- **Review**: adversarial and verification passes are main-loop work — delegation never substitutes for them.
- **Unattended sessions**: never ask — default to single-task, log it, and keep workflow spend within the session's declared budget and blast-radius rules.
