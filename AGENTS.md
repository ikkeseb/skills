# AGENTS.md

Agent instructions for this repository.

## Instruction source

`AGENTS.md` is canonical for every harness. `CLAUDE.md` is a one-line import adapter (`@AGENTS.md`) so Claude Code loads this file; Codex CLI reads it natively. Edit here, never in `CLAUDE.md`. Repo-level agent conventions (invocation axis, ADRs) live in `.agents/`.

This is a skills repository — a collection of agent skills published as a Claude Code plugin (`ikkeseb-skills`) via `.claude-plugin/plugin.json`, with selected skills also usable from Codex CLI.

## Structure

Each skill lives in `skills/<name>/` with a `SKILL.md` whose YAML frontmatter (`name`, `description`, optional `allowed-tools`) is how Claude Code discovers and triggers the skill. Other files in the skill folder (references, scripts, assets) are loaded on demand by the skill itself.

## Adding or renaming a skill

Three places must stay in sync:

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

The `plugin.json` `description` stays generic (don't enumerate skill names
there). If the three drift, users get a misleading README or a plugin that
silently misses a skill. Update all three in the same change.

## Conventions

- The `description:` field in `SKILL.md` is the trigger surface — write it as a precise activation rule (when to use, when NOT to use), not a marketing blurb. Existing skills are the reference style.
- Skills are self-contained: a `SKILL.md` body never references another skill by name. Posture skills coordinate through capability-based ownership declarations instead — each states what it owns and what it defers (breadth, instrument, teardown, spend, interaction) so any combination resolves without the skills knowing about each other. Sole exception: a `description:` field may name a sibling skill purely for trigger disambiguation (e.g. drawio vs excalidraw) — such pointers degrade harmlessly when the sibling isn't installed.
- No build, lint, or test step. Content is markdown + YAML.
- All repository content — every `SKILL.md`, reference file, and this `AGENTS.md` — is written in English, whatever language a session converses in. (A skill's *runtime output* follows the session; the committed artifacts stay English.)
- Skills publish publicly via the marketplace, so keep content free of PII and sensitive detail, don't personalize instructions (no personal names), and don't hard-wire a skill's logic to a specific private repo. Illustrative example flavor is fine — the bar is "no PII / nothing sensitive," not "never name a project." De-personalize before committing.
