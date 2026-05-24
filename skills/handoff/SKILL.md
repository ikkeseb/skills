---
name: handoff
description: Compact the current session into a paste-ready handoff snippet (saved to `~/.claude/handoffs/`). Invoke ONLY when the user explicitly types `/handoff` — do NOT auto-invoke from cues like "wrap this up", "switching machines", or "context is full". Do NOT invoke when reading a pasted handoff snippet — that's context, continue the work.
---

# handoff

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

## Design invariants

- **No resume-side mechanism.** No `/handoff:resume`, no auto-detection. The snippet is self-describing — the next session reads it as context and continues.
- **Single mode.** No `full`/`quick` split. Length is driven by the "earn its place" rule, not a flag.
