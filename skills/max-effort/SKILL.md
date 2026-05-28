---
name: max-effort
description: Posture skill activated by `/max-effort` (single-task) or `/max-effort sustained` (session). Dispatches subagents widely, then runs an orchestrator-pass that's the load-bearing verification step. Invoke ONLY when the user explicitly types the command — do NOT auto-invoke from context cues like "this is important", "high-stakes", "be careful", "irreversible", or "do this thoroughly". Sustained mode drops only on explicit user off-signal.
---

# max-effort

Posture for high-stakes / irreversible work. Dispatches subagents widely, then runs an orchestrator-pass to catch what subagents missed.

Not a "be careful" prompt. The load-bearing moves are (1) dispatching widely for independent signal, and (2) the orchestrator verifying the result rather than rubber-stamping it.

## Modes

- `/max-effort <task>` — single-task, one expensive round.
- `/max-effort sustained` — session posture, persists until explicit off-signal.

## Off-signal (sustained)

Only explicit user signal drops the posture: `back`, `stopp`, `max-effort off`, `drop max-effort`, or unambiguous equivalent. Mid-sustained questions or redirects do not drop it. New session starts fresh.

## Preamble — first response after `/max-effort`

1. **Mode** — single or sustained, if not already in the invocation.
2. **Task ambiguity** — surface in one batch only if genuinely unclear *what* is being asked. No "should I be thorough?" padding.

Then wait.

## Phase 1 — Broad dispatch

**Default.** Dispatch. Bar is low: if you can name distinct work per agent — different files, perspectives, risk surfaces — dispatch them. "Distinct contribution" is the test, not "maximum independence". Token and time cost are not constraints; the user invoked this posture because they want resources spent.

**Skip dispatch only when:**

- Deterministic single-step task (lint, rename, mechanical refactor) — no judgment to parallelize.
- Single-file lookup where solo is strictly faster.
- Fully sequential subproblems — B literally cannot start without A's output.

**Brief-content rule.** Subagents start with empty context — pass relevant skills, project context, prior decisions. Common failures: not telling the subagent to load a skill you loaded; duplicate agents on one question; adversarial reviewers when not warranted.

## Phase 2 — Orchestrator pass

**Always run.** With subagent artifacts in front of you, in this turn:

1. **Match against the actual goal.** Did subagents answer the question the user asked, or a neighboring one their brief drifted into?
2. **Verify load-bearing claims against source-of-truth.** Task-specific: read the file cited, open the URL, check the browser, check internal consistency. Subagents hallucinate; their confidence is not evidence.
3. **Resolve conflicts explicitly.** Don't paper over disagreements with "both have a point" — use the context they lacked to navigate.
4. **Adversarial sub-dispatch — as a tool, not a phase.** Spawn auditors when the artifact warrants red-team (security-sensitive, irreversible, externally-visible). Otherwise skip.
5. **Run task-specific verification.** Code: tests, build, repro. Research: open the cited sources. Frontend: open the browser and look. Concept work: check internal consistency and constraint-fit. The CLAUDE.md / `superpowers:verification-before-completion` rule, generalized — not relaxed.
6. **Be explicit about checked vs unchecked.** Calibration over confidence. Surface a gap rather than claim coverage you didn't deliver.

## Final summary

Inline only — no persistent log file. Persistent "thorough on X" markers create a false-certainty cascade across sessions; verification lives in the active turn, not state. For cross-session capture, use `/handoff`.

This lands *after* Claude Code's normal output — so it's a scannable index on top, not a recap. Don't re-narrate the work above; keep every line to one line. Same shape as afk's return summary: a tally line, then status bullets.

> **[max-effort sustained] · 3 done · 2 open · 4 checks**
>
> - ✅ what was produced — `commit` / file when relevant
> - 🚩 open: unresolved conflict, unverified claim, or assumption leaned on
> - 🔍 verified: read X, confirmed Y exports Z

Status keys: ✅ done · 🚩 open/flagged · 🔍 verified (an action — "confirmed Y", not a verdict like "code is correct"). In sustained mode, fold `[max-effort sustained]` into the tally line so the posture survives context compression.

**One invariant:** open/flagged is always represented — at least one 🚩 bullet, or an explicit `✅ nothing open, all load-bearing claims checked`. It's the anti-cascade anchor; everything else flexes to the work, this doesn't.

When >1 subagent, add a one-line `Subagents: A (did x), B (did y)` so the user knows what to second-guess.

In sustained mode, prefix the summary with `[max-effort sustained]` so the posture is recoverable after context compression.

## Composition with other skills and modes

- **`afk`.** Stacks but stays distinct: afk owns the interaction model, max-effort owns dispatch + the orchestrator pass. Under afk, Phase 1/2 run unchanged but the preamble is suppressed (asking is forbidden). afk's "Composition with other skills and modes" section is the source of truth for the exact contract — no questions, single-task default, log format — so it isn't restated here.
- **`superpowers:subagent-driven-development`** (if installed). The how-to for Phase 1 dispatch — load when available for brief-writing and parallel patterns.
- **Plan mode.** Compatible. Plan first if the work is plan-shaped; max-effort dispatches against approved steps. If dispatch surfaces something that invalidates the plan, exit plan mode and re-plan.

## Failure modes worth naming

- **Trivial task invoked under max-effort.** Deterministic work where no dispatch can change the outcome. Say so once in the preamble and ask whether to proceed. Don't silently spawn agents that will produce nothing.
- **Solo'd a multi-angle task.** Orchestrator-pass against your own work is just verification-before-completion, not max-effort. If you couldn't name a skip-dispatch reason, you should have dispatched.
- **Orchestrator pass collapsing to "subagents agreed, done".** This is the cascade. If you're writing the summary without having read at least one source-of-truth artifact in this turn, the orchestrator pass did not happen — go back and do it.
- **Sustained mode quietly persisting after the high-stakes work is done.** If the user moves to small unrelated tasks, surface once: "still in sustained — drop?" Don't dispatch on micro-tasks just because the mode is on.
