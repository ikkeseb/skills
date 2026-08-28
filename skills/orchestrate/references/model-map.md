# Model map

Roles and fallbacks are the contract. The cost/intelligence/taste scores
encode routing judgment, not benchmarks — higher = better/cheaper, and the
cost column ranks across lanes, not within them; adjust the scores when
experience disagrees.

## The senior seat

The session model is the senior seat. It is never a delegate, and this skill
does not select it — the seat is whatever model the session is running, so it
carries no score.

**Seat selection.** A mid-session `/model` switch before invoking this skill
is how a seat is handed over. Field experience: `fable` (Fable 5) is the best
seat — strongest at reading intent, goals and orchestration — at roughly
twice opus's price, with one known cost: an occasional shortcut habit, so a
fable seat applies the verification and senior-review rules to its own
conclusions instead of trusting itself. `sonnet` (Sonnet 5) is a serviceable
budget seat — a seat strength that does not extend to its delegate niche.

## The delegate table

| model | lane | cost | intelligence | taste | default effort | default role | fallback |
|---|---|---:|---:|---:|---|---|---|
| `fable` | claude | 2 | 9 | 9 | medium/high | Priciest row, reserved: fuzzy-intent and highest-stakes user-facing work — reading underspecified goals is the bottleneck; particular frontend strength. Occasional shortcut habit — its output still gets acceptance criteria and review | `opus` |
| `opus` | claude | 4 | 9 | 8 | high/xhigh | Claude-lane workhorse (user-facing surface — UI, copy, API shape — and anything needing harness tools) and the standard cross-family verifier of Codex-produced work | gpt-5.6-sol |
| gpt-5.6-sol | codex | 6 | 8–9 | 7 | high/xhigh | Primary execution workhorse (decision 2026-08-24): research, heavy implementation, root-cause, taste/review; fable only when reading underspecified intent is the bottleneck. Scope prompts tightly — see the overengineering note | `opus` |
| gpt-5.6-sol @ max | codex | 3 | 9–10 | 6 | max | Adversarial verification, independent second opinion on critical work | `opus` @ xhigh |
| gpt-5.6-terra | codex | 8 | 7–8 | 6 | high; xhigh/max when it writes | Broad fan-out workhorse (recon, parallel analysis, bulk transforms) and small reviews / simple well-specified coding — first stop below sol; try before luna for anything that is actual code or review | `opus` |
| `sonnet` | claude | 5 | 6 | 7 | high | Budget conductor seat (see seat selection) and the Codex-adapter relay seat @ low (see routing rules) — not an execution lane | `opus` |
| gpt-5.6-luna | codex | 10 | 5–6 | 5 | high; xhigh/max when it writes | Bottom usable tier: extraction, classification, sanity checks — very simple, tightly specified tasks only; prefer terra when the task is code or review | gpt-5.6-terra |
| `haiku` | claude | 10 | 4 | 5 | — | Never use — off-limits even for mechanical relay/adapter stages; luna covers this tier | gpt-5.6-luna |

**The two lanes are named differently, and the difference matters.**
Claude-lane rows are *harness aliases* (`fable`, `opus`, `sonnet`, `haiku`) —
the values the Agent tool's `model` parameter accepts. Write the alias, never
a versioned Claude ID (`claude-opus-5`): a delegated stage wants the current
best model in its tier, not a frozen one, and a pinned ID rots when a version
retires. The tradeoff is that a harness update re-points an alias silently,
with no change in this repo — which is why the seat verifies the delegate's
lane rather than trusting a label. Codex-lane rows are *exact model IDs*
passed straight through to `codex -m` by the worker helper; they do not
resolve to anything and go stale loudly (a wrong ID fails as `config`).
Informal names resolve through this table, and an ID missing here is read
from `~/.codex/config.toml` — never guessed or transcribed from speech
(dictated `sol-5.6` failed as `config`; the real ID is `gpt-5.6-sol`).

The fallback column is *availability* fallback (model or lane down/throttled),
kept cross-lane where possible so a lane outage never strands a role. Quality
escalation on a failed result is a different move — see the routing rules.
Neither is the same as a provider's own **safety-classifier fallback**, which
swaps the model underneath a running request without telling the
orchestrator — a pitfall, not a routing option; the policy lives in
`codex-exec.md` (provider content filtering).

Effort support varies per model and is enforced server-side — a bad value
returns a clear `api_error`; fix the call. sol, terra and luna accept max;
`fable` supports medium and high only — never pin it above high. Codex-lane
`ultra` exists on some models but is off-limits: it can introduce nested
delegation the orchestrator doesn't control.

## Calibration notes

- **Score provenance** (rule, 2026-07-28): aliases re-point silently, so a
  score is only as trustworthy as its provenance. Every score change here
  names the resolved model that earned it, the date, and the evidence type
  (field vs vendor-reported). When a harness update re-points an alias, the
  row's scores are *inherited, not earned* — treat them as unverified until
  field use confirms them.
