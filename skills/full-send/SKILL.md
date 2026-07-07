---
name: full-send
description: Posture skill activated by `/full-send` (single-task) or `/full-send sustained` (session). Resources are authorized — tokens, time, subagents, agent teams. Go for the best result, not the first acceptable one — fan out across independent work, then converge to one. Sustained mode persists until an explicit off-signal from the user.
---

# full-send

Posture for when the user has opened the taps — tokens, time, subagents, and agent teams are authorized. The job is the **best** result on this problem, not the first acceptable one.

So don't settle for a single pass: spend the resources to explore alternatives — competing ideas, rival approaches, parallel pieces of one implementation — then converge to one coherent result. That's a synthesized answer or merged working code depending on the task; for code, "best" includes that it runs.

Breadth isn't correctness. Resolve conflicts and integrate yourself — never relay raw agent dumps or rubber-stamp a confident subagent. Verify when it sharpens the result (for code: tests, build, repro).

## Modes

- `/full-send <task>` — single-task, one wide round.
- `/full-send sustained` — session posture, persists until explicit off-signal.

## Off-signal (sustained)

Only an explicit user signal drops it: `full-send off`, `stop full-send`, or any unambiguous stop/return signal in any language. Mid-sustained questions or redirects don't drop it. New session starts fresh.

## Preamble — first response after `/full-send`

Open with the marker: `[full-send]` (single) or `[full-send sustained]`. Surface task ambiguity in one batch only if it's genuinely unclear *what* is asked — no "should I go wide?" padding. Then go.

## Judgment, not phases

No fixed procedure — use judgment on how wide to go and how to slice the work. Defaults:

- **Every agent earns its spend.** Name its distinct contribution — a different file, angle, approach, or risk surface — or don't spawn it. When you can't name the next one, the fan-out is done.
- **Open-ended work goes in rounds.** Fan out, converge, then spawn another round only if the last earned it.
- **Brief every subagent.** They start empty — pass the skills, project context, and prior decisions they need, or they drift onto a neighboring question.
- **Workflows stay opt-in.** Agents and teams are the default instrument; reach for the `Workflow` tool only when the user names it (e.g. `/full-send workflows`).

**Skip the fan-out when it can't change the outcome:** deterministic single step (lint, rename), atomic lookup (one fact), or strictly sequential subproblems (B needs A's output first). Say so once instead of spawning agents that produce nothing.

## Stacking

- **`max-effort`**: full-send owns generation (fan out, converge); max-effort owns the adversarial pass on the converged result. Build wide, then tear down — in that order.
- **`afk`**: the subagent budget picked in the AFK preamble is the spend authority — fan out within it, never past it.

## Final summary

Inline, marker-led: `[full-send]` / `[full-send sustained]`. In sustained mode the marker is load-bearing — it's how the posture survives context compression, so it appears on every turn that emits a summary. After it, **open items only**: one `🚩` line per angle left unexplored, agent that came back empty, or decision waiting on you. If nothing's open: `✅ nothing open`.
