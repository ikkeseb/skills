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
