---
name: handoff
description: Create and save a concise, paste-ready continuation handoff for resuming the current task in a fresh session.
---

# Handoff

A handoff is a judgment exercise, not template fill: the failure mode is a polished snippet that restates what the next session could read off `git status`. Create a compact, high-signal handoff for continuing the current task in a fresh session.

Do not substitute `/compact`, `/resume`, or `/fork`, and do not continue implementation except for narrow, read-only checks needed to make the handoff accurate.

## Build the handoff

1. Reconstruct the goal, verified state, discussed but unimplemented plans, failed approaches, clearest next action, and anything that could silently block or mislead the next session.
2. Run only cheap, read-only checks when a material fact is uncertain, such as the repository path, branch, current commit, or worktree state. Do not broaden the task into a new investigation.
3. Distinguish verified facts from assumptions or discussion. Never describe work as complete without the verification required by the active repository guidance.
4. Omit facts the next session can recover cheaply unless their interpretation matters. Prefer decisions, constraints, failure reasons, and precise next actions over a transcript summary.
5. Match the language used with the user. Preserve commands, paths, identifiers, and source-language technical terms where translation would reduce precision.
6. Never include secrets. Include private or personal details only when they are necessary to continue the task safely.

A handoff is transient, machine-local state. It does not replace durable repository guidance. If a lasting decision or invariant still needs capture in the repository's agent guidance (`AGENTS.md` / `CLAUDE.md`) or project docs, flag that gap in the handoff; do not edit durable files during handoff creation unless the user asks.

## Structure the content

- Required: `# Handoff: [task]` and the disclaimer below verbatim.
- Almost always: `## Goal` and `## Next`.
- Only when useful: `## Current State`, `## Key Decisions`, `## Failed Approaches`, `## Verification`, `## Code Context`, `## Warnings`, or `## Setup`.

Make `## Next` executable: lead with the clearest next step, then name any prerequisite, blocker, or approval it needs.

> Handoff written from session memory.

## Write the handoff

1. Choose the save directory for the active harness:
   - In Claude Code, use `$HOME/.claude/handoffs`.
   - In Codex, resolve the Codex home to `$CODEX_HOME` when it is set and non-empty; otherwise use `$HOME/.codex`, then use its `handoffs/` directory.
   Create the selected directory if needed.
2. Delete only top-level regular `*.md` files in that directory whose modification time is more than 30 days old. Do not recurse, follow symlinks, or delete any other file type.
3. Save the handoff as `YYYY-MM-DD-HHmm-<slug>.md` using local time and a short kebab-case slug derived from the goal.
4. Never overwrite a file. If the name already exists, append `-2`, `-3`, and so on before `.md`.
5. Ensure the saved file contains exactly the handoff Markdown and ends with a newline.

Done when: the file exists at the chosen path with exactly the handoff content — verify by reading it back, so a partial failure anywhere in the sequence is caught before the Reply claims success.

## Reply

After a successful write, reply with `Saved to <absolute path>. Snip below for cross-context paste:` followed by a four-backtick `markdown` fence containing exactly the saved file content. Add nothing after the fence.

If the write fails, do not claim it was saved. State the failure briefly and still return the paste-ready content in the same four-backtick fence.
