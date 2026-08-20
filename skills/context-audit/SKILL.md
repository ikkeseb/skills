---
name: context-audit
description: "Audit how a project's instructions and context load across harnesses: CLAUDE.md, AGENTS.md, skills, nested files, hooks. Analysis only, ending in an honest worth-it verdict. Not for mechanical AGENTS.md conversion (agents-md-convert)."
---

# Context Audit

Treat this as an attention audit, not a line-count diet. Splitting a lean file into
unreachable indirection is a regression.

## Establish the loading contract first

Do not classify or move a rule until its current and proposed reach are known:

1. Identify every target harness and its canonical instruction file. The target-harness
   set comes from evidence, not assumption: harness artifacts present in the repo
   (`CLAUDE.md`, `AGENTS.md`, import adapters, harness manifests, hooks or settings)
   plus any harness the user names. No artifact and no mention means not a target;
   ambiguous means ask. Read the canonical files, adapters, parent/global instructions, and
   every file they require. Done when the harness list and its evidence can be stated in
   the read-back.
2. Determine each harness's effective skill invocation policy from the installed skill
   metadata and user/project settings. Check, rather than infer, whether skills are
   model-invoked or explicit/name-only. In Codex, inspect
   `policy.allow_implicit_invocation` where present. In Claude Code, inspect skill
   frontmatter (`disable-model-invocation`, `user-invocable`) and effective settings
   (`skillOverrides`, noting they do not affect plugin-shipped skills). Do not change
   invocation policy as part of the audit. Done when each harness's policy is proven or
   marked unknown.
3. Record which mechanisms each target harness actually supports; this support matrix
   belongs in the read-back. If policy or support cannot be proven, treat skills as
   explicit and use the least-capable shared contract.
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
Optional procedures may move to skills.

## When to run, and when to stop

Run a full audit only when it pays back. Gauge two things:

- **Irrelevance fraction:** what share of the file a *typical* session never uses.
- **Session-hit-rate per domain:** rate it high/med/low from observable proxies:
  git-log touch frequency of the domain's files, the share of the tree it covers, any
  session history the user offers. A cluster touched in few sessions (roughly ~5%) is a
  great move-out candidate; one touched in most (~60%) is not. State the proxy used. If
  none is available, mark the rate unknown and say the verdict is weakened by it.

A repo with no instruction files at all is not an audit target. Say so and offer a
bootstrap proposal instead of a restructuring.

If the file is already lean and mostly relevant every session, **say so and stop**.
Splitting adds indirection for no attention gain. Raw line count is a weak proxy: a
130-line file that's fully relevant is fine; an 80-line file that's 70% irrelevant is
not. (Past ~120 lines is *worth a look*, never automatically guilty. Any number is a
nudge, not a law.)

## Process

1. **Read** the complete instruction stack identified above.
2. **Map** the folder structure, domains, target harnesses, and effective loading policy.
3. **Classify** each rule on type and scope, then mark it mandatory or optional. Done
   when every live rule carries type, scope, flags, and mandatory/optional.
4. **Place** each rule in the cheapest location that preserves its required reach.
5. **Draft** ready-to-review canonical instructions, adapters, nested files, skills, and
   hook configuration as applicable. Done when every moved rule appears in a draft.
6. **Verdict** against the worth-it test above. A no-op is a useful result.

## Classify on two axes

Type and scope are **orthogonal**: every rule has both. Scope narrows the candidate
locations; mandatory versus optional reach selects among them.

**Axis 1, TYPE (what kind of content):**

| Type | Example |
|---|---|
| Instruction | "Use conventional commits", "prefer X pattern" |
| Guardrail | "Don't re-introduce X, it caused regression Y" |
| Procedural | Step-by-step how-to (deploy, add content) |
| Reference / Example | Snippets, exact values, config samples |
| Knowledge | Background facts about the domain / architecture |

**Axis 2, SCOPE (drives placement):** Universal · Domain (task-type) · Domain
(directory). Two flags ride alongside scope without replacing it: **sacred** (a
guardrail whose loss causes regressions, see Guardrails) and **dead/stale** (no live
rule; a deletion candidate whatever its scope: it needs no further classification, its
proposed location is delete/archive). A live rule's required reach still determines
whether it stays static, moves to verified nested instructions, or becomes an optional
skill procedure with added enforcement.

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
  overhead outweighs the content. Leave it static.
- **Dedup across always-on layers.** Audit the whole always-on stack as one surface:
  global `~/.claude/CLAUDE.md`, parent-directory files, the project file. A rule stated
  in two layers pays attention twice and drifts independently. Keep it in the narrowest
  layer that covers its scope, delete the other copy.
- **Enforcement-superseded prose.** If a deterministic mechanism enforces a
  *non-critical* rule for every target harness, delete duplicate prose or shrink it to a
  one-line pointer. Keep prose where another harness still needs it or where it must
  steer work before a block. Critical guardrails follow the Guardrails section instead:
  enforcement supplements their prose, never replaces it.

## Guardrails are sacred

Anti-regression rules ("don't do X, it broke Y") are the highest-value, lowest-token
content in the file. They exist because the agent *will* repeat the mistake without them.

- **Rules capture decisions, not current state.** A guardrail records a *rejected
  alternative + why*, or a true invariant. A bare current-state fact ("box A is blue") is
  not one: the code already says it, and it rots the moment the value changes, then
  silently fights the change. Leave it at its source of truth; don't copy it into a rule.
- **Never silently drop one.** Every "don't do X" line in the original must reappear in
  the output, moved rather than deleted. No home found means keep it static and flag it.
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

1. **Read-back:** list the instruction stack, the target harnesses with their evidence,
   the mechanism-support matrix, and evidence for each effective invocation policy. Mark
   unknowns explicitly, and flag broken or unreadable imports as defects.
2. **Verdict up front:** worth restructuring or leave it? One sentence, then the reasoning.
3. **Classification table:** each rule → type → scope (plus sacred/dead flags) →
   mandatory/optional → current reach → proposed location → reach after the move.
4. **What a typical session stops loading:** per moved domain, its rough hit-rate
   (high/med/low) and what leaves always-on context. Frame as attention/confusion
   reduction; a token delta is a footnote, not the headline.
5. **Draft files:** full contents of the canonical instructions, adapters, and each new
   skill, nested file, or hook. Keep each extracted domain self-contained and flag every
   guardrail's new home. Do not invent unsupported cross-harness parity.
6. **Apply steps:** the exact file operations, including any the dedup rule names on
   user-global files. **Do not perform them.** This skill proposes; the user reviews
   and applies.

On a leave-it-alone verdict, deliver items 1–2 plus any dead/stale deletions worth
naming, and stop. No draft files or apply steps for a structure that should not change.
