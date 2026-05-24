# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

This is a Claude Code plugin (`ikkeseb-skills`) — a collection of skills published as a single plugin via `.claude-plugin/plugin.json`.

## Structure

Each skill lives in `skills/<name>/` with a `SKILL.md` whose YAML frontmatter (`name`, `description`, optional `allowed-tools`) is how Claude Code discovers and triggers the skill. Other files in the skill folder (references, scripts, assets) are loaded on demand by the skill itself.

## Adding or renaming a skill

Three places must stay in sync:

1. The folder under `skills/`
2. The path in `.claude-plugin/plugin.json` → `skills`
3. The entry in the top-level `README.md` skills list

If a skill is added, removed, or renamed and any of the three drift, plugin install will look broken to users. Update all three in the same change.

## Conventions

- The `description:` field in `SKILL.md` is the trigger surface — write it as a precise activation rule (when to use, when NOT to use), not a marketing blurb. Existing skills are the reference style.
- No build, lint, or test step. Content is markdown + YAML.
