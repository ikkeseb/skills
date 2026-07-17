---
name: afk
disable-model-invocation: true
description: Posture skill for unattended autonomous work. Invoke ONLY when the user types the literal `/afk` command — a described intention to leave is not a trigger; only the command is. Sets a session posture (no clarifying questions, low-blast-radius default, audit-trail logging) that persists until an explicit return signal from the user.
---

# afk

Posture for sessions where the user has handed work off and won't be available to course-correct in real time. Mutates session behavior until explicitly dropped. Common uses: overnight runs, discovery/optimization sweeps, audits, spec-driven implementation on low-risk repos, greenfield work.

AFK is **not** "move fast". AFK is "work autonomously and leave a clean audit trail."

## Off-signal

Only an explicit user signal drops AFK: `back`, `afk off`, or any unambiguous return/stop signal in any language. Mid-AFK interactive input (questions, redirects, corrections) does NOT drop the posture — the user may be poking in from mobile. Answer briefly, stay in AFK. A new session starts fresh; nothing persists.

## Preamble — first response after `/afk`

Open with `[afk mode engaged]` so activation is visible, then two steps, then wait. Goal: front-load every clarification so the user can leave without coming back to answer follow-ups.

**Step 1 — Subagent / token budget (one question, three options).** Ask the user to pick one:
- *Single-agent* — Claude alone. Simpler, context compounds. Most token-conservative.
- *Subagent-driven, moderate spend* — Claude orchestrates, prefer fewer larger subagents. Reduces context bloat without multiplying tokens hard.
- *Subagent-driven, unconstrained* — parallelize aggressively, big jobs in own contexts.

Bake token concern into this question — don't ask separately.

**Step 2 — Task-specific clarifications.** Surface any genuine ambiguity about the requested work. Front-load all of it in one batch.

Then wait for the user's reply before starting work.

## Posture rules

### Never ask clarifying questions

Decisions are made and logged, not deferred. Calibrate by blast radius:

- **Trivial** (naming, equivalent options): take it, log briefly.
- **Mid-stakes** (architecture choice, refactor scope): pick the least-committing option, log the trade-off.
- **High-blast + genuinely uncertain**: STOP. Log `[AFK BLOCKED] <what> — needs the user on <X>`. Move to the next independent task if one exists; otherwise wait.

### Blast radius — principle, not exhaustive list

- **Forbidden** (stop + log, don't proceed): destructive, irreversible, or externally-visible operations. E.g. force-push to main, prod deploys, external messages (Slack/email/PR comments), dropping data, overwriting uncommitted work Claude didn't author.
- **Pre-authorized** (proceed): local and reversible work. E.g. edits, tests/build/lint, local commits, scratch files.
- **Gray area** (proceed with thorough logging): everything between — feature-branch pushes, draft PRs, dependency installs, multi-file refactors.

### Proactive scope expansion within blast rules

Low-hanging fruit can be implemented during AFK when blast-radius rules hold and the log names the concrete signal that made it clearly desired (`"duplicate logic in 3 places, extracted helper"` beats `"looked cleaner"`). If a fix drags into unknown terrain (unfamiliar imports, feature flags, unclear side effects), back out and log it as a suggestion instead. Separate core-task work from extras in the log — the user should be able to scan "did the core job get done" before reviewing the rest.

### Bias toward uncertainty framing in the log

Without live feedback, sycophancy creeps in. Counter-pressure: write `"uncertain about X because Y, proceeded because Z"` rather than `"this is correct"`. Calibration over confidence.

## Logging

Updates flow naturally in the conversation — what was done, what's running, what surfaced. No fixed format, no per-decision template; pick a sensible cadence (major checkpoints, completed task, surprising finding) and write a normal line.

One exception: when stopped because of blast-radius rules + genuine uncertainty, use the structured marker `[AFK BLOCKED] <what> — needs the user on <X>` so it's scannable if the user pokes in from mobile.

The conversation IS the audit trail. No separate log file written.

## Return summary

When AFK is explicitly dropped, lead the reply with one tally line + bulleted index:

> **3 done · 1 deferred · 1 blocked**
>
> - ✅ implemented X — commit `abc123`
> - ✅ tests pass — 47/47
> - ⏸ dependency bump deferred — minor vs major is your call
> - 🛑 blocked: prod deploy — needs your AWS creds

Status keys: ✅ done · ⏸ deferred · 🛑 blocked. One bullet per item, plain prose, no nested paragraphs — this is the index, not the recap; the inline updates carry the detail.

## Composition with other skills and modes

- **Other posture skills**: stack. AFK owns the interaction model and the spend authority — another posture's preamble does not run (asking is forbidden); it defaults to single-task, logged as `[AFK] <posture> default → single-task`. Its substantive pass runs unchanged within AFK's blast-radius rules, and the budget picked in the AFK preamble caps any fan-out — within it, never past it.
- **Plan mode / `EnterPlanMode`**: NEVER under AFK — requires user approval to exit, would deadlock. Write the plan inline in the log and proceed (if low-blast).
- **Long blocking brainstorming**: NEVER under AFK. Answer the questions brainstorming would have asked in the log, proceed with best judgment.
- **Verification before "done"**: not relaxed by AFK. Before logging anything as "done", "fixed", "passing", or equivalent, run the verification command (test/build/typecheck/repro) and include its output in the log. No bare claims. This stands regardless of whether the user has a separate verification skill installed.

## Stop hooks firing mid-AFK

Acknowledge briefly, continue the task. Don't pivot to address what the hook flagged unless it actively blocks the work. If the hook requests follow-up work (journal, log entry, audit), defer: note it briefly and continue. The hook's content is recoverable later; the AFK task isn't.

## Failure modes worth naming

- **Test failures mid-AFK**: one retry on an obvious fix (typo, import). If still failing, stop and log. Don't guess deeper — that's where unsupervised AFK runs go off the rails.

