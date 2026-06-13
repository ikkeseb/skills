---
name: max-effort
description: Posture skill activated by `/max-effort` (single-task) or `/max-effort sustained` (session). Runs a load-bearing verification pass — match the work against the real goal, check every load-bearing claim against source-of-truth, red-team what's irreversible — instead of rubber-stamping it. Invoke ONLY when the user types the literal `/max-effort` command — a described need for thoroughness is not a trigger; only the command is. Sustained mode drops when the user says so in any phrasing — "stop max-effort", "max-effort off", "back", "stopp".
---

# max-effort

Posture for high-stakes / irreversible work. The load-bearing move is verification: with the work product in front of you, check it against source-of-truth rather than trusting it.

Not a "be careful" prompt, and not an engine for producing more work. This skill *tears down*: it assumes the work might be wrong and tries to prove it before you ship.

## Modes

- `/max-effort <task>` — single-task, one verification round.
- `/max-effort sustained` — session posture, persists until explicit off-signal.

## Off-signal (sustained)

Only explicit user signal drops the posture: `back`, `stopp`, `max-effort off`, `stop max-effort`, `drop max-effort`, or any unambiguous equivalent in any language. Mid-sustained questions or redirects do not drop it. New session starts fresh.

## Preamble — first response after `/max-effort`

Open with the activation marker so it's visible: `[max-effort]` (single) or `[max-effort sustained]`. Then surface task ambiguity in one batch only if genuinely unclear *what* is being asked. No "should I be thorough?" padding. Then wait.

## The verification pass

**Always run.** With the work product in front of you, however it was produced, in this turn:

1. **Match against the actual goal.** Does the work answer the question the user asked, or a neighboring one it drifted into?
2. **Verify load-bearing claims against source-of-truth.** Task-specific: read the file cited, open the URL, check the browser, check internal consistency. Confidence is not evidence — yours or a subagent's.
3. **Resolve conflicts explicitly.** Don't paper over disagreements with "both have a point" — use the context to navigate.
4. **Adversarial sub-dispatch — as a tool, not a phase.** Spawn auditors to red-team when the work warrants it (security-sensitive, irreversible, externally-visible). Skeptics tearing down, not fanning out to produce. Otherwise skip.
5. **Run task-specific verification.** Code: tests, build, repro. Research: open the cited sources. Frontend: open the browser and look. Concept work: check internal consistency and constraint-fit. The CLAUDE.md verification rule, generalized — not relaxed.
6. **Be explicit about checked vs unchecked.** Calibration over confidence. Surface a gap rather than claim coverage you didn't deliver.

## Final summary

Inline only — no persistent log file. Persistent "thorough on X" markers create a false-certainty cascade across sessions; verification lives in the active turn, not state.

This lands *after* Claude Code's normal output, which already shows the work — so the summary is **not** a recap. It is two things and nothing else: the marker, and what's still open. No tally counts, no `🔍 verified` re-narration of checks already visible above, no "why I solo'd" justification.

- **Marker.** Lead with `[max-effort]` / `[max-effort sustained]`. In sustained mode it's load-bearing — it's how the posture survives context compression — so it appears on every turn that emits a summary.
- **Open items only.** One `🚩` line per unresolved conflict, unverified claim, assumption leaned on, or decision waiting on the user — what's left *for them*, not what you did.

> **[max-effort sustained]**
>
> - 🚩 prod confirmation pending the 04:30 run (last tar is pre-deploy)
> - 🚩 stale 208 MB `gravity.db.bak` dominates offsite — delete / exclude?
> - 🚩 backlog: miniflux restore-drill, NAS log-rotation — what to land first?

**One invariant:** open/flagged is always represented — at least one `🚩` line, or an explicit `✅ nothing open, all load-bearing claims checked` when there genuinely is nothing. It's the anti-cascade anchor; everything else is cut, this stays.

## Failure modes worth naming

- **Verification pass collapsing to "looks right, done".** The cascade. If you're writing the summary without having read at least one source-of-truth artifact in this turn, the pass did not happen — go back and do it.
- **Rubber-stamping a subagent because it sounded confident.** Subagents hallucinate; their confidence is not evidence. Check the claim, not the tone.
- **Trivial task invoked under max-effort.** Deterministic work where there's nothing load-bearing to verify. Say so once in the preamble and ask whether to proceed.
- **Sustained mode quietly persisting after the high-stakes work is done.** If the user moves to small unrelated tasks, surface once: "still in sustained — drop?"
