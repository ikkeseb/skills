---
name: context-audit
description: >-
  Audit a project's CLAUDE.md and context architecture, then propose a leaner
  structure that moves domain-specific rules out of always-on static context
  and into auto-loading skills, nested CLAUDE.md files, or hooks — so the agent
  isn't slowed or distracted by rules irrelevant to the current task.
  Analysis-only: produces a classification, draft files, and an honest
  worth-it verdict for the user to apply by hand. Use this whenever the user
  wants to audit, slim, declutter, or reorganize a CLAUDE.md / context setup,
  mentions context bloat, a bloated or huge CLAUDE.md, the agent "loading too
  much" or "getting confused" by unrelated rules, or asks where a rule should
  live (static vs skill vs nested file vs hook). Do NOT trigger for routine
  edits that just add or change one rule.
---

# Context Audit

Audit exercise, not a line-count diet. The win is **attention, not tokens** — and the
failure mode is splitting a lean file into indirection nobody needed.

## Why

Everything in a project's `CLAUDE.md` is **static context** — it loads every session no
matter what the task touches. The tokens are cheap; the cost is that irrelevant rules
crowd the agent's attention, so it conflates unrelated rules or follows a guideline meant
for another subsystem. Keep static only what *every* session needs; let the rest load on
demand, exactly when the task calls for it. Claude Code supports this natively — map each
rule to the right loader, don't invent one.

## Mechanics — how Claude Code loads context

Build the proposal on the real mechanics, not folklore:

- **`CLAUDE.md` — static, always on.** Project file, any parent-directory `CLAUDE.md`,
  and the global `~/.claude/CLAUDE.md` all load every session. Global is the *most*
  expensive (it loads in every project), so meta-advice rarely belongs there.
- **Skills — three-level progressive disclosure.** (1) Metadata (name + `description`,
  ~100 tokens) is always in context. (2) The `SKILL.md` body loads **automatically when
  the model judges the task matches the description** — model-invoked is the *default*;
  typing `/name` is an additional manual path, not the only one. (3) Bundled
  `references/`, `scripts/` load only when the skill points to them. **The `description`
  is the router** — a sharp one pulls the skill in on its own. (Opt out with
  `disable-model-invocation: true` for manual-only.)
- **`paths:` glob on a skill** (e.g. `paths: ["**/*.css"]`) auto-activates it **only when
  the session touches matching files** — native, file-scoped, no routing prose.
- **Nested `CLAUDE.md`** loads when the agent works **in that directory subtree** — ideal
  when a domain maps cleanly to a folder.
- **Hooks — deterministic.** Configured in `settings.json` with a matcher on the tool
  name (`Edit`/`Write`); the hook command sees the tool input, including the file path. A
  **PreToolUse** hook can **hard-block** a bad change before it happens; a **PostToolUse**
  hook can **inject guardrail text** back into context after a matching edit. Hooks are
  the only mechanism that fires *guaranteed*, not "if the model matches" — reserve them
  for the handful of sacred invariants.

The upshot: a **spectrum**, not a static-vs-manual binary. Route each rule to the
cheapest mechanism that still guarantees it shows up when needed (see the table below).

## When to run — and when to stop

Run a full audit only when it pays back. Gauge two things:

- **Irrelevance fraction** — what share of the file a *typical* session never uses.
- **Session-hit-rate per domain** — a cluster touched in ~5% of sessions is a great
  move-out candidate; one touched in ~60% is not.

If the file is already lean and mostly relevant every session, **say so and stop** —
splitting adds indirection for no attention gain. Raw line count is a weak proxy: a
130-line file that's fully relevant is fine; an 80-line file that's 70% irrelevant is
not. (Past ~120 lines is *worth a look*, never automatically guilty. Any number is a
nudge, not a law.)

## Process

1. **Read** the project `CLAUDE.md` end to end, plus everything it says is required
   reading (nested `CLAUDE.md`, "read X before Y" READMEs, imports). You can't classify
   what you haven't read.
2. **Map** the folder structure and stack so you know which domains exist and roughly how
   often each is worked — that's where the hit-rate estimate comes from.
