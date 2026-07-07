# /loop mechanics — packed for suggest-loop

> **Datestamped: verified 2026-06-24** from a web sweep + a docs-reading pass.
> `/loop`, the **Monitor** tool, and `/goal` all post-date the Jan-2026 training
> cutoff — a session reasoning from memory **gets them wrong**. That blind spot
> is the whole reason this block exists. The docs are the source of truth: if
> this drifts from them, the docs win. Re-verify against
> [`code.claude.com/docs/en/scheduled-tasks`](https://code.claude.com/docs/en/scheduled-tasks)
> (and the `/goal` docs) and bump this datestamp when you do.

Read this before emitting any `/loop` suggestion — the skill exists *because*
these mechanics can't be reconstructed from training.

## What `/loop` is

A Claude Code slash command that re-fires a prompt or slash-command on a
recurring cadence **inside the current session** — a session-scoped heartbeat.
It's the polling/babysit primitive: "check the deploy every 5 min", "watch this
PR until CI is green", "run the suite, fix the top failure, repeat". It needs the
session open — it dies when you close it, restores on `--resume`. For unattended
recurring jobs that's `/schedule` (cloud cron), not `/loop`.

## The three forms

- **Fixed interval** — `/loop <interval> <prompt>`, e.g.
  `/loop 5m check if the deploy finished and report what happened`. Right for
  **predictable cadences** (poll something on a clock).
- **Self-paced (dynamic)** — `/loop <prompt>` with *no* interval. Claude picks
  the next delay itself after each iteration. Right for **uncertain timelines** (a
  PR might merge in 30s or 30m). The stop condition lives in the prompt itself
  ("…stop when the suite is green") — self-paced `/loop` checks it each turn and
  **can end itself** when provably complete.
- **Bare `/loop`** (no prompt) — runs a built-in maintenance prompt, *or* reads
  `.claude/loop.md` if present. `loop.md` is loop-as-code: **convenience for a
  loop you run often — not the starting point. Inline in the prompt is primary.**

## Two gates a suggestion must pass

**1. Is the loop well-formed?** It needs a **hard termination signal** baked into
the prompt — a *queue that empties* (a work-list) or a *gate that goes green*
(tests pass, `exit 0`, a measured peak over threshold). "Fix until no more bugs
appear" is the anti-pattern: no measurable done, so the loop never knows it's
finished.

**2. Is the work autonomy-suitable at all?** A *different* criterion: **autonomy
follows the oracle.** Where correctness is a fact about the world (a spec, a
hash, a measured peak) the loop checks itself; where "correct" lives in the
user's taste (does it *sound* good, does the UI *feel* right) it is **ear-gated**
and a human gates every step. Most real work is a split — scope the loop to the
machine-measurable half; the taste call stays the human's. Naming that seam
explicitly is the point, not a footnote.

## `/goal` — optional reinforcement, not a requirement

`/goal <condition>` sets a session-scoped completion condition; after each turn a
small fast model judges whether it holds and re-fires if not. Reach for it **only
when "done" is judgment-heavy** and you don't trust the loop to call its own
completion honestly. When "done" is a hard measurement (exit code, empty queue),
the inline stop condition suffices — plain `/loop`, no `/goal`. The evaluator
only sees what Claude surfaces, so phrase any condition as something the output
can *demonstrate* (`pnpm test exits 0`, `git status clean`), and add a turn/time
bound (`or stop after 20 turns`) to cap runaway runs.
