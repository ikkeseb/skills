# Model map

Read once before the first delegation of an orchestrated run. Roles and
fallbacks are the contract. The cost/intelligence/taste scores are calibrated
working values under active tuning (higher = better/cheaper within its own
lane's quota) — they encode routing judgment, not benchmarks; adjust them
when experience disagrees.

## The table

| model | lane | cost | intelligence | taste | default effort | default role | fallback |
|---|---|---:|---:|---:|---|---|---|
| fable-5 (or session model) | main loop | 2 | 10 | 9 | — | Senior seat: orchestration, synthesis, final review. Not a delegate. Scores describe fable-5; the seat invariant holds for whatever model runs the session — when the seat's model family also appears as a delegate, verify its lane's work in the other lane. | — |
| opus-4.8 | claude | 5 | 8 | 8 | high/xhigh | Real-coding workhorse; best taste among delegates — user-facing surface (UI, copy, API shape) build-out | gpt-5.6-sol |
| gpt-5.6-sol | codex | 5 | 8–9 | 6 | high/xhigh | Heavy implementation, root-cause work | opus-4.8 |
| gpt-5.6-sol @ max | codex | 3 | 9–10 | 6 | max | Adversarial verification, independent second opinion on critical work | opus-4.8 @ xhigh |
| gpt-5.6-terra | codex | 7 | 7–8 | 6 | high | Broad fan-out workhorse (recon, parallel analysis, bulk transforms) | opus-4.8 |
| sonnet-5 | claude | 5 | 6 | 7 | high | Narrow niche: only when opus is overkill and the task needs more taste than the cheap tier offers | opus-4.8 |
| gpt-5.6-luna | codex | 9 | 5–6 | 5 | low/medium | THE cheap tier: extraction, classification, sanity checks | gpt-5.6-terra |
| haiku-4.5 | claude | 10 | 4 | 5 | — | Avoid — luna covers this tier | gpt-5.6-luna |

The fallback column is *availability* fallback (model or lane down/throttled),
kept cross-lane where possible so a lane outage never strands a role. Quality
escalation on a failed result is a different move — see the routing rules.

Effort support varies per model and is enforced server-side (a bad value
returns a clear `api_error`; fix the call). Observed: luna accepts
none/low/medium/high/xhigh — no minimal, no max; sol and terra accept max.
Codex-lane `ultra` exists on some models but is off-limits: it can introduce
nested delegation the orchestrator doesn't control.

## Calibration notes

- **sol vs opus**: sol is often slightly stronger raw (hard bugs, deep
  root-cause); opus has slightly better taste. On hard problems, pair them —
  one implements, the other verifies — rather than doubling down on either.
- **sonnet** costs near opus in practice for similar results, which is why its
  niche is narrow.
- The lanes bill separate subscriptions, so one lane throttling rarely means
  both are closed — rate-limit handling follows the failure policy in
  `codex-exec.md`.

## Routing rules

- **Intelligence > taste > cost** for anything that ships; cost breaks ties.
- **Escalate on failure without asking**: if a delegate's output misses the
  bar, rerun one tier up — judge the output, not the price tag. Wider spend
  changes (bigger fan-outs, more rounds) follow the session's spend posture,
  not this rule.
- **Cross-provider verification is risk-triggered, not blanket**: for work
  where a wrong result ships or is expensive to unwind, implement in one lane
  and adversarially verify in the other (uncorrelated blind spots). Report
  coverage honestly: cross-provider, same-provider, or none — a degraded
  verification is stated, never implied away.
- **Never route judgment work to the cheap tier**: luna-class models do
  extraction and mechanical checks; anything requiring a decision goes at
  least one tier up.
