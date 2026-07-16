# Agent-agnostic skills repo — working plan

**Date:** 2026-07-16 · **Status:** open — spar on this in-repo (Claude Code
and/or Codex session) before executing anything.

## Goal

One repo serving both Claude Code and Codex CLI with minimal double
maintenance. Decide the fate of the separate `codex-skills` repo. This repo is
**public** — everything committed here must make sense to an outside reader
and must never reference private infrastructure.

## Current state (verified 2026-07-16)

- Layout: flat `skills/<name>/SKILL.md`; `.claude-plugin/` packaging exists on
  the published plugin path (publish-only — local consumption is via
  symlinks, never plugin-install, to avoid double-loading).
- Claude consumes via `~/.claude/skills/<name>` symlinks.
- Codex consumes only two skills via `~/.agents/skills/{verify-claims,pretty-pdf}`
  symlinks — both worked as-is (canary-verified: discovery, explicit + implicit
  invocation, reference files, symlink propagation; Claude-only frontmatter
  keys are inert in Codex).
- `codex-skills` (separate repo) holds one Codex-native port: `handoff`, which
  diverged hard in body (save path, invocation, fence, delete rules).
- Three skills are Claude-only **by design** and stay that way: `orchestrate`,
  `suggest-loop`, `context-audit` — their substance is Claude machinery;
  mistranslating a posture is worse than not porting it.

## Patterns worth stealing from mattpocock/skills

Inspected 2026-07-16 (github.com/mattpocock/skills). Each item lists what it
buys; none are adopted yet.

1. **Per-skill `agents/openai.yaml`** — Codex UI metadata
   (`interface.display_name`, `interface.short_description`) and, for
   user-invoked skills, `policy.allow_implicit_invocation: false` paired with
   Claude's `disable-model-invocation: true`. Buys: one repo carries both
   harnesses' metadata without touching skill bodies. Keep the pair in sync —
   a skill is user-invoked in both harnesses or neither.
2. **Invocation axis as a first-class convention** — every skill is either
   user-invoked (zero context load, the human is the index) or model-invoked
   (description pays context load every turn, so it earns hard pruning). His
   `.agents/invocation.md` documents the axis once; skills just comply.
3. **Promoted buckets + explicit plugin `skills` array** — `plugin.json` lists
   exactly the promoted set, so the published plugin ships a curated subset
   while drafts (`in-progress/`), personal, and deprecated skills stay in the
   repo but out of the package. Buys: solves "don't expose everything" on the
   Claude side with zero extra tooling. (His Codex side deliberately has NO
   plugin — an ADR documents why; distribution is symlinks only.)
4. **`scripts/link-skills.sh`** — one script (re)links every skill into both
   `~/.claude/skills` and `~/.agents/skills`. Buckets are repo organisation
   only; discovery always goes through the flat symlink layer, so nested
   directory layouts never depend on harness scanning behaviour.
5. **Root `.agents/` docs dir** — repo-level agent conventions (ADRs,
   invocation rules, docs-writing rules) live in a dotted dir that is NOT a
   reserved Claude component name. Buys: a home for "how this repo works"
   that both harnesses can be pointed at.
6. **`writing-great-skills` methodology** — predictability as the root
   virtue; checkable completion criteria per step; leading words; failure
   modes (no-op lines, sediment, sprawl, negation, premature completion,
   duplication). Worth adopting as the house editing standard regardless of
   structure decisions.
7. **Router skill** (his `ask-matt`) — one user-invoked skill that maps all
   user-reachable skills and when to reach for each, curing the cognitive
   load of many user-invoked skills. Contract: any skill add/rename/removal
   re-syncs the router, or the router lies.

Counter-note: his root `CLAUDE.md` is a full duplicate of `AGENTS.md`; the
one-line `@AGENTS.md` import adapter used elsewhere in this ecosystem is
strictly better (single source of truth) and should be kept.

## Open questions to spar on (in-repo, with Codex and/or Claude)

1. **Buckets or stay flat?** Eleven skills may not justify bucket dirs +
   per-bucket READMEs + docs mirroring. The plugin `skills` array and the
   link script work with a flat layout too. Don't cargo-cult the structure;
   steal the mechanisms.
2. **`agents/openai.yaml` wholesale or on-demand?** Wholesale = every skill
   is Codex-ready metadata-wise; on-demand = add it only when a skill is
   actually wanted in Codex (evidence-driven, matches how the two canaries
   went in). Related: the earlier idea of one big neutralization pass over
   all shared skills was re-scoped to on-demand — neutralize a body when a
   concrete skill is actually wanted Codex-side.
3. **Where does hard body divergence live?** `handoff` is the test case:
   in-body harness branches, a per-harness override file next to `SKILL.md`,
   or keep the separate `codex-skills` repo for exactly these. The Codex-side
   discovery and `openai.yaml` investigation has landed below and informs the
   recommendation.
4. **Curated plugin set** — adopt the explicit `skills` array in
   `plugin.json` (and validate with `claude plugin validate . --strict`)
   regardless of the other decisions? Cheap, no downside identified.
