---
name: verify-claims
disable-model-invocation: true
description: Audit factual claims in prose for traceable sources — produces a classified table flagging which assertions have sources and which are unverified. Use when the user asks to verify claims, fact-check, source-audit, or "check what you just said". Different from /verify (which runs the app to confirm code works) — this checks whether assertions in writing have backing sources, not whether software behaves. Do NOT auto-invoke; explicit user request only.
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

For each claim, try sources in order:

1. **Workspace files** — cite as `file:line`
2. **Session context** — tool output, fetches, or doc lookups already done this session
3. **External** — web search, documentation lookup (e.g. a docs MCP like context7), or page fetch with whatever tools the session has. Default budget: one lookup per claim. User can lift it ("search broadly", "don't spare lookups").

Classify each claim:

- ✅ **verified** — explicitly supported by the source
- ❓ **unverified** — no source found after the above
- ❌ **contradicted** — source disagrees

❓ unverified is the honest answer when the support is "I remember reading it somewhere". Don't promote a guess to ✅ verified to make the table look clean.

## Special cases

- **Session facts** ("I created X", "I ran Y", "the test passed") → verify against this session's tool-call history. ❌ contradicted if the call never happened. This is the most common confabulation mode — don't skip it.
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
| ❌ | "released in 2024" | webfetch (vendor docs) | docs say 2023 |

Quote claims naturally. Sources should be specific (`file:line`, tool + what was fetched) — not just "websearch". The `note` column is for the *why* behind the classification, in human language.

**3. Retract list** — one section below the table, only ❓ and ❌ rows. Quote the original sentence and say plainly what's wrong or missing. No automatic rewrites — the user decides what to strike or qualify.

Don't add extra headers, preambles, or summary paragraphs. The three parts above — plus the `[N/A — predictive]` block when predictions exist — are the whole output.

## Large targets

If the target has more claims than is useful to audit at once (rough threshold: ~30), stop and ask which section or theme to scope to before generating the table. A 100-row table no one reads is worse than no audit.
