---
name: handoff
description: "Write a paste-ready handoff for continuing the current task in a fresh session, returned in the reply only (no file is written). Use when asked to hand off or produce continuation context. Not for reading or resuming from a pasted handoff."
---

# Handoff

A handoff is a judgment exercise, not template fill: the failure mode is a polished snippet that restates what the next session could read off `git status`.

Do not substitute `/compact`, `/resume`, or `/fork`, and do not continue implementation except for narrow, read-only checks needed to make the handoff accurate.

## Build the handoff

1. Reconstruct the goal, verified state, discussed but unimplemented plans, failed approaches, clearest next action, and anything that could silently block or mislead the next session. If little is reconstructable (fresh or freshly compacted session), say so and write the short honest handoff rather than padding it.
2. Run only cheap, read-only checks when a material fact is uncertain, such as the repository path, branch, current commit, or worktree state. Do not broaden the task into a new investigation.
3. Distinguish verified facts from assumptions or discussion. Never describe work as complete without the verification required by the active repository guidance.
4. Omit facts the next session can recover cheaply unless their interpretation matters. Prefer decisions, constraints, failure reasons, and precise next actions over a transcript summary.
5. Match the language used with the user for the body content. Commands, paths, identifiers, and source-language technical terms where translation would reduce precision, plus the required title, section headings, and disclaimer, stay in English exactly as specified.
6. Never include secrets. Include private or personal details only when they are necessary to continue the task safely.

Done when: the draft distinguishes verified fact from assumption, and the clearest next action is stated and executable.

A handoff is transient state that lives in the reply, not on disk. It does not replace durable repository guidance. If a lasting decision or invariant still needs capture in the repository's agent guidance (`AGENTS.md` / `CLAUDE.md`) or project docs, flag that gap in the handoff; do not edit durable files during handoff creation unless the user asks.

## Structure the content

- Required: `# Handoff: [task]`, with the disclaimer below verbatim as the first line under the title.
- Almost always: `## Goal` and `## Next`.
- Only when useful: `## Current State`, `## Key Decisions`, `## Failed Approaches`, `## Verification`, `## Code Context`, `## Warnings`, or `## Setup`.

Make `## Next` executable: lead with the clearest next step, then name any prerequisite, blocker, or approval it needs.

> Handoff written from session memory.

## Reply

Reply with exactly these parts, in order, and nothing after the closing fence:

1. `Paste the snip below into the receiving session, opening with "handover: " (leading with the literal word "handoff" can invoke this skill again).`
2. A `markdown` fence containing exactly the handoff content. Choose the
   fence length dynamically: find the longest contiguous run of backticks in the
   content and use at least one more, with four backticks as the minimum.

Write no file and run no cleanup: the snippet is the whole deliverable. If
the user wants it kept, they save it where they choose.

Done when: the reply contains the fenced snippet and nothing else.
