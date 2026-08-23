# Model map

Read once before the first delegation of an orchestrated run. Roles and
fallbacks are the contract. The cost/intelligence/taste scores are calibrated
working values under active tuning (higher = better/cheaper; since the
2026-07-28 recalibration the cost column ranks across lanes, not within them)
— they encode routing judgment, not benchmarks; adjust them when experience
disagrees.

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
rules. Any claude-lane seat over claude-lane delegates is this case;
verification routes to the codex lane as usual.

**Seat selection.** The skill still never selects the seat, but field
experience now informs the choice, and a mid-session `/model` switch before
invoking this skill is how a seat is handed over — starting an opus session
and then giving the seat to another model is exactly that. Observed
(field, 2026-07-28): `fable` (Fable 5) is the best seat — strongest of any
model at reading intent, goals and orchestration, with strong frontend
judgment — at roughly twice opus's price, and with one known cost: an
occasional shortcut habit, so a fable seat applies the verification and
senior-review rules to its own conclusions instead of trusting itself.
`sonnet` (Sonnet 5) is a serviceable budget seat for orchestration — a seat
strength that does not extend to its delegate niche, which stays narrow.

## The delegate table

| model | lane | cost | intelligence | taste | default effort | default role | fallback |
|---|---|---:|---:|---:|---|---|---|
| `fable` | claude | 2 | 9 | 9 | medium/high | Priciest row, reserved: fuzzy-intent and highest-stakes user-facing work, where reading underspecified goals is the bottleneck. Occasional shortcut habit — its output still gets acceptance criteria and review | `opus` |
| `opus` | claude | 4 | 9 | 8 | high/xhigh | Claude-lane workhorse (user-facing surface — UI, copy, API shape — and anything needing harness tools) and the standard cross-family verifier of Codex-produced work | gpt-5.6-sol |
| gpt-5.6-sol | codex | 6 | 8–9 | 7 | high/xhigh | Primary execution workhorse (decision 2026-08-24): research, heavy implementation, root-cause, taste/review; fable only when reading underspecified intent is the bottleneck. Scope prompts tightly — see the overengineering note | `opus` |
| gpt-5.6-sol @ max | codex | 3 | 9–10 | 6 | max | Adversarial verification, independent second opinion on critical work | `opus` @ xhigh |
| gpt-5.6-terra | codex | 8 | 7–8 | 6 | high; xhigh/max when it writes | Broad fan-out workhorse (recon, parallel analysis, bulk transforms) and small reviews / simple well-specified coding — first stop below sol; try before luna for anything that is actual code or review | `opus` |
| `sonnet` | claude | 5 | 6 | 7 | high | Budget conductor seat (see seat selection) and the Codex-adapter relay seat @ low (see routing rules) — not an execution lane | `opus` |
| gpt-5.6-luna | codex | 10 | 5–6 | 5 | high; xhigh/max when it writes | Bottom usable tier: extraction, classification, sanity checks — very simple, tightly specified tasks only; prefer terra when the task is code or review | gpt-5.6-terra |
| `haiku` | claude | 10 | 4 | 5 | — | Never use — off-limits even for mechanical relay/adapter stages; luna covers this tier | gpt-5.6-luna |

**The two lanes are named differently, and the difference matters.** Claude-lane
rows are *harness aliases* (`fable`, `opus`, `sonnet`, `haiku`) — the values the
Agent tool's `model` parameter accepts — which resolve to whatever version the
installed Claude Code points them at. A harness update therefore re-points a row
silently, with no change in this repo: observed 2026-07-25 under Claude Code
2.1.219, `opus` resolves to Opus 5; observed 2026-07-28, `fable` resolves to
Fable 5. Codex-lane rows are *exact model IDs* passed
straight through to `codex -m` by the worker helper; they do not resolve to
anything and go stale loudly (a wrong ID fails as `config`). Informal names
resolve through this table, and an ID missing here is read from
`~/.codex/config.toml` — never guessed or transcribed from speech (field,
2026-08-05: dictated `sol-5.6` failed as `config`; the real ID is
`gpt-5.6-sol`).

Write the alias in Claude-lane calls. Versioned Claude IDs (`claude-opus-5`)
are real and are what settings and the API use, but they are the wrong choice
here for two reasons: a delegated stage wants the current best model in its
tier, not a frozen one, and a pinned ID rots into a support question the moment
a version retires. The tradeoff is the silent re-point above — which is why the
seat verifies the delegate's lane rather than trusting a label.

The fallback column is *availability* fallback (model or lane down/throttled),
kept cross-lane where possible so a lane outage never strands a role. Quality
escalation on a failed result is a different move — see the routing rules.
Neither is the same as a provider's own **safety-classifier fallback**, which
swaps the model underneath a running request without telling the orchestrator;
that is a pitfall, not a routing option, and it lives in the skill body.

Effort support varies per model and is enforced server-side (a bad value
returns a clear `api_error`; fix the call). Observed: sol, terra and luna all
accept max — luna's max support field-verified 2026-08-02 through the worker
helper, superseding an earlier observation that it topped out at xhigh.
`fable` supports medium and high only (field, 2026-08-04) — never pin it
above high.
Codex-lane `ultra` exists on some models but is off-limits: it can introduce
nested delegation the orchestrator doesn't control.

