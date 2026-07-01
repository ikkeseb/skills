# context-audit

A global Claude Code skill that audits a project's `CLAUDE.md` and context
architecture and proposes a leaner structure — moving domain-specific rules out
of always-on static context into auto-loading skills, nested `CLAUDE.md` files,
or hooks.

## Why

Everything in `CLAUDE.md` loads on every session. The problem isn't the token
bill (a few thousand tokens is noise) — it's **attention**. Rules irrelevant to
the current task make the agent slower and more prone to conflating unrelated
guidance. Leaner static context keeps the agent sharp on the task in front of it.

## What it does

Analysis-only. When invoked it:

1. Reads the project `CLAUDE.md` and any required sub-files.
2. Classifies each rule on two axes — **type** (Instruction / Guardrail /
   Procedural / Reference / Knowledge) and **scope** (Universal / Domain /
   Sacred / Stale).
3. Routes each rule to the cheapest mechanism that still guarantees it shows up
   when needed: static `CLAUDE.md`, an auto-loading skill, a nested `CLAUDE.md`,
   or a hook.
4. Produces draft files plus an honest "is this worth it?" verdict.

It **does not edit anything** — you review the drafts and apply them yourself.

## How to use

In any project, invoke `/context-audit` (or just ask to "audit the CLAUDE.md" /
"slim the context" / "the agent loads too much"). It reads the setup and hands
back a proposal you can accept, tweak, or reject.

## Key design principles

- **Attention, not tokens.** Success = less irrelevant context per session, not
  a lower line count. Line-count thresholds are a soft nudge, never a rule.
- **Skills auto-load.** A skill's `description` is the native router — the agent
  pulls it in when the task matches. No routing table needed for skills; keep
  routing tables only for non-skill sub-files that can't self-route.
- **Guardrails are sacred.** Anti-regression rules are never dropped; they move
  *with* their domain into the skill, and the critical ones get a hook.
- **Don't over-split.** Lean, mostly-relevant files are left alone. A no-op
  audit is a valid result.

## Where things live

- **This skill** is generic → lives in `~/.claude/skills/context-audit/`
  (global, available in all projects).
- **Domain skills it proposes** are project-specific → live in each project's
  own `.claude/skills/`, committed to the repo so they sync across machines
  (not `.claude/commands/`, which is the legacy single-file form).

## Files

- `SKILL.md` — the skill instructions (loaded into context when the skill
  triggers).
- `README.md` — this file (human reference; not loaded into context).
