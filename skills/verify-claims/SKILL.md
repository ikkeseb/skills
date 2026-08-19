---
name: verify-claims
description: "Audit factual claims in prose against traceable sources and classify each as verified, unverified, or contradicted. Checks written assertions, not software behavior."
disable-model-invocation: true
---

# verify-claims

Audit exercise, not template fill. The failure mode is dressing up "I think so" with confident-looking citations — a verified-looking table that papers over guesses.

## What counts as a claim

Declarative assertions about the world — true-or-false-independent-of-opinion. Names, numbers, quotes, attributions, "X does Y", "the API is called Z", "the file lives at P".

Exclude: opinions ("this is simpler"), recommendations, questions, hypotheses already flagged uncertain.

## Modes

- No argument → claims in the assistant's most recent message
- Path argument → claims in that file or directory

If the path doesn't exist or can't be read, say so and stop. If the target yields no claims, say so in one line — no table.

## Process

First split the target into the smallest independently verifiable claims. A
sentence that asserts multiple facts becomes multiple rows; one supported clause
must not make an unsupported neighbor look verified. Done when every row stands
or falls on exactly one fact.

For each atomic claim, try sources in order:

1. **Workspace files** — cite as `file:line`
2. **Session evidence** — tool output, fetches, or doc lookups already done this session, or a cheap side-effect-free check run now
3. **External** — web search, documentation lookup (e.g. a docs MCP like context7), or page fetch with whatever tools the session has. Default budget: one lookup per claim. User can lift it ("search broadly", "don't spare lookups").

When tiers conflict, the source closer to the thing wins — the artifact itself
over prose about it, vendor or primary material over third-party — and the note
names the conflict.

Classify each claim **as worded**:

- ✅ **verified** — explicitly supported by a source in a position to know: the artifact itself, primary material, or the vendor's documentation. A match found only on an aggregator or blog is ❓ with the reference in the note.
- ❓ **unverified** — no adequate source found after the above, or the wording is too ambiguous to check (an undefined term like "fastest" or "public") — name the gap in the note
- ❌ **contradicted** — a source affirmatively disagrees, including with the claim's precision: right idea but wrong number, date, or scope is ❌ with the accurate version in the note

A negative or universal claim ("nothing references X", "all Y do Z") is ✅ only
when the source covers the full asserted scope; failing to find a counterexample
is not coverage.

❓ unverified is the honest answer when the support is "I remember reading it
somewhere". Your own recent output gets the same burden of proof as a stranger's
text — being its author is not a source.

## Special cases

- **Session facts** ("I created X", "I ran Y", "the test passed") → verify against
  the visible session tool history and the resulting artifact or repository state.
  When the claim implies a checkable artifact (a file, a commit, a test result),
  check it before settling on any status — an incomplete history never excuses
  skipping the artifact. A cheap, side-effect-free check may be re-run now: it
  settles current state, not whether the earlier action happened. Never re-run
  expensive or state-changing commands to settle a claim — leave it ❓. Use
  ❌ contradicted only when evidence affirmatively disagrees. If history may be
  compacted, truncated, inherited, or otherwise incomplete and no artifact can
  decide it, an absent call is ❓ unverified — absence from an incomplete record
  is not proof that the action never happened.
- **Predictions / estimates** ("this will take 2h", "Y will break under load") → list in a short `[N/A — predictive]` block after the retract list, not inside the table.
- **Tautologies** — restatements of the user's own input in this conversation (the path they just typed, the file they pointed at) → omit. The same fact asserted independently by the audited text is a claim.

## Output

Three parts, in order:

**1. Tally line** — one bold line, dot-separated counts so the user reads the shape at a glance:

> **5 verified · 2 unverified · 1 contradicted**

Add a single *coverage line* directly below it only when it changes how ❓
reads: an evidence tier was unavailable (e.g. no network access, so external
claims could not be checked), the lookup budget ran out, or the target was a
directory (name the files audited and anything scoped out).

**2. Table** — emoji as the status column, plain prose in the others:

| | claim | source | note |
|---|---|---|---|
| ✅ | "the API is called X" | `src/api.ts:42` | direct match |
| ❓ | "X is the fastest framework" | — | "fastest" undefined — no benchmark to check against |
| ❌ | "released in 2024" | [Vendor release notes § v2.0](https://vendor.example/releases/v2) | docs say 2023 |

Quote claims naturally. Every source needs a precise locator: `path:line` for a
workspace file; the command or named tool call plus its relevant result for
session evidence; or a direct page title and URL (with section/anchor when
available) for external material. "websearch", "vendor docs", and a bare tool
name are not sources. The `note` column is for the *why* behind the
classification, in human language.

**3. Retract list** — one section below the table, only ❓ and ❌ rows. Quote the original sentence and say plainly what's wrong or missing. No automatic rewrites — the user decides what to strike or qualify.

Don't add extra headers, preambles, or summary paragraphs. The three parts above — plus the coverage line and the `[N/A — predictive]` block when they apply — are the whole output.

## Large targets

If the target is plainly larger than one useful audit (rough threshold: ~30
claims — judge from its size before splitting everything), stop and ask which
section or theme to scope to. A 100-row table no one reads is worse than no
audit. Unattended, with no one to ask: audit the most consequential section and
name the cut in the coverage line.
