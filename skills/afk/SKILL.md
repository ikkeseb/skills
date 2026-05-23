---
name: afk
description: Posture skill for unattended autonomous work. Invoke ONLY when the user explicitly types `/afk` — do NOT auto-invoke from context cues like "I'm leaving", "going AFK", or "check back later". Sets a session posture (no clarifying questions, low-blast-radius default, audit-trail logging) that persists until the user explicitly drops it with "back", "I'm back", "stopp", "afk off", or "drop AFK".
---

# afk

Posture for sessions where the user has handed work off and won't be available to course-correct in real time. Mutates session behavior until explicitly dropped. Common uses: overnight runs, discovery/optimization sweeps, audits, spec-driven implementation on low-risk repos, greenfield work.

AFK is **not** "move fast". AFK is "work autonomously and leave a clean audit trail."

## Off-signal

Only an explicit user signal drops AFK: `back`, `I'm back`, `stopp`, `afk off`, `drop AFK`, or an unambiguous equivalent. Mid-AFK interactive input (questions, redirects, corrections) does NOT drop the posture — the user may be poking in from mobile. Answer briefly, stay in AFK. A new session starts fresh; nothing persists.

## Preamble — first response after `/afk`

Three steps, then wait. Goal: front-load every clarification so the user can leave without coming back to answer follow-ups.

**Step 0 — Stop-hook scan.** Read each of these if present, list any `hooks.Stop` entries:
- `~/.claude/settings.json`
- `~/.claude/settings.local.json`
- `<cwd>/.claude/settings.json`
- `<cwd>/.claude/settings.local.json`

Flag heuristically disruptive hooks (names/commands suggesting "journal", "log", "trigger", "audit", "review") and recommend the user mute them in `settings.json` before going AFK. Do not modify settings yourself — user decides.

**Step 1 — Subagent / token budget (one question, three options).** Ask the user to pick one:
- *Single-agent* — Claude alone. Simpler, context compounds. Most token-conservative.
- *Subagent-driven, moderate spend* — Claude orchestrates, prefer fewer larger subagents. Reduces context bloat without multiplying tokens hard.
- *Subagent-driven, unconstrained* — parallelize aggressively, big jobs in own contexts.

Bake token concern into this question — don't ask separately. Don't assume Max plan; Pro users will pick moderate or single-agent.

**Step 2 — Task-specific clarifications.** Surface any genuine ambiguity about the requested work. Front-load all of it in one batch.

Then wait for the user's reply before starting work.

## Posture rules

### Never ask clarifying questions

Decisions are made and logged, not deferred. Calibrate by blast radius:

- **Trivial** (naming, equivalent options): take it, log briefly.
- **Mid-stakes** (architecture choice, refactor scope): pick the least-committing option, log the trade-off.
- **High-blast + genuinely uncertain**: STOP. Log `[AFK BLOCKED] <what> — needs Seb on <X>`. Move to the next independent task if one exists; otherwise wait.

### Blast radius — principle, not exhaustive list

- **Forbidden** (stop + log, don't proceed): destructive, irreversible, or externally-visible operations. E.g. force-push to main, prod deploys, external messages (Slack/email/PR comments), dropping data, overwriting uncommitted work Claude didn't author.
- **Pre-authorized** (proceed): local and reversible work. E.g. edits, tests/build/lint, local commits, scratch files.
- **Gray area** (proceed with thorough logging): everything between — feature-branch pushes, draft PRs, dependency installs, multi-file refactors.

### Proactive scope expansion within blast rules

Low-hanging fruit and clearly-desired fixes can be implemented during AFK if:
- (a) blast-radius rules still hold,
- (b) the log articulates *why* it was clearly desired with a concrete signal (`"duplicate logic in 3 places, extracted helper"` beats `"looked cleaner"`),
- (c) if the fix drags into unknown terrain (unfamiliar imports, feature-flag context, unclear side effects), back out and log it as a suggestion instead of implementing.

Separate core-task work from additional fixes in the log — the user should be able to scan "did the core job get done" before reviewing extras.

### Bias toward uncertainty framing in the log

Without live feedback, sycophancy creeps in. Counter-pressure: write `"uncertain about X because Y, proceeded because Z"` rather than `"this is correct"`. Calibration over confidence.

### Re-anchor in status summaries

Long AFK sessions WILL compress context; posture can be lost mid-flight. Re-state AFK status in each `[AFK status]` summary so the posture is recoverable from any recent log entry.

## Logging

### During work — inline

| Format | When |
|---|---|
| `[AFK] <what> — <why>` | Per non-trivial decision. One line, scannable. |
| `[AFK status] …` | Per major step. Short: done / deferred / blocked. Re-anchors posture. |
| `[AFK BLOCKED] <what> — needs Seb on <X>` | When stopped on high-blast + uncertain. |

### At the end — when AFK is explicitly dropped

Write `~/.claude/afk-logs/YYYY-MM-DD-HHmm-<slug>.md` (slug from the initial AFK task description, kebab-case). Structure:

- **Summary** at top — 5–10 lines: what was done, what's pending, any blockers.
- **Detailed log** below — full audit trail.

Create `~/.claude/afk-logs/` if missing. On each AFK run, auto-delete `*.md` older than 30 days in that directory.

## Composition with other skills and modes

- **`max-effort`**: stacks. AFK owns the interaction model; max-effort owns dispatch + orchestrator pass. Under AFK the max-effort preamble does not run — asking is forbidden — so default to single-task and log as `[AFK] max-effort default → single-task`.
- **Plan mode / `EnterPlanMode`**: NEVER under AFK — requires user approval to exit, would deadlock. Write the plan inline in the log and proceed (if low-blast).
- **Long blocking brainstorming**: NEVER under AFK. Answer the questions brainstorming would have asked in the log, proceed with best judgment.
- **Verification before "done"**: not relaxed by AFK. Before logging anything as "done", "fixed", "passing", or equivalent, run the verification command (test/build/typecheck/repro) and include its output in the log. No bare claims. This stands regardless of whether the user has a separate verification skill installed.

## Stop hooks firing mid-AFK

Acknowledge briefly, continue the task. Don't pivot to address what the hook flagged unless it actively blocks the work. If the hook requests follow-up work (journal, log entry, audit), defer: log `hook requested X, pending end of AFK` and continue. The hook's content is recoverable later; the AFK task isn't.

Hard-muting hooks for unattended runs requires editing `settings.json` — that's user-config, outside the skill's scope. Surface the option in Step 0 of the preamble; don't act on it.

## Failure modes worth naming

- **Test failures mid-AFK**: one retry on an obvious fix (typo, import). If still failing, stop and log. Don't guess deeper — that's where unsupervised AFK runs go off the rails.
- **Forgetting AFK is on when the user returns**: low-cost. AFK is conservative by design; the failure mode is "more careful than needed", not destructive.

