---
name: context-audit
description: >-
  Audit a project's instruction and context architecture, including CLAUDE.md,
  AGENTS.md, skills, nested files, and hooks. Analysis-only: classify the rules,
  preserve their effective reach across the target harnesses, draft a leaner
  structure, and give an honest worth-it verdict for the user to apply by hand.
---

# Context Audit

Treat this as an attention audit, not a line-count diet. Splitting a lean file into
unreachable indirection is a regression.

## Establish the loading contract first

Do not classify or move a rule until its current and proposed reach are known:

1. Identify every target harness and its canonical instruction file. Read `CLAUDE.md`,
   `AGENTS.md`, import adapters, parent/global instructions, and every file they require.
2. Determine each harness's effective skill invocation policy from the installed skill
   metadata and user/project settings. Check, rather than infer, whether skills are
   model-invoked or explicit/name-only. In Codex, inspect
   `policy.allow_implicit_invocation` where present. In Claude Code, inspect the effective
   skill settings and frontmatter. Do not change invocation policy as part of the audit.
3. Record which mechanisms each target harness actually supports. If policy or support
   cannot be proven, treat skills as explicit and use the least-capable shared contract.
4. For a shared project, identify one canonical source plus any harness adapters. Do not
   duplicate the same rule merely to serve both harnesses.

Apply these reachability rules:

- **Implicit/model-routed skill:** its description may route an optional domain procedure.
- **Explicit/name-only skill:** only deliberate invocation loads its body. Its description
  aids discovery; it does not deliver mandatory context.
- **Claude Code `paths:`:** valid skill frontmatter can activate file-scoped guidance when
  matching files are touched. Preserve and use it where the target is Claude Code and the
  glob covers the domain, but do not make it the sole home of a cross-harness rule.
- **Unknown or mixed policy:** assume explicit. Keep mandatory rules on a deterministic
  instruction surface that every target harness loads.

Mandatory always-on rules stay in canonical root instructions. Mandatory directory rules
may move to nested instructions only after verifying that every target harness loads them.
Optional procedures may move to skills. Claude Code hooks may enforce critical operations,
but they supplement rather than replace cross-harness instructions.

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

1. **Read** the complete instruction stack identified above.
2. **Map** the folder structure, domains, target harnesses, and effective loading policy.
3. **Classify** each rule on type and scope, then mark it mandatory or optional.
4. **Place** each rule in the cheapest location that preserves its required reach.
5. **Draft** ready-to-review canonical instructions, adapters, nested files, skills, and
   hook configuration as applicable.
6. **Verdict** against the worth-it test above. A no-op is a useful result.

## Classify on two axes

Type and scope are **orthogonal** — every rule has both. Scope narrows the candidate
locations; mandatory versus optional reach selects among them. A flat sort mis-files
things.

**Axis 1 — TYPE (what kind of content):**

| Type | Example |
|---|---|
| Instruction | "Use conventional commits", "prefer X pattern" |
| Guardrail | "Don't re-introduce X — it caused regression Y" |
| Procedural | Step-by-step how-to (deploy, add content) |
| Reference / Example | Snippets, exact values, config samples |
| Knowledge | Background facts about the domain / architecture |

**Axis 2 — SCOPE (drives placement):** Universal · Domain (task-type) · Domain
(directory) · Sacred invariant · Dead/stale. One *Guardrail* can be Universal, Domain,
or Sacred. Its required reach still determines whether it stays static, moves to verified
nested instructions, or becomes an optional skill procedure with added enforcement.

## Placement

| Where it lives | Best for | Reach condition |
|---|---|---|
| Canonical root instructions | Universal or mandatory cross-directory rules | Loaded by every target harness |
| Harness adapter | Import/pointer to the canonical source | Contains no duplicate policy |
| Nested instructions | Mandatory directory-scoped rules | Verified for every target harness |
| Skill body | Optional domain procedure | Explicit invocation is acceptable, or implicit loading is proven |
| Claude Code skill `paths:` | File-scoped guidance | Claude Code target and complete glob coverage |
| Claude Code hook | Critical operation enforcement or reminders | Claude-specific; shared prose remains reachable elsewhere |
| Delete / archive | Stale or resolved content | No live rule or required history is lost |

Rules of thumb the table can't hold:

- **Concrete read:** optional CSS procedure in Claude Code may use a skill with a
  `paths:` glob; mandatory rules for `services/pihole/` may use verified nested
  instructions.
- **Routing pointer:** add one only when it is necessary to make required context
  reachable under the effective policy. Do not duplicate the rule itself. In an
  implicit setup a skill description may be sufficient; in an explicit setup it is not.
- **Project ownership:** keep project-specific rules in the project's supported
  instruction or skill locations, not in user-global context. Follow the repository's
  existing packaging convention instead of assuming a Claude-only directory.
- **Don't over-split.** Create a skill only when the domain is genuinely separable *and*
  low-hit-rate. Below ~10–15 lines, the frontmatter plus "which place is this rule in?"
  overhead outweighs the content — leave it static.
- **Dedup across always-on layers.** Audit the whole always-on stack as one surface —
  global `~/.claude/CLAUDE.md`, parent-directory files, the project file. A rule stated
  in two layers pays attention twice and drifts independently: keep it in the narrowest
  layer that covers its scope, delete the other copy.
- **Enforcement-superseded prose.** If a deterministic mechanism enforces a rule for
  every target harness, delete duplicate prose or shrink it to a one-line pointer. Keep
  prose where another harness still needs it or where it must steer work before a block.

## Guardrails are sacred

Anti-regression rules ("don't do X, it broke Y") are the highest-value, lowest-token
content in the file — they exist because the agent *will* repeat the mistake without them.

- **Rules capture decisions, not current state.** A guardrail records a *rejected
  alternative + why*, or a true invariant. A bare current-state fact ("box A is blue") is
  not one — the code already says it, and it rots the moment the value changes, then
  silently fights the change. Leave it at its source of truth; don't copy it into a rule.
- **Never silently drop one.** Every "don't do X" line in the original must reappear in
  the output — moved, not deleted. No home found → keep it static and flag it.
- **Keep a guardrail with its domain without weakening its reach.** Use a skill only
  when the guardrail is optional or invocation is guaranteed; otherwise use canonical
  or verified nested instructions.
- **For the truly critical ones, keep reachable instructions and add deterministic
  enforcement where the target harness supports it.** A hook or `paths:` glob must not
  silently remove the rule from another harness.
- **When in doubt, keep it static.** A little redundant static context is far cheaper
  than a returning bug.

## Output

Present, in order:

1. **Read-back** — list the instruction stack, target harnesses, and evidence for each
   effective invocation policy. Mark unknowns explicitly.
2. **Verdict up front** — worth restructuring or leave it? One sentence, then the reasoning.
3. **Classification table** — each rule → type → scope → mandatory/optional → current
   reach → proposed location → reach after the move.
4. **What a typical session stops loading** — per moved domain, its rough hit-rate
   (high/med/low) and what leaves always-on context. Frame as attention/confusion
   reduction; a token delta is a footnote, not the headline.
5. **Draft files** — full contents of the canonical instructions, adapters, and each new
   skill, nested file, or hook. Keep each extracted domain self-contained and flag every
   guardrail's new home. Do not invent unsupported cross-harness parity.
6. **Apply steps** — the exact file operations. **Do not perform them** — this skill
   proposes; the user reviews and applies.
