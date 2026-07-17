# AGENTS.md

Agent instructions for this repository.

## Instruction source

`AGENTS.md` is canonical for every harness. `CLAUDE.md` is a one-line import adapter (`@AGENTS.md`) so Claude Code loads this file; Codex CLI reads it natively. Edit here, never in `CLAUDE.md`. Repo-level agent conventions (invocation axis, ADRs) live in `.agents/`.

This is a skills repository — a collection of agent skills published as a Claude Code plugin (`ikkeseb-skills`) via `.claude-plugin/plugin.json`, with selected skills also usable from Codex CLI.

## Structure

Each skill lives in `skills/<name>/` with a `SKILL.md` whose YAML frontmatter (`name`, `description`, optional `allowed-tools`) is how Claude Code discovers and triggers the skill. Other files in the skill folder (references, scripts, assets) load on demand: keep the core workflow in `SKILL.md`, put branch-only or bulky reference in sibling files, and word each pointer to say when to read it.

The plugin also ships subagent definitions from top-level `agents/` (auto-discovered; not governed by the manifest's `skills` list). Bump the plugin `version` whenever shipped content changes — it is the update/cache key for installs. The `version` fields in `.claude-plugin/plugin.json` and `.codex-plugin/plugin.json` are one repository-wide release version: keep them equal and bump both in the same commit.

The repo is also a Codex CLI plugin: Codex reads `.claude-plugin/marketplace.json` for the marketplace, but `.codex-plugin/plugin.json` takes precedence over `.claude-plugin/plugin.json` as the plugin manifest — its narrower `skills` list is what Codex advertises to the model (the whole repo is still copied into the consumer's cache; the list filters exposure, not download).

## Maintainer-local workspace

Gitignored `local/`, when present, is maintainer-internal — follow
`local/AGENTS.md`. Never run `git clean -x` variants in this repo; they
delete it.

## Adding or renaming a skill

Four places must stay in sync:

1. The folder under `skills/`
2. The entry in the top-level `README.md` skills list
3. The explicit `skills` list in `.claude-plugin/plugin.json` — the published
   plugin ships exactly this set. (This works as an allowlist only because the
   marketplace entry's `source` is the marketplace root — that exception makes
   the list *replace* the default `skills/` scan instead of adding to it.
   Validate with `claude plugin validate . --strict` after editing — but note
   it only validates the manifests, not skill files. Also YAML-parse every
   changed `SKILL.md` frontmatter; an unquoted `description:` containing
   ": " (colon+space) is invalid YAML the validator will not catch.)
4. The `skills` list in `.codex-plugin/plugin.json`, which must equal exactly
   the set of skills carrying `agents/openai.yaml` (the Codex-support marker
   stays the single source of truth — check with
   `ls skills/*/agents/openai.yaml`). Codex-only README bits: the four-skill
   enumeration in the Install section.

The `plugin.json` `description` stays generic (don't enumerate skill names
there). If the three drift, users get a misleading README or a plugin that
silently misses a skill. Update all three in the same change.

## Conventions

- Every skill is user-invoked (command-only, never auto-triggered); the mechanics and description-writing rules live in `.agents/invocation.md`.
- Each meaning lives once per skill. Don't restate a rule across description, body, tables, and checklists — keep it where it governs behaviour. Prose that wouldn't change the agent's behaviour if deleted gets deleted.
- In procedural skills where steps can fail or branch, end each step on a checkable "done when".
- Skills are self-contained: a `SKILL.md` body never references another skill by name. Posture skills coordinate through capability-based ownership declarations instead — each states what it owns and what it defers (breadth, instrument, teardown, spend, interaction) so any combination resolves without the skills knowing about each other. Sole exception: a `description:` field may name a sibling skill purely for trigger disambiguation (e.g. drawio vs excalidraw) — such pointers degrade harmlessly when the sibling isn't installed.
- No build, lint, or test step. Content is markdown + YAML.
- All repository content — every `SKILL.md`, reference file, and this `AGENTS.md` — is written in English, whatever language a session converses in. (A skill's *runtime output* follows the session; the committed artifacts stay English.)
- Skills publish publicly via the marketplace, so keep content free of PII and sensitive detail, don't personalize instructions (no personal names), and don't hard-wire a skill's logic to a specific private repo. Illustrative example flavor is fine — the bar is "no PII / nothing sensitive," not "never name a project." De-personalize before committing.
