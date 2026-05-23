---
name: verify-claims
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
2. **Session context** — tool output, web-fetch, context7 already done this session
3. **External** — websearch / context7 / webfetch. Default budget: one lookup per claim. User can lift it ("search broadly", "don't spare lookups").

Classify each claim:

- `DIRECT` — explicitly supported by the source
- `UNVERIFIED` — no source found after the above
- `CONTRADICTED` — source disagrees

`UNVERIFIED` is the honest answer when the support is "I remember reading it somewhere". Don't promote a guess to `DIRECT` to make the table look clean.

## Special cases

- **Session facts** ("I created X", "I ran Y", "the test passed") → verify against this session's tool-call history. `CONTRADICTED` if the call never happened. This is the most common confabulation mode — don't skip it.
- **Predictions / estimates** ("this will take 2h", "Y will break under load") → `[N/A — predictive]`, listed below the table, not inside it.
- **Tautologies** (path the user just named, file they pointed at) → omit.

## Output

Markdown table in chat:

| claim | source | classification | note |

After the table, a short retract list: each `UNVERIFIED` and `CONTRADICTED` row, quoting the original sentence and the issue. No automatic rewrites — the user decides what to strike or qualify.

## Large targets

If the target has more claims than is useful to audit at once (rough threshold: ~30), stop and ask which section or theme to scope to before generating the table. A 100-row table no one reads is worse than no audit.
