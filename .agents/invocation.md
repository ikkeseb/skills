# Invocation convention

Every skill in this repo is *intended* user-invoked — reached through an
explicit invocation (`/name` in Claude Code, the `$` skill picker in Codex)
rather than self-triggering from a matching request — **with one deliberate
exception, `handoff`** (see below). What changed on 2026-07-22 is the
*enforcement*: the frontmatter flag that used to encode this is banned.

## Why no `disable-model-invocation: true`

In current Claude Code the flag removes the skill from the model's view
entirely, and because a typed `/name` run is executed by the model calling the
Skill tool, a hidden skill cannot be invoked **even by explicit slash
command** — it shows in autocomplete and the `/skills` panel ("user-only ·
locked by author") but the model reports it doesn't exist. Field-confirmed
2026-07-22; known upstream as anthropics/claude-code #26251, #38969, #43875
(unfixed as of v2.1.217). `skillOverrides` cannot un-hide an author-locked
skill (frontmatter wins), so there is no consumer-side escape: the flag makes
a skill unusable, full stop. Earlier repo history assumed slash invocation
kept working under the flag — that was wrong.

Mechanics now:

- **Frontmatter carries no invocation flag.** The user-invoked intent is
  carried by description wording alone: descriptions are what a human reads in
  the marketplace listing and the `$` picker — what the skill does and when to
  reach for it, never activation bait. That is the guard against unwanted
  auto-triggering.
- **Codex markers are unaffected by the bug and keep encoding intent:** a
  Codex-supported user-invoked skill carries
  `policy.allow_implicit_invocation: false` in its `agents/openai.yaml`.
- **Per-machine tuning happens in settings `skillOverrides`** (consumer-side,
  not shipped): `name-only` lists the skill by bare name — invocable, near-zero
  ambient context, effectively inert as a trigger. Avoid the
  `user-invocable-only` override for these skills: on current Claude Code it
  hides personal skills from the model just like the frontmatter flag did.

## The `handoff` exception

`handoff` is the one skill the model legitimately reaches for on its own — at
session wrap-up, when a continuation handoff is the obviously right tool. It
is model-invokable in both harnesses: its `agents/openai.yaml` sets
`policy.allow_implicit_invocation: true`. (Decided in 0.7.4, when hiding it
made the model improvise a `handoff.md` instead of using the skill.)

`agents/openai.yaml` presence is also the repo's machine-readable marker for
"this skill is Codex-supported" — see `.agents/adr/0001-agent-agnostic-repo.md`.
