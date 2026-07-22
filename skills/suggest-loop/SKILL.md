---
name: suggest-loop
description: Draft 2–3 paste-ready `/loop` prompts from a repo's documented verification gate, stop conditions baked in — or explain why the work isn't safely loopable. Writes the prompt text only; running loops is `/loop` itself.
---

# suggest-loop

Generation exercise, not template fill. Turn a repo's verification signal into
`/loop` prompts a "vibe coder" can paste as-is — someone who can't author a
precise loop prompt, so the repo proposes it and they just approve or tweak. The
failure mode: a confident-sounding loop with no measurable "done".

## Read this first — the load-bearing constraint

**Do not reason about `/loop` from memory.** `/loop`, the Monitor tool, and
`/goal` post-date the model's training cutoff; a session reconstructing them from
memory gets them wrong (that's why this skill exists). Read
[`references/loop-mechanics.md`](references/loop-mechanics.md) before emitting any
suggestion — every claim about *how* `/loop` behaves comes from there, not priors.

## Recipe

1. **Find the hard gate.** Read the target repo's `CLAUDE.md`, `package.json`
   scripts, CI config, test setup — whatever documents how work is checked.
   You're looking for a *machine* signal: an exit code, a measured assertion, an
   emptying queue. No documented signal → refuse (see Anti-patterns); **do not
   fabricate a gate**.
2. **Match the gate to real work.** A failing suite, a backlog item, a scoped
   feature, a refactor that must stay green. The loop has to be *about*
   something in this repo, not a generic shape.
3. **Emit an inline `/loop` with the stop condition baked in.** "…stop when the
   suite is green twice in a row", "…stop when the work-list is empty". Inline is
   primary. Reach for `.claude/loop.md` only for a loop run *often*; reach for
   `/goal` only when "done" is judgment-heavy (see the mechanics file). Default
   to a plain inline `/loop`.
4. **Mark the human/taste-gate explicitly.** Autonomy follows the oracle: where
   correctness is a fact about the world (an exit code, a hash, a measured peak)
   the loop checks itself; where "correct" lives in the user's taste (does it
   *sound* good, does the UI *feel* right) a human gates every step. Most repos
   are a split — scope the loop to the machine-measurable half and hand the taste
   half back ("the by-ear check stays yours"). Naming that seam is the point, not
   a footnote.

## Anti-patterns — refuse these, don't dress them up

- **Vague termination** ("fix until no more bugs", "keep improving it") — no
  measurable done, the loop never knows it's finished. Rewrite to a hard signal
  or decline.
- **Taste/ear-gated work** (does it *sound* right, does the UI *feel* right) —
  not loopable autonomously; the oracle is a human sense. Say so and leave it
  human-gated.
- **No documented signal** — a suggestion would be guessed. Recommend
  documenting the gate instead of inventing one.

When you refuse, that *is* the deliverable — a clear "this isn't loopable, and
here's the one thing that would make it loopable" beats a plausible-looking loop
that runs to nowhere.

## Output shape

Per loop, a short scannable block: the **paste-ready `/loop` line**, the **hard
signal** it terminates on, and the **taste-gate line**.

> **Loop 1 — keep the suite green (the clean first loop)**
> ```
> /loop run `pnpm test`, fix the single top failure, re-run; commit each green
> step; stop when `pnpm test` exits 0 twice in a row
> ```
> - **Hard signal:** exit code of `pnpm test`.
> - **Stays yours:** whether the result *feels* right — animation smoothness,
>   copy tone, visual polish — the loop never touches those.

**A queue-loop must carry its own queue.** Derive the work-list *inside the loop
line* from source files ("build the list of X from `a.ts`, then drain it"), not
from a `STATUS`/backlog doc that may be stale or a list the user never gave. If
the queue can't self-derive, the loop isn't paste-ready — mark the gap or send it
to the refusals.

## Scope

This skill writes prompt text; it does not run anything. Suggest 2–3 good loops,
name what *can't* be looped, and stop — don't force a loop for every corner.
