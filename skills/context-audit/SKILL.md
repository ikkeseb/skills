---
name: context-audit
description: "Audit how a project's instructions and context load across harnesses — CLAUDE.md, AGENTS.md, skills, nested files, hooks — and how its document skeleton routes each truth to one owner. Analysis only, ending in an honest worth-it verdict. Not for mechanical AGENTS.md conversion (agents-md-convert)."
---

# Context Audit

Treat this as an attention audit, not a line-count diet. Splitting a lean file into
unreachable indirection is a regression.

## Target shape

Judge against this default: always-loaded files form a minimal skeleton — the
project's general rules plus a routing table — and every other truth lives in
exactly one on-demand owner the project has earned, not a template file list. The
environment (code, config, directory layout, `--help` output) owns what it can
show; a doc restating it is a cache. Slim never at the cost of reach: a mandatory
rule keeps a deterministic path into context. A repo that deviates deliberately
wins — flag the deviation once and audit within its convention.

## Process

Two phases. Phase 1 ends in a verdict the user can accept or redirect in one reading;
phase 2 runs only after the user has chosen a direction.

1. **Read** the complete instruction stack (see Loading contract). Done when every
   canonical file, adapter, parent/global file, and required file has been read.
2. **Map** the folder structure, domains, target harnesses, and effective loading policy.
   Note skeleton gaps against Target shape: a truth with no owner, two documents owning
   one truth, a document the routing never reaches. Done when the harness list, its
   evidence, each policy, and any skeleton gaps are stated or marked unknown.
3. **Classify** each rule on type and scope, then mark it mandatory or optional and flag
   it (see Classify). Done when every live rule carries type, scope, flags, and
   mandatory/optional.
4. **Place** each rule in the cheapest location that preserves its required reach (see
   Placement). Done when every moved rule has a destination and a reach-after-move.
5. **Verdict** against the worth-it test. A no-op is a useful result. Deliver phase 1 as
   specified under Output and stop. Done when the user has accepted, narrowed, or
   rejected a direction.
6. **Draft**, only for the accepted direction: ready-to-review canonical instructions,
   adapters, nested files, skills, and hook configuration (Output items 5–6). Every
   environment fact a draft asserts (a test exists, a hook is wired, a script does X) is
   proven by running the lookup in this session, not by reading about it; a suite the
   draft calls the verifier has been run, since a stale suite is the contradiction the
   draft is about to cite as truth. Done when every moved rule appears in a draft, every
   guardrail's new home is flagged, and every asserted environment fact was proven or
   marked unproven.

## Loading contract

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

Any extraction the audit would propose must also pass the write-back test under
Placement; if nothing does, the verdict is likely leave-it-alone.

A repo with no instruction files at all is not an audit target. Say so and offer a
bootstrap proposal instead of a restructuring.

If the file is already lean and mostly relevant every session, **say so and stop**.
Splitting adds indirection for no attention gain. Raw line count is a weak proxy: a
130-line file that's fully relevant is fine; an 80-line file that's 70% irrelevant is
not. (Past ~120 lines is *worth a look*, never automatically guilty. Any number is a
nudge, not a law.)

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
(directory). Flags ride alongside scope without replacing it; each names its
disposition:

- **sacred** — a guardrail whose loss causes regressions (see Guardrails).
- **dead/stale** — no live rule; a deletion candidate whatever its scope: no further
  classification needed, its proposed location is delete/archive.
- **weak pointer** — a line whose job is to make the agent reach another file, but
  whose wording fails to state what the material is or omits a distinct branch that
  should trigger reading it; sharpen the wording before considering inlining.
- **environment cache** — a line restating what `package.json` scripts, config files,
  the directory layout or `--help` already say; keep only what the agent cannot find
  by looking: the unwritten convention, the reason behind a choice, the gotcha no
  config confesses.
- **contradiction** — a fact two live documents state differently (one says a hook is
  unwired, another says live); find the deployed truth (settings, config, the script
  itself), name one owner for that fact, and align every other statement to a pointer.
- **frozen enumeration** — a present-tense count, list or measurement ("the four
  routes", "all 17 skills") that froze at write time and lies at the first change to
  what it counts; rewrite as a derivation pointer to its source, or as a dated
  measurement.
- **evidence-laden** — a kept rule still carrying the history that earned it (dates,
  quotes, incident stats); strip the rule bare and leave the evidence to the owning
  document or git history.
- **no-op** — a sentence the agent already obeys by default, paying load to say
  nothing; delete the whole sentence rather than trim it.

A live rule's required reach still determines whether it stays static, moves to
verified nested instructions, or becomes an optional skill procedure with added
enforcement.

## Placement

| Where it lives | Best for | Reach condition |
|---|---|---|
| Canonical root instructions | Universal or mandatory cross-directory rules | Loaded by every target harness |
| Harness adapter | Import/pointer to the canonical source | Contains no duplicate policy |
| Nested instructions | Mandatory directory-scoped rules | Verified for every target harness |
| Skill body | Optional domain procedure | Explicit invocation is acceptable or implicit loading is proven, and the write-back test passes |
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
- **Write-back test.** Extracted surfaces get read but not written back to: in field
  measurement, always-on files kept receiving content updates while a routed-in skill
  body received none — new knowledge lands on whichever surface sits in the working
  loop. Recommend extraction only when the content is *documented* stable (few or no
  semantic changes over the relevant history; durable boundaries, rare failure modes) or
  when updates already flow through a mechanical workflow the document sits in. Unknown
  stability keeps the content on the living surface. Auto-loading (a `paths:` glob)
  guarantees reading, not write-back, and does not qualify; neither does a planned
  changelog convention or periodic staleness audit until that loop is proven. Accepted
  trade: stable content stays always-loaded when stability can't be documented —
  cheaper than guidance that silently stops matching practice.
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
  not one: it is an environment cache (see Classify) that rots the moment the value
  changes, then silently fights the change. Leave it at its source of truth.
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
2. **Verdict up front:** worth restructuring or leave it? One sentence, then the
   reasoning, naming which budget the proposal spends: placement (what moves), prose
   (what tightens), or both — they are different passes and a full audit runs both.
3. **Classification table:** grouped by domain, one row per rule: type → scope (plus
   flags) → mandatory/optional → current reach → proposed location → reach after the
   move. Rules whose every field is identical may share one row; a sacred rule never
   shares.
4. **What a typical session stops loading:** per moved domain, its rough hit-rate
   (high/med/low) and what leaves always-on context. Frame as attention/confusion
   reduction; a token delta is a footnote, not the headline.
Items 1–4 are phase 1. Stop there until the user has chosen a direction. On a
leave-it-alone verdict, deliver items 1–2 plus any dead/stale deletions, contradiction
repairs, and weak-pointer or environment-cache rewrites worth naming, and stop.

5. **Draft files:** full contents of the canonical instructions, adapters, and each new
   skill, nested file, or hook, for the accepted direction only. Keep each extracted
   domain self-contained and flag every guardrail's new home. Do not invent unsupported
   cross-harness parity.
6. **Apply steps:** the exact file operations, including any the dedup rule names on
   user-global files. **Do not perform them.** This skill proposes; the user reviews
   and applies.
