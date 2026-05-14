---
name: handoff
description: Compact the current session into a handoff snippet — saves to ~/.claude/handoffs/ and prints for copy-paste. Use when creating a handoff. Do NOT invoke when reading a handoff snippet pasted from another session — treat it as context and continue the work.
---

# Handoff

Judgment exercise, not template fill. The failure mode is a polished snippet that mostly restates what the next session could read off `git status`.

Reconstruct mentally: goal, what was tried and why it failed, what's actually true vs. just discussed, the obvious next move, anything that would silently bite the next session.

For each piece of content: *will the next session waste time, repeat a mistake, or miss the goal without this?* If no, omit.

Save to `$HOME/.claude/handoffs/YYYY-MM-DD-HHmm-<slug>.md` (slug from goal, kebab-case). Create dir if missing. Delete `*.md` older than 30 days in that dir.

Reply: `Saved to <path>. Snip below for cross-context paste:` then a **four**-backtick `markdown` fenced block with the same content as the file. (Four-tick outer fence so 3-tick blocks inside render when pasted.)

**Content:**
- Required: `# Handoff: [task]` title; disclaimer blockquote (verbatim below)
- Almost always: Goal, Next
- Opt-in: Failed Approaches, Key Decisions, Code Context, Current State, Warnings, Setup

> Handoff written from session memory. Verify anything load-bearing before acting.
