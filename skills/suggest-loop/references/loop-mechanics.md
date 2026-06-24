# /loop mechanics — packed for suggest-loop

> **Datestamped: verified 2026-06-24** from a web sweep + a docs-reading pass.
> `/loop`, the **Monitor** tool, and `/goal` all post-date the Jan-2026 training
> cutoff — a session reasoning from memory **gets them wrong** (it did: Opus 4.8
> confidently proposed `.claude/loop.md` + a `/goal` combo as the *starting*
> shape, both off). That blind spot is the whole reason this block exists. Some
> exact limits below are disputed across sources (flagged inline) — **re-verify
> against [`code.claude.com/docs/en/scheduled-tasks`](https://code.claude.com/docs/en/scheduled-tasks)
> before quoting a hard number.** Treat this as re-checkable, not frozen.

This file is the load-bearing payload of the `suggest-loop` skill. Read it
before emitting any `/loop` suggestion. The skill exists *because* the mechanics
can't be reconstructed from training.

## What `/loop` is

A Claude Code slash command (landed ~March 2026) that re-fires a prompt or
slash-command on a recurring cadence **inside the current session** — a
session-scoped heartbeat. It's the polling/babysit primitive: "check the deploy
every 5 min", "watch this PR until CI is green", "run the suite, fix the top
failure, repeat". It is **orthogonal to** `/goal` (which judges a completion
condition, not time) and **distinct from** `/schedule` cloud routines (which run
unattended off your machine).

## The three forms

- **Fixed interval** — `/loop <interval> <prompt>`, e.g.
  `/loop 5m check if the deploy finished and report what happened`. Claude
  converts the interval to a jittered cron schedule and fires each tick. Right
  for **predictable cadences** (poll something on a clock).
- **Self-paced (dynamic)** — `/loop <prompt>` with *no* interval. After each
  iteration Claude picks the next delay itself (≈1 min – 1 hr) via the
  `ScheduleWakeup` mechanism and **prints the reason for each wait** — short
  while a build/PR is active, long when idle. Right for **uncertain timelines**
  (a PR might merge in 30s or 30m). The stop condition lives in the prompt
  itself ("…stop when the suite is green") — self-paced `/loop` checks it each
  turn and **can end itself** when provably complete.
- **Bare `/loop`** (no prompt) — runs a built-in maintenance prompt (continue
  unfinished work → tend PR/CI → cleanup), *or* reads `.claude/loop.md` (project
  or user level) if present, which replaces the default. `loop.md` is
  loop-as-code: check it in next to the code it drives. **Convenience for a loop
  you run often — not the starting point. Inline in the prompt is primary.**

## Event-driven alternative: the Monitor tool

For watching logs/files/status, the **Monitor tool** (~April 2026) streams
events and lets Claude react the instant something changes — no polling
interval, no turn held open. Self-paced `/loop` may use Monitor *instead of*
heartbeat ticks when the work is "react when X appears" rather than "re-check on
a clock". Tail-a-log-and-flag-errors is the canonical Monitor case;
check-deploy-every-5-min is the `/loop` case.

## Two gates a suggestion must pass

**1. Is the loop well-formed?** It needs a **hard termination signal** baked
into the prompt — a *queue that empties* (a work-list) or a *gate that goes
green* (tests pass, `exit 0`, an analyser peak over threshold, a `[diag]` line
matches). "Fix until no more bugs appear" is the anti-pattern: no measurable
done, so the loop never knows it's finished.

**2. Is the work autonomy-suitable at all?** A *different* criterion: **autonomy
follows the oracle.** Where correctness is a fact about the world (a spec, a
hash, a measured peak) the loop checks itself; where "correct" lives in the
user's taste (does it *sound* good, does the UI *feel* right) it is **ear-gated**
and a human gates every step. Most real work is a split — scope the loop to the
machine-measurable half; the taste call stays the human's. Naming that seam
explicitly in the suggestion is the point, not a footnote.

## `/goal` — optional reinforcement, not a requirement

`/goal <condition>` sets a session-scoped completion condition; after each turn
a small fast model judges whether it holds and re-fires if not. Reach for it
**only when "done" is judgment-heavy** and you don't trust the loop to call its
own completion honestly (the early-"done" failure mode). When "done" is a hard
measurement (exit code, empty queue), the inline stop condition suffices — plain
`/loop`, no `/goal`. The `/goal` evaluator only sees what Claude surfaces in the
conversation; phrase any condition as something Claude's output can *demonstrate*
(`pnpm test exits 0`, `git status clean`), and add a turn/time bound
(`or stop after 20 turns`) to cap runaway runs.

## How it compares to the neighbours

| Primitive | Next iteration fires when | Scope / survives | Best for |
|---|---|---|---|
| `/loop` (fixed) | A time interval elapses | Session-scoped; restored on `--resume` if unexpired | Predictable polling on a clock |
| `/loop` (self-paced) | Claude-chosen delay (`ScheduleWakeup`) | Same; can self-terminate | Uncertain timelines (PR babysit) |
| `/goal` | Previous turn finishes | Session-scoped; condition restored on resume | Run-until a *checkable* end state |
| Monitor tool | An event streams in | Session-scoped; **never** restored | React the instant X happens |
| `/schedule` (routine) | Cloud cron | **Off-machine, durable, fresh context each run** | True unattended recurring jobs |
| background Bash | n/a (one-shot) | Auto-notifies on completion | Local builds/tests you'll be pinged about |

Key line: **`/loop` needs the session open** — it dies when you close it,
restores on `--resume`, a *fresh* session clears it. For unattended-across-sleep,
that's `/schedule`, not `/loop`. And for a *local* build/test you don't need a
loop at all — background Bash notifies you when it exits. Only reach for `/loop`
when there's genuine iteration (fix→re-run→fix) or genuine waiting (poll until X).

## Limits & footguns (re-verify exact numbers against docs)

- **Session-scoped.** Stops firing when the session closes; `--resume` /
  `--continue` restores unexpired recurring tasks. Background Bash and Monitor
  tasks are **never** restored.
- **Auto-expiry.** A hard cap forces a review point. **Sources disagree — blogs
  say 72 h, a docs-reading pass said 7 days.** Treat as "a few days, re-check
  docs", not a known constant.
- **~50 scheduled tasks per session** (fixed + self-paced combined); **1-min
  minimum interval**; recurring fires are **jittered**; **no catch-up** on
  missed fires (fires once when idle, not once per miss).
- **Cloud platforms (Bedrock/Vertex/Foundry):** `ScheduleWakeup` absent →
  self-paced `/loop` falls back to a fixed ~10-min schedule; `loop.md` and
  Monitor may be unavailable.
- **Usage-window cost:** each wakeup is a model invocation. The prompt cache TTL
  is ~5 min, so intervals ≤5 min tend to hit cache (cheaper) and ≥15 min miss
  it. Loops also advance the rolling 5 h usage window like any use.

## Keeping this current

Condensed 2026-06-24 from a verified review of the `/loop`, Monitor, and `/goal`
surface against Anthropic's own documentation. This file is the self-contained
copy — nothing external is read at skill runtime. The docs are the source of
truth: if this block drifts from them, the docs win. Re-verify against
[`code.claude.com/docs/en/scheduled-tasks`](https://code.claude.com/docs/en/scheduled-tasks)
(and the `/goal` docs) and bump the datestamp at the top when you do.
