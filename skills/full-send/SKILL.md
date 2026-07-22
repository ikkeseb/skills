---
name: full-send
description: Posture for when resources are authorized — explore independent approaches in parallel and converge on the best result, not the first acceptable one. Single-task or sustained for the session.
---

# full-send

Posture for when the user has opened the taps — tokens, time, subagents, and agent teams are authorized. The job is the **best** result on this problem, not the first acceptable one.

So don't settle for a single pass: spend the resources to explore alternatives — competing ideas, rival approaches, parallel pieces of one implementation — then converge to one coherent result. That's a synthesized answer or merged working code depending on the task; for code, "best" includes that it runs.

Breadth isn't correctness. Resolve conflicts and integrate yourself — never relay raw agent dumps or rubber-stamp a confident subagent. Verify when it sharpens the result (for code: tests, build, repro).

## Modes

- `/full-send <task>` — single-task, one wide round.
- `/full-send sustained` — session posture. Only an explicit user signal drops it (`full-send off`, `stop full-send`, or any unambiguous stop signal in any language); mid-sustained questions or redirects don't. New session starts fresh.

Open the first response with the marker `[full-send]` / `[full-send sustained]`, batch any genuine ambiguity about *what* is asked once — no "should I go wide?" padding — then go.

## Judgment, not phases

No fixed procedure — use judgment on how wide to go and how to slice the work. Defaults:

- **Every agent earns its spend.** Name its distinct contribution — a different file, angle, approach, or risk surface — or don't spawn it. When you can't name the next one, the fan-out is done.
- **Open-ended work goes in rounds.** Fan out, converge, then spawn another round only if the last earned it.
- **Brief every subagent.** They start empty — pass the skills, project context, and prior decisions they need, or they drift onto a neighboring question.
- **Workflows stay opt-in.** Agents and teams are the default instrument; reach for the `Workflow` tool only when the user names it (e.g. `/full-send workflows`).

**Skip the fan-out when it can't change the outcome:** deterministic single step (lint, rename), atomic lookup (one fact), or strictly sequential subproblems (B needs A's output first). Say so once instead of spawning agents that produce nothing.

## With other active postures

full-send owns generation — how wide to explore and how to converge. It defers everything else:

- **Teardown**: if an active posture owns adversarial review, generation converges first, then that pass runs on the result — build wide, then tear down, in that order.
- **Instrument**: if an active posture restricts delegation to a specific instrument or role split, fan out through it.
- **Spend**: a budget declared at session handoff is the spend authority — fan out within it, never past it.
