---
name: suggest-loop
description: Propose ready-to-paste `/loop` prompts for a target repo. Reads the repo's documented verification gate and emits 2–3 inline `/loop` suggestions with stop conditions baked in, each marking which half stays a human taste-gate. Use when the user asks "what could I loop here", wants an autonomous fix/babysit loop but can't author the prompt themselves, or asks how `/loop` applies to this repo. Do NOT use to actually run a loop — that's the `/loop` command itself; this only writes the prompt text. Refuse (and say why) when the repo has no documented machine gate, or when the work is taste/ear-gated.
---

# suggest-loop

Generation exercise, not template fill. The job: turn a repo's verification
signal into `/loop` prompts a "vibe coder" can paste as-is — someone who can't
author a precise loop prompt, so the repo proposes it for them and they just
approve or tweak. The failure mode is a confident-sounding loop with no
measurable "done", or one proposed for work that can only be judged by ear.

## Read this first — the load-bearing constraint

**Do not reason about `/loop` from memory.** `/loop`, the Monitor tool, and
`/goal` all post-date the model's training cutoff; a session reconstructing them
from memory gets them wrong (that's why this skill exists). Read
[`references/loop-mechanics.md`](references/loop-mechanics.md) before emitting
any suggestion — it carries the datestamped, verified mechanics and a
re-verify-against-docs pointer. Every claim you make about *how* `/loop` behaves
comes from there, not from priors.

## Recipe

1. **Find the hard gate.** Read the target repo's `CLAUDE.md`, `package.json`
   scripts, CI config, test setup — whatever documents how work is checked.
   You're looking for a *machine* signal: an exit code, a measured assertion, an
   emptying queue. If the repo documents **no** verification signal, stop and say
   so — suggest the repo document one first; **do not fabricate a gate**. A
   suggestion is only as good as the documented oracle.
2. **Match the gate to real work.** A failing suite, a backlog item, a scoped
   feature, a refactor that must stay green. The loop has to be *about*
   something in this repo, not a generic shape.
3. **Emit an inline `/loop` with the stop condition baked in.** "…stop when the
   suite is green twice in a row", "…stop when the work-list is empty". Inline is
   primary. Reach for `.claude/loop.md` only for a loop run *often*; reach for
   `/goal` only when "done" is judgment-heavy (see the mechanics file). Default
   to a plain inline `/loop`.
4. **Mark the human/taste-gate explicitly.** Name the seam: what the loop proves
   by machine, and what stays the user's call ("the by-ear check stays yours").
   Most repos are a split — scope the loop to the machine-measurable half and
   hand the taste half back. This line is the point, not a footnote.

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

Per loop, a short block: the **paste-ready `/loop` line**, the **hard signal**
it terminates on, and the **taste-gate line**. Keep it scannable — the user is
approving prompts, not reading an essay.

> **Loop 1 — keep the suite green (the clean first loop)**
> ```
> /loop run `pnpm test`, fix the single top failure, re-run; commit each green
> step; stop when `pnpm test` exits 0 twice in a row
> ```
> - **Hard signal:** exit code of `pnpm test`.
> - **Stays yours:** whether the result *feels* right — animation smoothness,
>   copy tone, visual polish — the loop never touches those.

A repo's `CLAUDE.md` usually documents both halves: a **machine gate** (an exit
code, an emptying queue) that's loopable, and a **taste/ear gate** (does it
*sound* / *feel* / *read* right) that stays the human's. Surface both — scope the
loop to the machine half and hand the taste half back. A second loop on the same
repo might backfill a deterministic regression-test suite (queue-empties), and a
*refused* suggestion ("make the animation feel smooth" — eye-gated) is itself a
valid, useful output: it tells the user exactly what *can't* be automated here.

**A queue-loop must carry its own queue.** Derive the work-list *inside the loop
line* from source files ("build the list of X from `a.ts`, then drain it"), not
from a `STATUS`/backlog doc that may be stale or a list the user never gave. If
the queue can't self-derive, the loop isn't paste-ready — mark the gap or send it
to the refusals.

## Scope

This skill writes prompt text; it does not run anything. Suggesting 2–3 good
loops and naming what *can't* be looped is the whole job — resist proposing a
loop for every corner of the repo. If nothing in the repo is cleanly loopable,
the honest output is "no good loop here yet, and here's why."
