# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

This is a Claude Code plugin (`ikkeseb-skills`) — a collection of skills published as a single plugin via `.claude-plugin/plugin.json`.

## Structure

Each skill lives in `skills/<name>/` with a `SKILL.md` whose YAML frontmatter (`name`, `description`, optional `allowed-tools`) is how Claude Code discovers and triggers the skill. Other files in the skill folder (references, scripts, assets) are loaded on demand by the skill itself.

## Adding or renaming a skill

Two places must stay in sync:

1. The folder under `skills/`
2. The entry in the top-level `README.md` skills list

Skills are auto-discovered from `skills/` at install time — `.claude-plugin/plugin.json` carries no skill list, and its `description` stays generic (don't enumerate skill names there). If the folder and the README drift, the README misleads users. Update both in the same change.

## Conventions

- The `description:` field in `SKILL.md` is the trigger surface — write it as a precise activation rule (when to use, when NOT to use), not a marketing blurb. Existing skills are the reference style.
- No build, lint, or test step. Content is markdown + YAML.