3. **Classify** each rule on the two axes below.
4. **Place** each rule via the table below.
5. **Draft** ready-to-review files (slimmed `CLAUDE.md` + one file per extracted domain
   + any hook config).
6. **Verdict** — state honestly whether it's worth it. A no-op "leave it" is a valid,
   useful result, not a failure: near-done or rarely-touched projects may not repay the
   migration plus the ongoing "where does this rule live?" overhead.

## Classify on two axes

Type and scope are **orthogonal** — every rule has both. Type doesn't decide location;
**scope does**. A flat single-bucket sort mis-files things.

**Axis 1 — TYPE (what kind of content):**

| Type | Example |
|---|---|
| Instruction | "Use conventional commits", "prefer X pattern" |
| Guardrail | "Don't re-introduce X — it caused regression Y" |
| Procedural | Step-by-step how-to (deploy, add content) |
| Reference / Example | Snippets, exact values, config samples |
| Knowledge | Background facts about the domain / architecture |

**Axis 2 — SCOPE (drives placement):** Universal · Domain (task-type) · Domain
(directory) · Sacred invariant · Dead/stale. One *Guardrail* can be Universal (keep
static), Domain (into that domain's skill), or Sacred (enforce with a hook) — always
place on both axes.

## Placement

| Where it lives | Best for |
|---|---|
| `CLAUDE.md` (static) | Universal, every-session content |
| Skill `description` | Domain task-types spanning dirs |
| Skill `paths:` glob | Domain tied to specific file types |
| Nested `CLAUDE.md` | Domain that is a folder |
| `PreToolUse` hook | Sacred invariants, hard stops (can block) |
| `PostToolUse` hook | Reminders on specific file types (injects context) |
| Delete / archive | Stale / resolved content |

Rules of thumb the table can't hold:

- **Concrete read:** "material/CSS work" spanning many files → skill + `paths:` glob;
  `services/pihole/` → nested `CLAUDE.md`.
- **Routing table in `CLAUDE.md`?** Only to point at **non-skill** sub-files (nested
  `CLAUDE.md` / READMEs) that have no `description` and can't self-route. Never add a row
  for a skill — its description already routes, and a second source of truth drifts.
- **Don't over-split.** Create a skill only when the domain is genuinely separable *and*
  low-hit-rate. Below ~10–15 lines, the frontmatter plus "which place is this rule in?"
  overhead outweighs the content — leave it static.

## Guardrails are sacred

Anti-regression rules ("don't do X, it broke Y") are the highest-value, lowest-token
content in the file — they exist because the agent *will* repeat the mistake without them.

- **Rules capture decisions, not current state.** A guardrail records a *rejected
  alternative + why*, or a true invariant. A bare current-state fact ("box A is blue") is
  not one — the code already says it, and it rots the moment the value changes, then
  silently fights the change. Leave it at its source of truth; don't copy it into a rule.
- **Never silently drop one.** Every "don't do X" line in the original must reappear in
  the output — moved, not deleted. No home found → keep it static and flag it.
- **A guardrail moves *with* its domain** — into that domain's skill.
- **For the truly critical ones, prefer a hook** (or `paths:` glob) over hoping a
  description match loads — guaranteed beats probabilistic.
- **When in doubt, keep it static.** A little redundant static context is far cheaper
  than a returning bug.

## Output

Present, in order:

1. **Read-back** — one line confirming what was read (file + sub-files).
2. **Verdict up front** — worth restructuring or leave it? One sentence, then the reasoning.
3. **Classification table** — each rule → type → scope → proposed location.
4. **What a typical session stops loading** — per moved domain, its rough hit-rate
   (high/med/low) and what leaves always-on context. Frame as attention/confusion
   reduction; a token delta is a footnote, not the headline.
5. **Draft files** — full contents of the slimmed `CLAUDE.md` and each new skill / nested
   file / hook, ready to paste. Each extracted file is **self-contained** (its domain's
   full briefing, including that domain's guardrails). Flag every guardrail's new home.
6. **Apply steps** — the exact file operations. **Do not perform them** — this skill
   proposes; the user reviews and applies.
