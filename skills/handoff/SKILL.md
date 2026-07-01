---
name: handoff
description: Compact the current session into a paste-ready handoff snippet (saved to `~/.claude/handoffs/`). Invoke ONLY when the user explicitly types `/handoff` — do NOT auto-invoke from cues like "wrap this up", "switching machines", or "context is full". Do NOT invoke when reading a pasted handoff snippet — that's context, continue the work.
---

# handoff

Judgment exercise, not template fill. The failure mode is a polished snippet that mostly restates what the next session could read off `git status`.

Reconstruct mentally: goal, what was tried and why it failed, what's actually true vs. just discussed, the obvious next move, anything that would silently bite the next session.

For each piece of content: *will the next session waste time, repeat a mistake, or miss the goal without this?* If no, omit.

**A handoff does not replace repo docs.** It's transient — local to one machine, doesn't sync. If a convention, gotcha, or decision should outlive this task, update CLAUDE.md or the relevant repo docs *first*; knowledge parked only in a snippet can be lost in transit. The handoff carries in-flight state, not the lasting record.

Save to `$HOME/.claude/handoffs/YYYY-MM-DD-HHmm-<slug>.md` (slug from goal, kebab-case). Create dir if missing. Delete `*.md` older than 30 days in that dir.

Reply: `Saved to <path>. Snip below for cross-context paste:` then a **four**-backtick `markdown` fenced block with the same content as the file.

**Content:**
- Required: `# Handoff: [task]` title; disclaimer blockquote (verbatim below)
- Almost always: Goal, Next
- Opt-in: Failed Approaches, Key Decisions, Code Context, Current State, Warnings, Setup

> Handoff written from session memory.