5. **A `link-skills.sh` equivalent** — replace manual symlinking; must handle
   both harness dirs and both machines (macOS + Windows junctions on PC).
6. **Claude-only-by-design skills** — under any new convention, mark them
   explicitly (README grouping or metadata) so nobody "fixes" them into
   Codex later.

### Recommended resolutions from sparring (2026-07-16)

1. **Stay flat.** Keep `skills/<name>/`; eleven skills plus the planned
   `agents-md-convert` do not repay bucket paths, per-bucket READMEs, or
   mirrored docs. Codex's recursive discovery keeps buckets available later
   without making them useful now.
2. **Add `agents/openai.yaml` on demand.** Add it only when a skill is
   deliberately admitted to the Codex-supported set, and use its presence as
   the positive machine-readable marker consumed by the linker. Neutralise the
   body at the same admission point rather than promising untested support.
3. **Keep hard divergence in one body when the branch is small.** For
   `handoff`, start from the stricter Codex body, make invocation and durable
   guidance neutral, and branch inline only for the save root
   (`$CODEX_HOME`/`~/.codex` versus `~/.claude`). A pair of tiny adapter files
   would add a load-bearing router and extra reads without isolating enough
   logic to earn them; neither harness supports a magic override file.
4. **Adopt the explicit Claude plugin `skills` array.** It is the published
   Claude allowlist and should be validated with
   `claude plugin validate . --strict`. Update the current repo guidance at the
   same time: its claim that `plugin.json` carries no list becomes stale.
5. **Build a cross-platform `scripts/link-skills.py`.** Make it idempotent,
   support `--dry-run` and `--check`, refuse to replace real directories, use
   directory symlinks on POSIX, and use junctions on Windows. Link the Claude
   allowlist to `~/.claude/skills`; link only skills carrying
   `agents/openai.yaml` to `~/.agents/skills`.
6. **Mark Claude-only status explicitly in README, backed by linker
   behaviour.** Group `orchestrate`, `suggest-loop`, and `context-audit` under
   "Claude-only by design" with a one-line reason for each; do not add custom
   inert frontmatter. Their deliberate lack of `agents/openai.yaml` keeps them
   out of the Codex link set.

## Planned new skill: `agents-md-convert`

To be built in this repo once the structure above is decided (it should be
born in the chosen format, as its own first test case).

- **Purpose:** run inside any repo to convert it to the AGENTS.md-canonical
  convention (`AGENTS.md` canonical, one-line `CLAUDE.md` = `@AGENTS.md`
  import), or to check an existing conversion.
- **User-invoked** (deliberate one-shot wiring op; zero context load).
- **Flow:** preflight (repo root, clean git status, detect current state →
  convert vs check mode) → `git mv CLAUDE.md AGENTS.md` + "Instruction
  source" section + one-line `CLAUDE.md` → wording pass over harness-isms
  (slash-command references get a file-path fallback; hook-dependent
  behaviour gets a manual fallback) → nested scopes get the same pair and
  the parent tells Codex to read them → verify with a fresh `claude -p` and
  `codex exec` one-liner (both must report AGENTS.md as canonical) →
  optional final `codex exec` review of the converted file for
  Codex-side gaps.
- Commit/push stays with the human (repo conventions vary).

## Codex investigation verdict (landed 2026-07-16, gpt-5.6 via codex 0.144.5)

**Recommendation: one canonical repo (this one), flat layout, per-skill Codex
allowlist via a linker script, and one shared `SKILL.md` with a small inline
harness branch only where mechanics truly differ. Retire `codex-skills` after
migrating `handoff` (archive it as a shell with a README pointer — no active
body).**
Two-repos-with-sync was rejected as a permanent design: submodules/mirrors
solve distribution, not semantic drift.

### Observed (evidence, not speculation)

