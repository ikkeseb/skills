---
name: max-effort
description: Posture skill activated by `/max-effort` (single-task) or `/max-effort sustained` (session). Adversarial review of the work in front of you — does it answer the real goal, and would it survive someone trying to break it? Match against the goal, red-team what's irreversible, check load-bearing claims against source-of-truth instead of rubber-stamping. Sustained mode drops when the user says so in any phrasing — "stop max-effort", "max-effort off", "back", "stop".
---

# max-effort

Posture for high-stakes / irreversible work. The load-bearing move is *adversarial*: with the work in front of you, ask whether it answers the real goal and would survive someone trying to break it — then try to break it before you ship.

Not a "be careful" prompt, and not an engine for producing more work. This skill *tears down* — it assumes the work might be wrong and tries to prove it.

## Modes

- `/max-effort <task>` — single-task, one review round.
- `/max-effort sustained` — session posture, persists until explicit off-signal.

## Off-signal (sustained)

Only explicit user signal drops it: `back`, `stop`, `max-effort off`, `stop max-effort`, `drop max-effort`, or any unambiguous equivalent. Mid-sustained questions or redirects don't drop it. New session starts fresh.

## Preamble — first response after `/max-effort`

Open with the marker: `[max-effort]` (single) or `[max-effort sustained]`. Surface task ambiguity in one batch only if it's genuinely unclear *what* is asked — no "should I be thorough?" padding. Then go.

## The pass

Always run, in this turn, against the work however it was produced:

- **Goal-match.** Does it answer the question asked, or a neighbor it drifted into?
- **Break it.** Red-team what's irreversible or externally-visible — spawn skeptics to tear down when the stakes warrant it. Confidence isn't evidence, yours or a subagent's.
- **Check load-bearing claims against source-of-truth.** Read the cited file, open the URL, run the tests/build/repro, look at the browser — task-specific, the CLAUDE.md verification bar not relaxed.
- **Resolve conflicts.** Don't paper over disagreement with "both have a point" — navigate it.
- **Calibrate.** Surface a gap rather than claim coverage you didn't deliver. If you haven't checked one source-of-truth artifact this turn, the pass didn't happen.

Trivial task with nothing load-bearing to check: say so once in the preamble, ask whether to proceed.

## Final summary

Inline, marker-led — no persistent log (cross-session "thorough on X" state breeds false certainty). Not a recap of the work above: just the marker and what's still open.

In sustained mode the marker is load-bearing — it's how the posture survives context compression, so it appears on every turn that emits a summary. After it, **open items only**: one `🚩` line per unresolved conflict, unverified claim, assumption leaned on, or decision waiting on you. Always at least one `🚩`, or `✅ nothing open` when there genuinely is nothing — the anti-cascade anchor.
