---
name: suggest-loop
description: Draft up to 3 paste-ready `/loop` prompts from a repo's documented verification gate, each with a measurable success stop and a hard turn/time cap — or explain why the work isn't safely loopable. Writes the prompt text only; running loops is `/loop` itself.
---

# suggest-loop

Generation exercise, not template fill. Turn a repo's verification signal into
`/loop` prompts a "vibe coder" can paste as-is — someone who can't author a
precise loop prompt, so the repo proposes it and they just approve or tweak. The
failure mode: a confident-sounding loop with no measurable "done".

## Read this first — the load-bearing constraint

**Do not reason about `/loop` from memory.** The vendored reference is the
authority: harness loop mechanics change faster than any model's priors, and a
session reconstructing them from memory gets them wrong (that's why this skill
exists). Read [`references/loop-mechanics.md`](references/loop-mechanics.md)
before emitting any suggestion — every claim about *how* `/loop` behaves comes
from there, not priors.

## Recipe

1. **Establish the target.** The repo of the current session, plus whatever
   work the user named. Bare invocation with no obvious candidate work → ask
   before generating. Done when you can name the repo and the work a loop would
   be about.
2. **Find the hard gate.** Read the target repo's `CLAUDE.md`, `package.json`
   scripts, CI config, test setup — whatever documents how work is checked.
   You're looking for a *machine* signal: an exit code, a measured assertion, an
   emptying queue — one the receiving session can actually run (no missing
   credentials, network, or exec it won't have). No documented, runnable
   signal → refuse (see Anti-patterns); **do not fabricate a gate**. Done when
   you hold a named command or signal and know roughly what one run of it costs
   (run it if cheap, else read CI timings).
3. **Match the gate to real work.** A failing suite, a backlog item, a scoped
   feature, a refactor that must stay green. Done when the loop is *about*
   something in this repo, not a generic shape.
4. **Bake in the stops.** Every suggestion needs a measurable success stop
   ("the suite exits 0 twice", "the work-list is empty") and an independent hard
   turn or wall-clock cap — sized to the gate: the wall-clock cap must cover at
   least ~3 runs at the gate's observed or documented duration, and if the gate
   is too slow for that, say so rather than suggest a loop that can't finish.
   Where the gate can repeat an identical failure, add a no-progress stop
   ("same failure twice in a row → stop"). Platform expiry is not a substitute
   for the task-level cap. Default to a prompt-only, self-paced inline `/loop`,
   because it can stop itself; a fixed interval cannot enforce the cap
   autonomously — use one only when a human explicitly owns cancellation. Done
   when every block carries its stops with concrete numbers.
5. **Mark the human/taste-gate explicitly.** Autonomy follows the oracle: where
   correctness is a fact about the world (an exit code, a hash, a measured peak)
   the loop checks itself; where "correct" lives in the user's taste (does it
   *sound* good, does the UI *feel* right) a human gates every step. Most repos
   are a split — scope the loop to the machine-measurable half and hand the taste
   half back ("the by-ear check stays yours"). Done when each block's
   "stays yours" line names the taste half, or states there is none.

## Anti-patterns — refuse these, don't dress them up

- **Vague termination** ("fix until no more bugs", "keep improving it") — no
  measurable done, the loop never knows it's finished. Rewrite to a hard signal
  or decline.
- **Taste/ear-gated work** (does it *sound* right, does the UI *feel* right) —
  not loopable autonomously; the oracle is a human sense. Say so and leave it
  human-gated.
- **No documented signal** — a suggestion would be guessed. Recommend
  documenting the gate instead of inventing one.
- **No hard cap** — a success signal can remain red forever. Add a turn/time
  limit or decline.

## No execution authority

`suggest-loop` grants none. Do not add commit, push, pull request,
dependency-install, deploy, or external-message instructions unless the user's
current task already authorizes that exact class of action.

## Output shape

Up to 3 loops plus the refusals — don't force a loop for every corner. A clear
refusal beats a plausible-looking loop that runs to nowhere.

Per loop, a short scannable block with four fields: the **paste-ready `/loop`
line**, the **hard signal** it terminates on, the **hard bound** (naming its
self-paced assumption), and the **taste-gate line**.

> **Loop 1 — keep the suite green (the clean first loop)**
> ```
> /loop run `pnpm test`, fix the single top failure, then re-run; stop when
> `pnpm test` exits 0 twice in a row, when the same failure repeats twice in
> a row, or after 10 iterations / 60 minutes, whichever comes first
> ```
> - **Hard signal:** exit code of `pnpm test`.
> - **Hard bound:** 10 iterations or 60 minutes — self-enforced by self-paced
>   `/loop`; on a fixed-cadence provider a human owns cancellation.
> - **Stays yours:** whether the result *feels* right — animation smoothness,
>   copy tone, visual polish — the loop never touches those.

Per refusal, an equally short block: the work item, the anti-pattern it trips,
and the one change that would make it loopable.

**A queue-loop must carry its own queue.** Derive the work-list *inside the loop
line* from source files ("build the list of X from `a.ts`, then drain it"), not
from a `STATUS`/backlog doc that may be stale or a list the user never gave. If
the queue can't self-derive, the loop isn't paste-ready — mark the gap or send it
to the refusals. The queue emptying is the success stop; the loop still needs a
separate hard turn/time bound.