- **sol taste 6 → 7** (field, 2026-08-22): sol is a valid pick for taste and
  review work, not just research and implementation; it sits a notch under
  fable at reading the user's intent, which is the only reason to reach past
  it.
- **sol overengineers when instructions leave room** (field, 2026-07-28): it
  defaults to adding validation, hardening and safety layers nobody asked
  for — but follows explicit instructions closely. Prompts to sol state scope
  and bound the extras ("no validation/hardening beyond the spec") rather
  than trusting its defaults.
- **sol as primary execution workhorse** (decision, 2026-08-24): sol is
  preferred over opus for most delegated execution — peer intelligence,
  strong instruction-following, lower cost. Opus keeps the Claude lane
  (harness-tool work, user-facing surface, a slight frontend-design edge)
  and gains the standard verifier role: sol-heavy production routes owed
  verification to opus under the cross-family rule, so fewer opus workers
  means more opus verification seats, not opus removed. The reason to pair
  the lanes on hard problems (one implements, the other verifies) is *vendor
  independence*, not a presumed edge either way — doubling down on one buys
  correlated blind spots.
- **GPT-5.6 price cut** (vendor, effective 2026-07-30): luna −80%, terra
  −20%. The cut also reduces Codex-subscription credit consumption, so it
  applies in this setup's billing, not just the API — hence terra cost 8 and
  luna 10, undercutting haiku on raw tariff.
- **Cheap-tier effort compensation** (field, 2026-08-02): terra and luna earn
  their keep at *higher* effort than their price suggests — high for read-only
  work, xhigh/max when they write or execute. The price cut makes this cheap:
  luna at max is still a fraction of sol at medium. Both remain
  delegation-eligible but deliberately underused until their task-class
  boundaries are clearer; the common precondition is a tight spec from the
  seat plus verification where the result matters.
- Score changes need usage evidence, not launch benchmarks — vendor
  capability claims are adopted nowhere. Cost stays a tariff/quota score; do
  not silently redefine it as cost-per-successful-task.

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
- **Verification is risk-triggered, not blanket — and cross-family when
  owed.** It is owed to work where a wrong result ships or is expensive to
  unwind; everything else is covered by acceptance criteria, tests, and
  mandatory senior review. The verifier must not share the producer's model
  family, the seat's own family included: a seat whose family also appears in
  the delegate table shares its delegates' blind spots, which does not by
  itself add a verification pass but decides who performs one that is owed —
  any claude-lane seat over claude-lane delegates routes verification to the
  codex lane. Same-family or same-lane verification is *degraded coverage*:
  usable when the other lane is down, stated as degraded, never implied away.
  Report coverage honestly: cross-provider, same-provider, or none.
- **Pin `{model, effort}` on every delegated stage.** Put each pin on the call
  itself where the instrument supports it; an agent definition's frontmatter
  may supply `effort` instead. An `effort` omitted from both inherits the
  session's setting, which is a per-session, per-machine choice that will not
  be what the stage needs. An omitted *model* inherits the seat's, which
  manufactures the same-family collision the verification rule exists to
  avoid — so the Workflow tool's own "default to omitting it" advice for
  `model` is overridden here, exactly as its effort advice is below. Explicit
  pinning is what makes a delegated stage reproducible across machines and
  sessions.
- **Effort by kind of work, not by price** — per-model defaults live in the
  table; the universal bounds: `medium` is the floor for substantive work
  (below it the output stops being worth reviewing); `xhigh`/`max` for
  exhaustive inventory, adversarial verification, anything where a miss is
  expensive; `low` only for transport/adapter stages and tightly bounded
  mechanical work with deterministic validation. Do not drop substantive
  stages to `low` to save quota: the Workflow tool's own "use low for cheap
  mechanical stages" advice is overridden here — it does not know which
  stages are substantive, and current premium models earn their best
  performance-per-cost in the high band.
- **Adapter seat: `sonnet` @ `low`.** Codex-lane adapter stages (foreground
  relay and active-wait adapter alike) are pure mechanics — run the helper
  command, hold bounded waits, relay one JSON envelope — with the orchestrator-minted run dir as
  ground truth if the relay garbles. Pin them `sonnet` @ `low` (field,
  2026-08-24: one green foreground relay held the contract verbatim; sonnet's
  lower per-token price nets ~20–25 % per relay despite a slightly higher
  token count). This supersedes the earlier opus @ low transport pin. The
  shipped `codex-worker` agent definition carries the same pin; `haiku`
  remains off-limits even here.
- **Relay-stage exception** (field, 2026-08-05): a stage whose real labor
  happens in a *separate* model the worker merely prompts — image generation
  relayed through a Codex worker is the known case — is pinned to
  `gpt-5.6-sol` @ `medium`; higher effort buys nothing there. Applies only
  when the relay target is actually available in the setup, and never to
  stages that do their own labor.
- **Never route judgment work to the cheap tier**: luna-class models do
  extraction and mechanical checks; anything requiring a decision goes at
  least one tier up.
