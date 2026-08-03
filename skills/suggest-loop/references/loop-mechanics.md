# /loop mechanics — packed for suggest-loop

> **Verified 2026-08-03** against the current
> [Claude Code scheduled-task documentation](https://code.claude.com/docs/en/scheduled-tasks).
> The docs win if this reference drifts — re-verify against them and bump this
> datestamp when you do.

Read this before emitting a suggestion. `/loop` is a Claude Code bundled skill
for recurring prompts inside the current conversation.

## Forms and lifecycle

- `/loop <interval> <prompt>` uses a fixed cron-backed cadence. Fixed loops keep
  running until the user stops them or the platform's seven-day expiry fires.
- `/loop <prompt>` is self-paced. Claude chooses a delay from one minute to one
  hour after each iteration, may use the Monitor tool, and can stop the loop
  itself when the prompt's condition or cap is met. Some hosted providers use a
  fixed ten-minute cadence instead; there, prompt-only `/loop` cannot be treated
  as autonomously self-stopping.
- Bare `/loop` runs Claude Code's maintenance prompt, or `.claude/loop.md` /
  `~/.claude/loop.md` when present. Supplying a prompt ignores those files.

Scheduled tasks inherit the session's permissions and only fire while Claude
Code is running and idle. A fresh conversation clears them; `--resume` or
`--continue` restores unexpired recurring tasks created within seven days.
Seven-day expiry bounds forgotten platform tasks, but is not an acceptable hard
cap for a generated work loop.

Pressing `Esc` while a `/loop` waits clears its pending wakeup. Self-paced loops
can also stop themselves; fixed loops require user cancellation. A scheduled
skill call executes as a skill only when Claude is allowed to invoke that skill;
otherwise it reaches the session as plain text.

## Suggestion contract

A safe generated loop has all three:

1. a machine-checkable success condition;
2. an independent hard iteration or wall-clock cap; and
3. work whose correctness does not depend on unobserved human taste.

The loop prompt does not create authority. It may repeat only actions already
authorized by the user's task and the active session permissions.
