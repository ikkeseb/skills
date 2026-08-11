---
name: handoff
description: Create and save a concise, paste-ready continuation handoff for resuming the current task in a fresh session. Saves to a handoffs directory chosen per harness and prunes saved handoffs older than 30 days.
---

# Handoff

A handoff is a judgment exercise, not template fill: the failure mode is a polished snippet that restates what the next session could read off `git status`.

Do not substitute `/compact`, `/resume`, or `/fork`, and do not continue implementation except for narrow, read-only checks needed to make the handoff accurate.

## Build the handoff

1. Reconstruct the goal, verified state, discussed but unimplemented plans, failed approaches, clearest next action, and anything that could silently block or mislead the next session. If little is reconstructable (fresh or freshly compacted session), say so and write the short honest handoff rather than padding it.
2. Run only cheap, read-only checks when a material fact is uncertain, such as the repository path, branch, current commit, or worktree state. Do not broaden the task into a new investigation.
3. Distinguish verified facts from assumptions or discussion. Never describe work as complete without the verification required by the active repository guidance.
4. Omit facts the next session can recover cheaply unless their interpretation matters. Prefer decisions, constraints, failure reasons, and precise next actions over a transcript summary.
5. Match the language used with the user for the body content. Commands, paths, identifiers, and source-language technical terms where translation would reduce precision — plus the required title, section headings, and disclaimer — stay in English exactly as specified.
6. Never include secrets. Include private or personal details only when they are necessary to continue the task safely.

Done when: the draft distinguishes verified fact from assumption, and the clearest next action is stated and executable.

A handoff is transient, machine-local state. It does not replace durable repository guidance. If a lasting decision or invariant still needs capture in the repository's agent guidance (`AGENTS.md` / `CLAUDE.md`) or project docs, flag that gap in the handoff; do not edit durable files during handoff creation unless the user asks.

## Structure the content

- Required: `# Handoff: [task]`, with the disclaimer below verbatim as the first line under the title.
- Almost always: `## Goal` and `## Next`.
- Only when useful: `## Current State`, `## Key Decisions`, `## Failed Approaches`, `## Verification`, `## Code Context`, `## Warnings`, or `## Setup`.

Make `## Next` executable: lead with the clearest next step, then name any prerequisite, blocker, or approval it needs.

> Handoff written from session memory.

## Write the handoff

1. Choose the save directory for the active harness:
   - In Claude Code, resolve the config home to `$CLAUDE_CONFIG_DIR` when it is set and non-empty; otherwise use `$HOME/.claude`, then use its `handoffs/` directory.
   - In Codex, resolve the Codex home to `$CODEX_HOME` when it is set and non-empty; otherwise use `$HOME/.codex`, then use its `handoffs/` directory.
   - In any other harness, use `$HOME/.claude/handoffs`.
   Create the selected directory if needed.
2. Save the handoff as `YYYY-MM-DD-HHmm-<slug>.md` using local time and a short ASCII kebab-case slug derived from the goal.
3. Never overwrite a pre-existing file. If the name already exists, append `-2`, `-3`, and so on before `.md`.
4. Ensure the saved file contains exactly the handoff Markdown and ends with a newline.
5. Read the new file back and verify its full content matches what you intended
   to write — watch line endings and the trailing newline, not just a skim. On a
   mismatch, rewrite the just-written file once (the no-overwrite rule protects
   pre-existing files, not this one); if it still mismatches, treat the write as
   failed and report the difference.
6. Only after that verification, best-effort delete top-level regular `*.md`
   files in the same directory whose modification time is more than 30 days old.
   Never recurse, follow symlinks, delete another file type, or delete the file
   just written. Cleanup failure does not invalidate a verified handoff; report
   it as a warning rather than claiming cleanup succeeded.

Done when: the file exists at the chosen path with exactly the handoff content,
readback-verified.

## Reply

After a successful write, reply with exactly these parts, in order, and nothing
after the closing fence:

1. One line on cleanup when it did anything or failed: how many files it
   deleted, and/or the failure warning (the write itself remains successful).
   Omit the line when cleanup found nothing to do.
2. `Saved to <absolute path>.`
3. `Paste the snip below into the receiving session, opening with "handover: " — leading with the literal word "handoff" can invoke this skill again.`
4. A `markdown` fence containing exactly the saved file content. Choose the
   fence length dynamically: find the longest contiguous run of backticks in the
   content and use at least one more, with four backticks as the minimum.

If the write fails, do not claim it was saved. State the failure briefly and
still return the paste-ready content using parts 3–4.

Done when: the reply contains the fenced snippet, the saved-path claim matches
what was verified on disk, and any cleanup claim reflects what actually
happened.
