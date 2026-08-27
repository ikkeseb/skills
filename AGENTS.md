# AGENTS.md

Agent instructions for this repository.

## Instruction source

`AGENTS.md` is canonical for every harness. `CLAUDE.md` is a one-line import adapter (`@AGENTS.md`) so Claude Code loads this file; Codex CLI reads it natively. Edit here, never in `CLAUDE.md`.

This is a skills repository — a collection of agent skills published as a Claude Code plugin (`ikkeseb-skills`) via `.claude-plugin/plugin.json`, with selected skills also usable from Codex CLI.

## Structure

Each skill lives in `skills/<name>/` with a `SKILL.md` whose YAML frontmatter (`name`, `description`, optional `allowed-tools`) is how Claude Code discovers the skill. Other files in the skill folder (references, scripts, assets) load on demand: keep the core workflow in `SKILL.md`, put branch-only or bulky reference in sibling files, and word each pointer to say when to read it.

The plugin also ships subagent definitions from top-level `agents/` (auto-discovered; not governed by the manifest's `skills` list). Bump the plugin `version` whenever shipped content changes — it is the update/cache key for installs. The `version` fields in `.claude-plugin/plugin.json` and `.codex-plugin/plugin.json` are one repository-wide release version: keep them equal and bump both in the same commit.

`agents/codex-worker.md` resolves its helper script through a list of candidate paths, because the plugin-root placeholder is only rewritten for plugin installs and nothing else about the deployment is fixed. After editing that list, run `MSYS=winsymlinks:nativestrict sh skills/orchestrate/scripts/check-helper-resolution.sh` from outside this repo on Windows (plain Git Bash can copy instead of linking); on macOS/Linux, run the script normally. It extracts the block from the agent file and resolves it from foreign working directories under simulated deployments.

The repo is also a Codex CLI plugin: Codex reads `.claude-plugin/marketplace.json` for the marketplace, but `.codex-plugin/plugin.json` takes precedence over `.claude-plugin/plugin.json` as the plugin manifest — its narrower `skills` list is what Codex advertises to the model (the whole repo is still copied into the consumer's cache; the list filters exposure, not download).

## Maintainer-local workspace

If a `local/` directory exists here, you are on a maintainer machine: read
`local/STATUS.md` before starting work. It carries release state plus active
and parked leads, so you don't re-propose something already decided.
`local/AGENTS.md` governs everything under it. It is a separate nested git
repo, not a submodule, so a git ask that doesn't name a target ("pull both
repos", "pull skills and local") covers this repo *and* `local/`. `local/` is
gitignored, so a clone or plugin install simply won't have it — skip this
section when it's absent. Never run `git clean -x` variants in this repo;
they delete it.

## Adding or renaming a skill

These must stay in sync:

1. The folder under `skills/`
2. The entry in the top-level `README.md` skills list
3. The `skills` list in `.codex-plugin/plugin.json`, which must equal exactly
   the set of skills carrying `agents/openai.yaml` (the Codex-support marker
   stays the single source of truth — check with
   `ls skills/*/agents/openai.yaml`). Codex-only README bits: the skill
   enumeration in the Install section.

`.claude-plugin/plugin.json` deliberately carries **no** `skills` key: Claude
Code discovers every `skills/*/SKILL.md`; the key neither curates nor restricts
the shipped set. Do not reintroduce it as an allowlist.

Run `bash scripts/check-repo.sh` for the repository-wide static and runtime
checks. On Windows, set `MSYS=winsymlinks:nativestrict` in the parent shell
before launching Bash. `claude plugin validate . --strict` validates the marketplace surface;
validate `.claude-plugin/plugin.json` directly as a separate Claude manifest
check. The repo check enforces this repository's restricted frontmatter shape
and catches malformed plain descriptions such as an unquoted value containing
`: `. For a release,
`claude plugin details <name>` on an isolated test install remains the honest
check that Claude ships the expected inventory and reports its always-on cost.

The `plugin.json` `description` stays generic (don't enumerate skill names
there). If any of these drift, users get a misleading README or a plugin that
silently misses a skill. Update all of them in the same change, and add the
`CHANGELOG.md` entry alongside the version bump.

## Conventions

- `disable-model-invocation` is banned in every SKILL.md (third ban, 2026-08-20; check-repo fails on presence). The flag's behavior has flipped across Claude Code versions: on 2.1.237 a flagged skill was uninvocable outright — hidden from the model's own skill list, and a typed `/name` is executed by the model calling the Skill tool (`git show accdcba`, 0.21.1); on 2.1.247 a typed `/name` dispatches again and the flag behaves as user-only (tui-probe against a fresh interactive session, Mac 2026-08-27, dotfiles `93132eb`). The ban stands on that instability: user-invoked intent lives in description wording plus per-machine consumer `skillOverrides: name-only`, the one level that has worked on every measured version (`user-invocable-only` shares the flag's model-hiding and its version risk). Picker visibility and headless dispatch do not prove invocability: measure with the model's own available-skills list or a real typed dispatch in a fresh interactive session, no reload. Descriptions say what the skill does, when to reach for it, and the nearest exclusion; never activation bait. Earlier reasoning: `git show b4441a3` (0.7.5).
- `allowed-tools` in skill frontmatter pre-approves the listed tools for the invoking turn; it does not restrict the tool set (vendor skills doc, verified 2026-08-11: "It does not restrict which tools are available"). It therefore cannot express an analysis-only guarantee — a skill's do-not-edit promise stays prose — and is added only to smooth prompts for tools a skill legitimately needs.
- A Codex-supported user-invoked skill carries `policy.allow_implicit_invocation: false` in its `agents/openai.yaml` — the Codex-side expression of the same convention. Whether that marker is behind the Codex symptom "slash command exists, skill body never loads" is unknown (not investigated as of 2026-08-20).
- Each meaning lives once per skill. Don't restate a rule across description, body, tables, and checklists — keep it where it governs behaviour. Prose that wouldn't change the agent's behaviour if deleted gets deleted.
- In procedural skills where steps can fail or branch, end each step on a checkable "done when".
- Skills are self-contained: a `SKILL.md` body never depends on another skill's semantics. Posture skills coordinate through capability-based ownership declarations instead — each states what it owns and what it defers (breadth, instrument, teardown, spend, interaction) so any combination resolves without the skills knowing about each other. A `description:` may name a sibling solely for trigger disambiguation. A shared executable may be referenced by path when the plugin ships it and duplicating it would create runtime drift; each consumer still owns its complete behavioral contract.
- The repository includes executable Bash and Node helpers. Run the checks required by the changed surface; `bash scripts/check-repo.sh` is the aggregate gate.
- All repository content — every `SKILL.md`, reference file, and this `AGENTS.md` — is written in English, whatever language a session converses in. (A skill's *runtime output* follows the session; the committed artifacts stay English.)
- Skills publish publicly via the marketplace, so keep content free of private or sensitive detail, don't personalize instructions, and don't hard-wire a skill's logic to a specific private repo. Standard public repository attribution is the only identity exception. Illustrative example flavor is fine; de-personalize before committing.
