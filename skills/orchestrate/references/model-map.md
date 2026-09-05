# Model map

Roles and fallbacks are the contract. The cost/intelligence/taste scores
encode routing judgment, not benchmarks: higher is better or cheaper, and
the cost column ranks across lanes. Adjust a score when field use disagrees,
and put the evidence (resolved model, date, field or vendor) in the commit
body, never here. Vendor capability claims never move a score.

## Tiers

Three tiers, cut by blast radius and final say rather than by score:

- **Seat**: the session model. Design, specification, cuts and seams,
  integration, final review. Never a delegate; this skill does not select
  it. A mid-session `/model` switch before invoking this skill hands the
  seat over. `fable` (Fable 5.1) is the strongest seat at reading intent
  and orchestrating, at about twice opus's price, with one known habit:
  shortcuts, so a fable seat applies the verification and senior-review
  rules to its own conclusions. `sonnet` is a serviceable budget seat.
- **Workhorse** (`opus`, gpt-5.6-sol): execution that carries judgment:
  implementation, root-cause, research with conclusions, cross-family
  review, recommendations. The last delegate word before the seat.
- **Cheap** (gpt-5.6-terra, gpt-5.6-luna): the default for breadth and
  mechanics: Map readers, single-dimension checkers, sweeps, extraction,
  classification, test and lint fix-ups, "does this diff meet criterion N".
  Fans out by default; every result is a candidate the seat or a workhorse
  judges, never a verdict. Anything that needs a decision goes one tier up.
  The cheap tier earns its keep at higher effort than its price suggests:
  high for read-only work, xhigh or max when it writes; fan-outs run at
  high because max is slow. It needs a tight spec and fumbles on
  open-ended work, so it replaces nothing in the workhorse tier.

`fable` as a delegate is the rare exception to all three: a fable seat over
fable delegates buys nothing the seat does not already have.

## The delegate table

| model | lane | cost | intelligence | taste | default effort | default role | fallback |
|---|---|---:|---:|---:|---|---|---|
| `fable` | claude | 2 | 9 | 9 | medium/high | Reserved: fuzzy-intent, highest-stakes user-facing work, particular frontend strength. Its output still gets acceptance criteria and review | `opus` |
| `opus` | claude | 4 | 9 | 8 | high/xhigh | Claude-lane workhorse: user-facing surface (UI, copy, API shape) and anything needing harness tools; the standard cross-family verifier of Codex-produced work | gpt-5.6-sol |
| gpt-5.6-sol | codex | 6 | 8–9 | 7 | high/xhigh | Primary execution workhorse: research, heavy implementation, root-cause, taste and review. It overbuilds when the spec leaves room (validation, hardening, safety layers nobody asked for) and follows explicit bounds closely, so state scope and bound the extras | `opus` |
| gpt-5.6-sol @ max | codex | 3 | 9–10 | 6 | max | Adversarial verification, independent second opinion on critical work | `opus` @ xhigh |
| gpt-5.6-terra | codex | 8 | 7–8 | 6 | high; xhigh/max when it writes | First cheap stop: Map readers, parallel analysis, bulk transforms, small reviews, simple well-specified code | `opus` |
| `sonnet` | claude | 5 | 6 | 7 | high | Budget seat and the Codex-adapter relay seat @ low; not an execution lane | `opus` |
| gpt-5.6-luna | codex | 10 | 5–6 | 5 | high; xhigh/max when it writes | Cheapest usable: extraction, classification, sanity checks, single-criterion checks; terra first when the task is code | gpt-5.6-terra |
| `haiku` | claude | 10 | 4 | 5 | — | Off-limits, adapter stages included; luna covers this tier | gpt-5.6-luna |

`gpt-6-astra` exists in the Codex lane and may be the CLI's configured
default, but it is not routed here: it costs more than sol and has no field
record in this setup. Delegate to it only on an explicit user ask.

