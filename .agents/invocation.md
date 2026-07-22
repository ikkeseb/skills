# Invocation convention

Every skill in this repo is user-invoked — it fires only on an explicit
invocation (`/name` in Claude Code, the `$` skill picker in Codex) and never
triggers itself from a matching request — **with one deliberate exception,
`handoff`** (see below). User-invoked skills cost zero ambient context and keep
activation fully predictable. (Decided 2026-07-17; the repo previously carried a
two-class user-/model-invoked axis.)

Mechanics, kept in sync everywhere:

- Frontmatter carries `disable-model-invocation: true` — on every user-invoked
  skill.
- When the skill is Codex-supported, its `agents/openai.yaml` carries
  `policy.allow_implicit_invocation: false`. The pair stays in sync: a skill
  is user-invoked in both harnesses or neither.

## The `handoff` exception

`handoff` is the one skill the model legitimately reaches for on its own — at
session wrap-up, when a continuation handoff is the obviously right tool. Making
it user-invoked hid it from the model entirely: `disable-model-invocation`
removes a skill from the model's view, and `skillOverrides` cannot un-hide it
(the frontmatter flag wins). So instead of using the skill the model improvised a
`handoff.md` in the working repo and reported "no /handoff skill in my list."
Slash invocation was never the problem — it always worked; only the model's
autonomous *reach* was blocked.

So `handoff` is model-invokable in both harnesses: it carries **no**
`disable-model-invocation` flag, and its `agents/openai.yaml` sets
`policy.allow_implicit_invocation: true`. The pair still stays in sync — just on
the model-invokable side. Per-machine delivery config (dotfiles `skillOverrides`,
e.g. `name-only`) tunes how eagerly the model surfaces it without re-hiding it.

Descriptions are no longer trigger surface — they are what a human reads in
the marketplace listing and the `$` picker. Write them for that reader:
what the skill does and when to reach for it, not activation bait.

`agents/openai.yaml` presence is also the repo's machine-readable marker for
"this skill is Codex-supported" — see `.agents/adr/0001-agent-agnostic-repo.md`.
