# Model map

Read once before the first delegation of an orchestrated run. Roles and
fallbacks are the contract. The cost/intelligence/taste scores are calibrated
working values under active tuning (higher = better/cheaper within its own
lane's quota) — they encode routing judgment, not benchmarks; adjust them
when experience disagrees.

## The senior seat

The session model is the senior seat: orchestration, synthesis, final review
and integration. It is never a delegate, and this skill does not select it —
the seat is whatever model the session is running, so the invariant is stated
here without a score. The seat's own context is the scarce resource; delegate
work, not judgment.

**Same-family collision.** When the seat's model family also appears in the
delegate table (an opus session delegating to `opus`, say), seat and delegate
share blind spots. That does not by itself add a verification pass — but when
verification *is* triggered, it changes who may perform it: see the routing
rules.

## The delegate table

| model | lane | cost | intelligence | taste | default effort | default role | fallback |
|---|---|---:|---:|---:|---|---|---|
| `opus` | claude | 5 | 9 | 8 | high/xhigh | Real-coding workhorse; best taste among delegates — user-facing surface (UI, copy, API shape) build-out | gpt-5.6-sol |
| gpt-5.6-sol | codex | 5 | 8–9 | 6 | high/xhigh | Heavy implementation, root-cause work | `opus` |
| gpt-5.6-sol @ max | codex | 3 | 9–10 | 6 | max | Adversarial verification, independent second opinion on critical work | `opus` @ xhigh |
| gpt-5.6-terra | codex | 7 | 7–8 | 6 | high | Broad fan-out workhorse (recon, parallel analysis, bulk transforms) | `opus` |
| `sonnet` | claude | 5 | 6 | 7 | high | Narrow niche: only when opus is overkill and the task needs more taste than the cheap tier offers | `opus` |
| gpt-5.6-luna | codex | 9 | 5–6 | 5 | low/medium | THE cheap tier: extraction, classification, sanity checks | gpt-5.6-terra |
| `haiku` | claude | 10 | 4 | 5 | — | Never use — off-limits even for mechanical relay/adapter stages; luna covers this tier | gpt-5.6-luna |

**The two lanes are named differently, and the difference matters.** Claude-lane
rows are *harness aliases* (`opus`, `sonnet`, `haiku`) that resolve to whatever
version the installed Claude Code points them at — so a harness update re-points
a row silently, with no change in this repo. Observed 2026-07-25 under Claude
Code 2.1.219: `opus` resolves to Opus 5. Codex-lane rows are *exact model IDs*
passed straight through to `codex -m` by the worker helper; they do not resolve
to anything and go stale loudly (a wrong ID fails as `config`). Never write a
versioned Claude model string into a delegated call — pin the alias and let it
resolve.

The fallback column is *availability* fallback (model or lane down/throttled),
kept cross-lane where possible so a lane outage never strands a role. Quality
escalation on a failed result is a different move — see the routing rules.
Neither is the same as a provider's own **safety-classifier fallback**, which
swaps the model underneath a running request without telling the orchestrator;
that is a pitfall, not a routing option, and it lives in the skill body.

Effort support varies per model and is enforced server-side (a bad value
returns a clear `api_error`; fix the call). Observed: luna accepts
none/low/medium/high/xhigh — no minimal, no max; sol and terra accept max.
Codex-lane `ultra` exists on some models but is off-limits: it can introduce
nested delegation the orchestrator doesn't control.

## Calibration notes

- **sol vs opus**: no established capability ordering — treat them as peers.
  The reason to pair them on hard problems (one implements, the other verifies)
  is *vendor independence*, not a presumed edge either way. Doubling down on
  one buys correlated blind spots.
- **sonnet** costs near opus in practice for similar results, which is why its
  niche is narrow. Whether that niche still exists is an open question, not a
  settled one.
- Score changes need usage evidence, not launch benchmarks. `opus`
  intelligence moved 8 → 9 on 2026-07-25 (Opus 5, vendor-reported: roughly
  double its predecessor's Frontier-Bench at unchanged token price, and
  markedly stronger at verifying its own work rather than declaring a symptom
  fix done). Taste deliberately stayed at 8 — benchmarks do not measure the
  repo-specific judgment that column tracks. Cost stays a tariff/quota score;
  do not silently redefine it as cost-per-successful-task.
- The lanes bill separate subscriptions, so one lane throttling rarely means
  both are closed — rate-limit handling follows the failure policy in
  `codex-exec.md`.

## Routing rules

- **Intelligence > taste > cost** for anything that ships; cost breaks ties.
- **Escalate on failure without asking, once**: if a delegate's output misses
  the bar, rerun one tier up the intelligence column — judge the output, not
  the price tag. One escalation, then stop: a second miss is a spec problem or
  a main-loop problem, and re-rolling is spend without a hypothesis. This
  governs *quality* misses only; a `workspace-write` failure is never
  blind-retried at any tier (the tree may hold a partial change to inspect).
  Wider spend changes (bigger fan-outs, more rounds) follow the session's
  spend posture, not this rule.
- **Verification is risk-triggered, not blanket**: it is owed to work where a
  wrong result ships or is expensive to unwind. Everything else is covered by
  acceptance criteria, tests, and mandatory senior review.
- **When verification is owed, the verifier must not share the producer's
  model family** — including the seat's own family, which is the common case
  in a same-family collision. Route it to the other lane. Same-family or
  same-lane verification is *degraded coverage*: usable when the other lane is
  down, but stated as degraded, never implied away. Report coverage honestly:
  cross-provider, same-provider, or none.
- **Pin `{model, effort}` on every delegated call.** An omitted `effort`
  inherits the session's setting, which is a per-session, per-machine choice
  that will not be what the stage needs. Explicit pinning is what makes a
  delegated stage reproducible across machines and sessions.
- **Effort by kind of work, not by price:**
  - `high` — default for substantive delegated work (implementation, analysis,
    review).
  - `medium` — floor for substantive work; below this the output stops being
    worth reviewing.
  - `xhigh`/`max` — exhaustive inventory, adversarial verification, anything
    where a miss is expensive.
  - `low` — allowed only for transport/adapter stages and tightly bounded
    mechanical work with deterministic validation.
  Do not drop substantive stages to `low` to save quota. The generic
  "use low for cheap mechanical stages" advice in the Workflow tool's own
  documentation is overridden here: it does not know which stages are
  substantive, and current premium models earn their best performance-per-cost
  in the high band, not the low one.
- **Never route judgment work to the cheap tier**: luna-class models do
  extraction and mechanical checks; anything requiring a decision goes at
  least one tier up.
