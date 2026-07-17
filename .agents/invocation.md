# Invocation convention

Every skill in this repo is user-invoked: it fires only on an explicit
invocation (`/name` in Claude Code, the `$` skill picker in Codex) and never
triggers itself from a matching request. This costs zero ambient context and
keeps activation fully predictable. (Decided 2026-07-17; the repo previously
carried a two-class user-/model-invoked axis.)

Mechanics, kept in sync everywhere:

- Frontmatter carries `disable-model-invocation: true` — on every skill.
- When the skill is Codex-supported, its `agents/openai.yaml` carries
  `policy.allow_implicit_invocation: false`. The pair stays in sync: a skill
  is user-invoked in both harnesses or neither.

Descriptions are no longer trigger surface — they are what a human reads in
the marketplace listing and the `$` picker. Write them for that reader:
what the skill does and when to reach for it, not activation bait.

`agents/openai.yaml` presence is also the repo's machine-readable marker for
"this skill is Codex-supported" — see `.agents/adr/0001-agent-agnostic-repo.md`.
