# AGENTS.md

Agent instructions for this repository.

## Instruction source

`AGENTS.md` is canonical for every harness. `CLAUDE.md` is a one-line import adapter (`@AGENTS.md`) so Claude Code loads this file; Codex CLI reads it natively. Edit here, never in `CLAUDE.md`.

This is a skills repository — a collection of agent skills published as a Claude Code plugin (`ikkeseb-skills`) via `.claude-plugin/plugin.json`, with selected skills also usable from Codex CLI via `.codex-plugin/plugin.json`.

## Structure

Each skill lives in `skills/<name>/` with a `SKILL.md` whose YAML frontmatter (`name`, `description`, optional `allowed-tools`) is how Claude Code discovers the skill. Other files in the skill folder (references, scripts, assets) load on demand: keep the core workflow in `SKILL.md`, put branch-only or bulky reference in sibling files, and word each pointer to say when to read it. Top-level `agents/` ships subagent definitions. The two plugin manifests carry one repository-wide release version.

## Conventions

- All repository content — every `SKILL.md`, reference file, and this `AGENTS.md` — is written in English, whatever language a session converses in. (A skill's *runtime output* follows the session; the committed artifacts stay English.)
- Skills publish publicly via the marketplace, so keep content free of private or sensitive detail, don't personalize instructions, and don't hard-wire a skill's logic to a specific private repo. Standard public repository attribution is the only identity exception.
- Skills are self-contained: a `SKILL.md` body never depends on another skill's semantics; a `description:` may name a sibling solely for trigger disambiguation.
- `bash scripts/check-repo.sh` is the aggregate static and runtime gate; run the checks required by the changed surface.

## Maintainer sessions

If a `local/` directory exists here, you are on a maintainer machine: read `local/AGENTS.md` and `local/STATUS.md` before starting work, and `local/MAINTAINING.md` before changing shipped content — release procedure, the add/rename/remove sync lists, frontmatter policy and authoring conventions live there, not in this file. `local/` is a separate nested private git repo (not a submodule), gitignored here, so a clone or plugin install simply won't have it — for such sessions the conventions above plus check-repo are the whole contract. A git ask that doesn't name a target ("pull both repos") covers this repo *and* `local/`. Never run `git clean -x` variants in this repo; they delete it.
