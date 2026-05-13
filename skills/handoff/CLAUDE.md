# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A single-file Claude Code skill called `handoff`. It generates a copy-paste-ready markdown snippet for transferring session context to a fresh Claude Code session. Flat layout — `SKILL.md` lives at the repo root, not under `skills/`.

## Layout

- `SKILL.md` — the skill (frontmatter + workflow).
- `README.md` — user-facing docs.
- `LICENSE` — MIT.

## Iterating on the skill

Edit `SKILL.md`, then trigger the skill in any Claude Code session by saying `/handoff`. If installed via symlink there's no reload step. Iterate against real conversations rather than synthetic test prompts — the skill is meant to compress session context, so it can only really be evaluated on a session that has context worth compressing.

## Design constraints — preserve these

Deliberate choices — don't undo on autopilot.

- **File + snippet.** Handoff is saved to `~/.claude/handoffs/` AND shown as a snippet inside a 4-backtick fence in chat. File for same-machine pickup; snippet for paste into a different repo, machine, or web Claude.
- **No resume-side mechanism.** No `/handoff:resume`, no auto-detection. The snippet is self-describing markdown — the user pastes it (or points the next session at the saved file) and tells the next Claude to continue.
- **Single mode.** No `full`/`quick` split. Length is driven by the "earn its place" rule, not a flag.
- **Opt-in inclusion.** Every section earns its place by giving the next session something they can't trivially derive from git/code. Default omit. Failed Approaches when there were any — no "None — happy path" padding. Keeps Claude out of template-fill mode.
- **Disclaimer.** Output leads with a one-line disclaimer ("Handoff written from session memory. Verify anything load-bearing before acting.") so the next session reads the snippet critically, not as spec.
- **30-day TTL on saved files.** Auto-cleanup happens in the skill workflow — `*.md` older than 30 days in the handoffs dir are deleted on next run. To keep a handoff as documentation, move it out.
- **English content.** Snippet template, README, and SKILL.md instructions are English. Trigger phrases are English (the user uses the word "handoff" verbatim regardless of conversational language).
