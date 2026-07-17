---
name: max-effort
disable-model-invocation: true
description: Posture skill activated by `/max-effort` (single-task) or `/max-effort sustained` (session). Adversarial review of the work in front of you — does it answer the real goal, and would it survive someone trying to break it? Sustained mode persists until an explicit off-signal from the user.
---

# max-effort

Posture for high-stakes / irreversible work. The load-bearing move is *adversarial*: with the work in front of you, ask whether it answers the real goal and would survive someone trying to break it — then try to break it before you ship.

Not a "be careful" prompt, and not an engine for producing more work. This skill *tears down* — it assumes the work might be wrong and tries to prove it.

## Modes

- `/max-effort <task>` — single-task, one review round.
- `/max-effort sustained` — session posture. Only an explicit user signal drops it (`max-effort off`, `stop max-effort`, or any unambiguous stop signal in any language); mid-sustained questions or redirects don't. New session starts fresh.

Open the first response with the marker `[max-effort]` / `[max-effort sustained]`, batch any genuine ambiguity about *what* is asked once — no "should I be thorough?" padding — then go.

## The pass

Always run, in this turn, against the work however it was produced:

- **Goal-match.** Does it answer the question asked, or a neighbor it drifted into?
- **Break it.** Red-team what's irreversible or externally-visible — spawn skeptics to tear down when the stakes warrant it. Confidence isn't evidence, yours or a subagent's.
- **Check load-bearing claims against source-of-truth.** Read the cited file, open the URL, run the tests/build/repro, look at the browser — task-specific, the CLAUDE.md verification bar not relaxed.
- **Resolve conflicts.** Don't paper over disagreement with "both have a point" — navigate it.
- **Calibrate.** Surface a gap rather than claim coverage you didn't deliver. If you haven't checked one source-of-truth artifact this turn, the pass didn't happen. No persistent log — cross-session "thorough on X" state breeds false certainty.

Trivial task with nothing load-bearing to check: say so once up front, ask whether to proceed.

## With other active postures

max-effort owns the adversarial pass on finished work; it defers generation entirely.

- **Generation**: if an active posture owns producing the work, let it converge first — tear down the converged result, not the drafts.
- **Unattended sessions**: never ask — default to single-task, log it, and run the pass unchanged within the session's blast-radius rules.
