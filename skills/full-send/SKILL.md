---
name: full-send
description: Posture skill activated by `/full-send` (single-task) or `/full-send sustained` (session). Grants free rein on subagents and agent teams — dispatch widely, branch, run research/QA/optimization passes; tokens and time are not constraints. The load-bearing move is synthesizing the fan-out, not verifying it. Invoke ONLY when the user types the literal `/full-send` command — a described wish for thoroughness or speed is not a trigger; only the command is. Workflows are opt-in: authorize the Workflow tool only when the user names it (e.g. `/full-send workflows`). Sustained mode drops when the user says so in any phrasing — "stop full-send", "full-send off", "back", "stopp".
---

# full-send

Posture for when the user has opened the taps: resource use is authorized. Default to fanning out — subagents and agent teams — for any substantial work, then synthesize.

Not a "work harder" prompt. The load-bearing move is **breadth then synthesis**: dispatch independent agents/teams to cover more ground, then dedupe, resolve, and assemble. This skill produces breadth; it does not verify — so synthesize the fan-out rather than trusting any single agent.

## Modes

- `/full-send <task>` — single-task, one wide round.
- `/full-send sustained` — session posture, persists until explicit off-signal.

## Off-signal (sustained)

Only explicit user signal drops it: `back`, `stopp`, `full-send off`, `stop full-send`, `drop full-send`, or any unambiguous equivalent in any language. Mid-sustained questions or redirects do not drop it. New session starts fresh.

## Preamble — first response after `/full-send`

Open with the marker: `[full-send]` (single) or `[full-send sustained]`. Surface task ambiguity in one batch only if genuinely unclear *what* is being asked — no "should I go wide?" padding. Then go.

## What this authorizes

- **Subagents and agent teams, freely.** If you can name distinct work per agent — different files, angles, risk surfaces — dispatch it. Token and time cost are not constraints; the user opened the taps.
- **Branch, explore, optimize.** Parallel approaches, research sweeps, QA passes, optimization rounds are all on the table.
- **Workflows are opt-in.** Do NOT reach for the `Workflow` tool by default — agents and teams are the default instrument. Only when the user names it (e.g. `/full-send workflows`) is deterministic orchestration authorized too.

## Judgment, not phases

No fixed procedure. Use judgment on how wide to go and how to slice the work. The one non-negotiable step: with artifacts in front of you, **synthesize** — dedupe, resolve conflicts, assemble into one answer. Never relay raw agent dumps.

**Skip the fan-out when** it can't change the outcome: deterministic single-step task (lint, rename), atomic lookup (one fact), or fully sequential subproblems (B can't start without A's output). Say so once rather than spawning agents that produce nothing.

**Brief-content rule.** Subagents start with empty context — pass relevant skills, project context, prior decisions, or they drift onto a neighboring question.

## Bounding the spend

Open taps, not no brakes — the bound is the task's shape, not a number:

- **Every agent earns its spend.** Name its distinct contribution or don't spawn it; when you can't name the next one, the fan-out is done. Breadth tracks the work, not a quota.
- **Open-ended work goes in rounds.** Fan out, synthesize, then spawn another round only if the last one earned it. Never pre-commit to unbounded or looping dispatch.

## Final summary

Inline, marker-led: `[full-send]` / `[full-send sustained]`. In sustained mode the marker is load-bearing — it's how the posture survives context compression, so it appears on every turn that emits a summary. Then **coverage gaps only**: one `🚩` line per angle left unexplored, agent that came back empty, or decision waiting on the user. If nothing's open, say so: `✅ nothing open`.