## Calibration notes

- **Score provenance** (rule, 2026-07-28): aliases re-point silently, so a
  score is only as trustworthy as its provenance. Every score change here
  names the resolved model that earned it, the date, and the evidence type
  (field vs vendor-reported). When a harness update re-points an alias, the
  row's scores are *inherited, not earned* — treat them as unverified until
  field use confirms them. Not hypothetical: the `opus` row's reputation was
  earned by the model previously behind the alias, and its 8 → 9 bump was
  vendor-reported at the very re-point that installed Opus 5 behind it.
- **fable** (field, 2026-07-28): intelligence 9 — peer of opus — but
  distinctly better at reading intent, goals and orchestration context; taste
  9 with particular frontend strength; occasional shortcut habit, so its
  output is never exempt from acceptance criteria or review. Costs roughly
  twice opus, hence cost 2.
- **sol taste 6 → 7** (field, 2026-08-22): sol is a valid pick for taste and
  review work, not just research and implementation; it sits a notch under
  fable at reading the user's intent, which is the only reason to reach past it.
- **Cost recalibration** (field, 2026-07-28): the column now ranks across
  lanes. fable ≈ 2× opus; opus sits well above every codex-lane model except
  sol @ max, which overtakes it; sol is cheaper than sonnet. Hence fable 2,
  opus 5 → 4, sol 5 → 6.
- **sol overengineers when instructions leave room** (field, 2026-07-28): it
  defaults to adding validation, hardening and safety layers nobody asked
  for — but follows explicit instructions closely. Prompts to sol state scope
  and bound the extras ("no validation/hardening beyond the spec") rather
  than trusting its defaults.
- **sol vs opus**: no established capability ordering — treat them as peers.
  The reason to pair them on hard problems (one implements, the other verifies)
  is *vendor independence*, not a presumed edge either way. Doubling down on
  one buys correlated blind spots.
- **sonnet** costs near opus in practice for similar results on substantive
  work, where it burns more tokens for the same output; on fixed mechanical
  work (the adapter seat) its lower per-token price wins directly. The open
  question about its delegate niche is settled (field, 2026-08-02): no
  execution niche — sonnet's roles are the budget conductor seat (seat
  selection) and the adapter relay seat (routing rules, 2026-08-24).
- **sol as primary execution workhorse** (decision, Seb, 2026-08-24): sol is
  preferred over opus for most delegated execution — peer intelligence,
  strong instruction-following, lower cost. Opus keeps the Claude lane
  (harness-tool work, user-facing surface, a slight frontend-design edge)
  and gains the standard verifier role: sol-heavy production routes owed
  verification to opus under the cross-family rule, so fewer opus workers
  means more opus verification seats, not opus removed. No scores changed —
  the existing columns already supported this reading.
- **GPT-5.6 price cut** (vendor, announced 2026-08-01, effective 2026-07-30):
  luna −80% ($0.20/$1.20 per M in/out), terra −20% ($2/$12). The cut also
  reduces Codex-subscription credit consumption, so it applies in this setup's
  billing, not just the API. Hence terra cost 7 → 8 and luna 9 → 10 — luna now
  undercuts haiku on raw tariff. The same announcement's capability claims
  (luna rivaling frontier models) are vendor benchmarks and adopted nowhere:
  intelligence scores move on field evidence only.
- **Cheap-tier effort compensation** (field, 2026-08-02): terra and luna earn
  their keep at *higher* effort than their price suggests — high for read-only
  work, xhigh/max when they write or execute. The price cut makes this cheap:
  luna at max is still a fraction of sol at medium. Both remain
  delegation-eligible but deliberately underused until their task-class
  boundaries are clearer; the common precondition is a tight spec from the
  seat plus verification where the result matters.
- Score changes need usage evidence, not launch benchmarks. `opus`
  intelligence moved 8 → 9 on 2026-07-25 (Opus 5, vendor-reported: roughly
  double its predecessor's Frontier-Bench at unchanged token price, and
  markedly stronger at verifying its own work rather than declaring a symptom
  fix done) — that entry violated this rule at the time; field-confirmed
  2026-07-28, Opus 5 holds 9 on use, so the bump now stands on evidence.
  Taste deliberately stayed at 8 — benchmarks do not measure the
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
  Instrument constraint (field, 2026-07-29; re-check when the installed
  harness's tool schema changes): the plain Agent tool exposes `model` but no
  `effort`, so a plain one-off Agent dispatch cannot satisfy the effort pin.
  Route such a stage through a single-stage Workflow (`agent()` accepts
  `effort`) or an agent definition that pins effort. This constrains the
  dispatch instrument, not one-off delegation itself.
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
- **Adapter seat: `sonnet` @ `low`.** Codex-lane adapter stages (foreground
  relay and background adapter alike) are pure mechanics — run one helper
  command, relay one JSON envelope — with the orchestrator-minted run dir as
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