**Lane naming.** Claude-lane rows are harness aliases (`fable`, `opus`,
`sonnet`, `haiku`), the values the Agent tool's `model` parameter accepts.
Write the alias, never a versioned Claude ID: a delegated stage wants the
current best model in its tier, and a pinned ID rots. A harness update
re-points an alias silently, so the seat verifies the delegate's lane
rather than trusting the label, and a re-pointed row's scores are
inherited, not earned. Codex-lane rows are exact model IDs passed straight
to `codex -m`; a wrong ID fails loudly as `config`. Resolve informal names
through this table and read an ID missing here from the CLI's models
cache; never transcribe one from speech.

**Fallback** is availability fallback (model or lane down or throttled),
kept cross-lane so a lane outage never strands a role. Quality escalation
on a failed result is a different move (routing rules). Neither is the
provider's own safety-classifier fallback, which swaps the model under a
running request without telling the orchestrator; that policy lives in
`codex-exec.md` § Result contract.

**Effort** is enforced server-side; a bad value returns a clear
`api_error`, so fix the call. sol, terra and luna accept `max`. `fable`
supports `medium` and `high` only. Codex-lane `ultra` is off-limits: it can
introduce nested delegation the orchestrator does not control.

## Routing rules

- **Intelligence > taste > cost** for anything that ships; cost breaks ties.
- **Escalate on failure without asking, once.** If a delegate's output
  misses the bar, rerun one tier up the intelligence column; judge the
  output, not the price tag. A second miss is a spec problem or a main-loop
  problem, and re-rolling is spend without a hypothesis. This governs
  quality misses only; a `workspace-write` failure is never blind-retried
  at any tier (the tree may hold a partial change to inspect).
- **Verification is risk-triggered and cross-family when owed.** It is owed
  to work where a wrong result ships or is expensive to unwind; everything
  else is covered by acceptance criteria, tests and mandatory senior
  review. The verifier never shares the producer's model family, the seat's
  own family included: a claude-lane seat over claude-lane delegates routes
  verification to the codex lane. Same-family verification is degraded
  coverage: usable when the other lane is down, stated as degraded. Report
  coverage honestly: cross-provider, same-provider, or none. Pairing the
  lanes buys vendor independence, not a presumed edge either way.
- **Pin `model` on every delegated stage; pin `effort` where the
  instrument takes one.** Workflow stages pin both on the `agent()` call;
  Codex stages pin both through the helper; a plain Agent dispatch pins
  `model` only, so the stage inherits the session's effort, which is the
  right level for bounded Claude work under a medium seat. The one stage
  inheritance shortchanges, deep verification of Codex-produced work, goes
  as a one-agent Workflow with `effort` pinned. An omitted model inherits
  the seat's, which manufactures the same-family collision above and,
  under a fable seat, bills the stage at fable price; the Workflow tool's
  own advice to omit `model` is overridden here.
- **Effort by kind of work, not by price.** Per-model defaults live in the
  table. `medium` is the floor for substantive work; `xhigh` or `max` for
  exhaustive inventory, adversarial verification, anything where a miss is
  expensive; `low` only for transport or adapter stages and tightly bounded
  mechanical work with deterministic validation. The Workflow tool's "use
  low for cheap mechanical stages" advice is overridden here: it does not
  know which stages are substantive.
- **Rounds are the cost, not text.** Every worker round re-sends its
  context, so a read-heavy stage's spend scales with command count, not
  prompt length. The levers are the prompt's `budget:` line and the
  Map-stage split (SKILL.md).
- **Adapter seat: `sonnet` @ `low`.** A Codex-lane foreground adapter is
  pure mechanics: run the helper, relay one JSON envelope, with the run dir
  as ground truth if the relay garbles. The shipped `codex-worker` agent
  carries the same pin; `haiku` stays off-limits even here.
- **Relay-stage exception.** A stage whose real labor happens in a separate
  model the worker merely prompts (image generation relayed through a
  Codex worker) is pinned to `gpt-5.6-sol` @ `medium`; higher effort buys
  nothing there. Never applies to stages that do their own labor.
