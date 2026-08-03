---
name: verify-claims
description: Audit factual claims in prose against traceable sources and classify each as verified, unverified, or contradicted. Unlike the verify skill (which runs the app to confirm code works), this checks written assertions, not software behavior.
---

# verify-claims

Audit exercise, not template fill. The failure mode is dressing up "I think so" with confident-looking citations — a verified-looking table that papers over guesses.

## What counts as a claim

Declarative assertions about the world — true-or-false-independent-of-opinion. Names, numbers, quotes, attributions, "X does Y", "the API is called Z", "the file lives at P".

Exclude: opinions ("this is simpler"), recommendations, questions, hypotheses already flagged uncertain.

## Modes

- No argument → claims in the assistant's most recent message
- Path argument → claims in that file or directory

## Process

First split the target into the smallest independently verifiable claims. A
sentence that asserts multiple facts becomes multiple rows; one supported clause
must not make an unsupported neighbor look verified.

For each atomic claim, try sources in order:

1. **Workspace files** — cite as `file:line`
2. **Session context** — tool output, fetches, or doc lookups already done this session
3. **External** — web search, documentation lookup (e.g. a docs MCP like context7), or page fetch with whatever tools the session has. Default budget: one lookup per claim. User can lift it ("search broadly", "don't spare lookups").

Classify each claim:

- ✅ **verified** — explicitly supported by the source
- ❓ **unverified** — no source found after the above
- ❌ **contradicted** — source disagrees

❓ unverified is the honest answer when the support is "I remember reading it somewhere". Don't promote a guess to ✅ verified to make the table look clean.

## Special cases

- **Session facts** ("I created X", "I ran Y", "the test passed") → verify against
  the visible session tool history and, when cheap, the resulting artifact or
  repository state. Use ❌ contradicted only when complete evidence affirmatively
  disagrees. If history may be compacted, truncated, inherited, or otherwise
  incomplete, an absent call is ❓ unverified — absence from an incomplete record
  is not proof that the action never happened.
- **Predictions / estimates** ("this will take 2h", "Y will break under load") → list in a short `[N/A — predictive]` block after the retract list, not inside the table.
- **Tautologies** (path the user just named, file they pointed at) → omit.

## Output

Optimize for human scanability. Three parts, in order:

**1. Tally line** — one bold line, dot-separated counts so the user reads the shape at a glance:

> **5 verified · 2 unverified · 1 contradicted**

**2. Table** — emoji as the status column, plain prose in the others:

| | claim | source | note |
|---|---|---|---|
| ✅ | "the API is called X" | `src/api.ts:42` | direct match |
| ❓ | "X is the fastest framework" | — | no benchmark in workspace, no lookup match |
| ❌ | "released in 2024" | [Vendor release notes § v2.0](https://vendor.example/releases/v2) | docs say 2023 |

Quote claims naturally. Every source needs a precise locator: `path:line` for a
workspace file; the command or named tool call plus its relevant result for
session evidence; or a direct page title and URL (with section/anchor when
available) for external material. "websearch", "vendor docs", and a bare tool
name are not sources. The `note` column is for the *why* behind the
classification, in human language.

**3. Retract list** — one section below the table, only ❓ and ❌ rows. Quote the original sentence and say plainly what's wrong or missing. No automatic rewrites — the user decides what to strike or qualify.

Don't add extra headers, preambles, or summary paragraphs. The three parts above — plus the `[N/A — predictive]` block when predictions exist — are the whole output.

## Large targets

If the target has more claims than is useful to audit at once (rough threshold: ~30), stop and ask which section or theme to scope to before generating the table. A 100-row table no one reads is worse than no audit.
