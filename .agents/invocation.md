# Invocation convention

Every skill in this repo is deliberately one of two kinds. Pick the kind when
the skill is born; changing it later is a design decision, not a tweak.

- **User-invoked** — the human is the index; the skill fires only on an
  explicit invocation (`/name` in Claude Code, `$name` in Codex). It costs
  zero ambient context. Frontmatter carries `disable-model-invocation: true`,
  and when the skill is Codex-supported its `agents/openai.yaml` carries
  `policy.allow_implicit_invocation: false`. The pair stays in sync: a skill
  is user-invoked in both harnesses or neither.
- **Model-invoked** — the `description:` field is trigger surface loaded every
  turn, so it pays context cost continuously and earns hard pruning: a precise
  activation rule (when to use, when NOT to use), never a marketing blurb.

`agents/openai.yaml` presence is also the repo's machine-readable marker for
"this skill is Codex-supported" — see `.agents/adr/0001-agent-agnostic-repo.md`.
