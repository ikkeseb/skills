# ADR 0001 — One canonical, agent-agnostic skills repo

**Status:** accepted (2026-07-16)

## Context

Skills here were consumed by Claude Code (marketplace plugin + maintainer
symlinks), while a separate `codex-skills` repo held one Codex-native port
(`handoff`) whose body diverged hard. Two repos solve distribution, not
semantic drift: every improvement lands twice or rots in one place. A live
investigation (Codex 0.144.5 source + isolated probes) confirmed Codex
discovers nested `skills/<name>/SKILL.md` recursively and tolerates
Claude-specific frontmatter, so one repo can serve both harnesses.

## Decision

- This repo is the single canonical home for every skill, whatever harness
  consumes it. One `SKILL.md` per skill; hard harness divergence is a minimal
  inline branch in that body, never a per-harness fork or adapter file.
- Distribution to consumers is package-based per harness: the Claude Code
  marketplace plugin today, a Codex packaging route once its manifest
  mechanics are verified. Maintainer-local symlinks are not a distribution
  channel and get no repo tooling until they cause real friction.
- `agents/openai.yaml` in a skill folder is the positive marker "this skill
  is Codex-supported". It is added on demand — when the body is actually
  neutralised and verified under Codex — never speculatively.
- Skills whose substance is Claude machinery stay Claude-only by design
  (currently `orchestrate`, `suggest-loop`, `context-audit`) and don't get
  `agents/openai.yaml` while so classified. Porting them as-is would
  mistranslate, not translate. The classification is revisitable per skill —
  `context-audit` is the most plausible future port (its subject matter
  generalises to AGENTS.md/config auditing); the posture skills are not.
- `codex-skills` is retired once `handoff` is merged here and canary-verified
  in both harnesses; it is archived as a shell with a README pointer.

## Consequences

Improvements land once. The Codex-supported set is explicit and greppable.
The published Claude plugin is curated via the explicit `skills` list in
`.claude-plugin/plugin.json`. Full background and evidence:
`docs/plans/2026-07-16-agent-agnostic-skills-plan.md`.

## Amendment (2026-07-17) — Codex packaging route verified and adopted

Verified against codex-cli 0.144.5 with isolated `CODEX_HOME` probes and
`codex debug prompt-input` (deterministic view of what the model sees):

- `codex plugin marketplace add <path|owner/repo|git-url>` followed by
  `codex plugin add <plugin>@<marketplace>` installs this repo end-to-end
  from GitHub. Codex reads the `.claude-plugin/` manifests natively and
  copies the whole repo into a version-keyed cache
  (`$CODEX_HOME/plugins/cache/<marketplace>/<plugin>/<version>/`).
- The manifest's `skills` array is honored as the advertisement allowlist;
  skills surface to the model as `<plugin>:<name>`.
- `.codex-plugin/plugin.json` takes precedence over
  `.claude-plugin/plugin.json` when both exist, so one repo ships
  harness-specific skill sets from a single marketplace registration.
- Codex ignores Claude's `disable-model-invocation` frontmatter but honors
  `agents/openai.yaml` → `policy.allow_implicit_invocation: false`: the skill
  is not advertised to the model. It stays reachable through the TUI's `$`
  picker, which inserts a path-linked mention (`[$name](skill://…/SKILL.md)`)
  — verified to inject. A *plain-text* `$name` mention in `codex exec` does
  NOT resolve a policy-hidden plugin skill on 0.144.5 (it does resolve for
  filesystem-installed skills, which is how earlier symlink-era canaries
  passed). Exec-driven consumers of hidden skills must use the linked form.

Decision: the Codex packaging route is the plugin flow above, expressed as a
minimal `.codex-plugin/plugin.json` whose `skills` list must equal the set of
skills carrying `agents/openai.yaml` — the marker remains the single source
of truth, the manifest is its packaged expression. Both plugin manifests
share one release `version`, bumped together. The allowlist filters exposure,
not download: the full repo lands in the consumer's cache, so all content
stays public-safe regardless of harness classification.