- **Nested discovery works.** An isolated Codex 0.144.5 `skills/list` probe
  added this repo's root as a standalone skill root and found all eleven
  nested `skills/<name>/SKILL.md` files. The scanner is recursive/breadth-first
  under each skill root: exact case-sensitive `SKILL.md` match, max 6 levels
  deep, 2 000 dirs per root, skips dot-dirs, follows directory symlinks,
  canonicalises + dedupes. Verified against the open-source loader
  (`codex-rs/core-skills/src/loader.rs`) and matching symbols in the
  installed 0.144.5 binary. Bucket layouts would work — but see the flat
  recommendation above (11 skills don't justify the churn).
- **Critical consequence:** one symlink of the whole `skills/` dir into
  `~/.agents/skills` would load EVERY skill, including the three
  Claude-only-by-design ones. Per-skill linking is load-bearing, not
  cosmetic.
- **Namespace surprise:** Codex recognises `.claude-plugin/plugin.json` when
  computing namespaces and canonicalises symlinks back to the repo, so
  current skills surface as `ikkeseb-skills:pretty-pdf` etc. Whether bare
  `$verify-claims` still works as an alias on 0.144.5 was NOT live-tested —
  canary that before documenting invocation forms.
- **`agents/openai.yaml` semantics:** `interface.*` is picker/UI metadata; the
  isolated runtime probe surfaced `display_name`, `short_description`, and
  `default_prompt` through `skills/list` (desktop visual rendering was not
  tested).
  `policy.allow_implicit_invocation: false` removes the skill from the
  model-visible list (observed for `handoff` this session); explicit
  invocation not retested. `dependencies.tools` parsing confirmed in source;
  end-to-end not tested. `policy.products` exists in source but is
  undocumented — do not build on it. Invalid `openai.yaml` is fail-open
  (ignored; the `SKILL.md` survives).
- **`.claude-plugin/` does not block Codex discovery.** But it is not a
  Codex plugin package either; official Codex distribution would need
  `.codex-plugin/plugin.json` with a single `skills` root — pointless here
  while `skills/` deliberately contains Claude-only skills. Don't add it.

### Body portability classification

| Skill | Verdict |
|---|---|
| `pretty-pdf` | Portable, canary-verified |
| `verify-claims` | Works; should swap `websearch/context7/webfetch` for generic tool terms |
| `drawio`, `excalidraw`, `afk`, `full-send`, `max-effort` | Portable on-demand with moderate body edits (generic tool names, environment branch, agent semantics) |
| `handoff` | One shared body + one small inline save-root branch (see below) |
| `context-audit`, `orchestrate`, `suggest-loop` | Claude-only by design — never link to Codex. Not metadata problems: their substance is Claude machinery (context/hook architecture; Fable+Workflow+per-agent model/effort, which Codex subagents lack; `/loop`+Monitor, and Codex CLI has no scheduled-task surface) |

### `handoff` merge shape

```text
skills/handoff/
├── SKILL.md              # shared workflow + inline save-root branch
└── agents/openai.yaml    # Codex UI/invocation policy
```

Use the stricter Codex body as the shared baseline (truth/verification
requirements, cleanup/collision/failure rules, and exact output fence).
Invocation policy belongs in frontmatter plus `agents/openai.yaml`; durable
guidance can say "repository guidance"; only save-root selection needs an
inline Claude Code versus Codex branch. Two adapter files would cost an extra
load-bearing router and reference read for only a few lines of real variance.

### Recommended change list for this repo

1. Add canonical `AGENTS.md`; keep `CLAUDE.md` as the import adapter.
2. Root `.agents/` for invocation convention + ADRs.
3. Keep flat `skills/<name>` layout.
4. Curate `.claude-plugin/plugin.json`'s published skill list explicitly.
5. `agents/openai.yaml` = the repo's "Codex-supported" marker; never on the
   three Claude-only skills. Always pair `disable-model-invocation: true`
   with `policy.allow_implicit_invocation: false`, or omit both.
6. Committed linker script: promoted skills → `~/.claude/skills`; only dirs
   with `agents/openai.yaml` → `~/.agents/skills`; handles macOS symlinks +
   Windows junctions.
7. Refactor `handoff` to one shared body with the inline save-root branch; then move
   `~/.agents/skills/handoff` to this repo and archive `codex-skills`.
8. Neutralise other bodies only when actually wanted on Codex — no
   speculative wholesale port.
9. CI/smoke checks: frontmatter, the yaml pairing, `claude plugin validate
   . --strict`, Codex discovery, both invocation forms.

## Decisions (2026-07-16, repo owner, post-spar)

- **Distribution to consumers is plugin-based for both harnesses.** Claude
  side ships via the marketplace plugin as today; the Codex-supported skills
  in this repo should eventually ship as a Codex plugin too. Anyone else
  installs via marketplace / gh install commands — never symlinks.
- **The linker script is parked** (open question 5). Manual symlinks are a
  single-person, per-machine concern for the repo owner only; not worth
  tooling until it becomes real friction. Same for deciding whether the
  owner's own consumption moves to plugin installs.
- **New load-bearing unknown: Codex plugin manifest semantics.**
  `.codex-plugin/plugin.json` reportedly takes a single `skills` root with no
  allowlist — which would ship Claude-only skills to Codex users. Verify
  (allowlist support? multiple roots? interaction with `openai.yaml` policy)
  before adopting Codex plugin distribution.
- **Migration scope now:** `orchestrate` and `suggest-loop` stay out of any
  Codex migration — `orchestrate` would need deep modding (Codex model
  routing) and its intended behaviour under Codex is unknown. `context-audit`
  remains Claude-only by design, as already classified.
- **`~/codex-skills` confirmed:** holds only the one-shot `handoff` port
  (4 commits, nothing else). Retire per the recommendation once `handoff`
  is merged here and canary-verified.

### Verification gaps

The isolated Codex 0.144.5 `skills/list` test now passes for recursive repo-root
discovery, namespace qualification, and `openai.yaml` interface metadata. Exact
0.144.5 tag source was not fetched (the detailed scanner limits come from the
installed binary plus current main-branch source); bare `$name` alias behaviour
under plugin namespacing, explicit invocation with the merged `handoff`, desktop
UI rendering, dependency prompting, and Windows junction creation remain
untested.
