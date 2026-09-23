# Model map

Roles and fallbacks are the contract. They encode routing judgment, not
benchmarks. Record field evidence and dated price comparisons in the commit
body, not this file. Compare models on accepted tasks, including rework;
token price alone does not establish which model is cheaper for the job.

## Tiers

- **Seat**: the session model. Owns design, specification, cuts and seams,
  integration and final review. This skill never selects or replaces it.
  Opus 5.5 is a strong seat at far lower cost; Fable 5.1, the larger model,
  may still read intent and the big picture a little better; `sonnet` is a
  budget seat. An `opus` seat delegating to `opus` buys parallelism and
  context isolation, not a second opinion. The seat verifies its own
  conclusions against evidence.
- **Workhorse**: judgment-bearing execution and review. `opus` is the
  default for long-horizon implementation, frontend and judgment-bearing
  builds, bounded implementation included; Astra handles the hardest
  reasoning and critical cross-family review of Claude output; Sol handles
  routine cross-family review of Claude output at low cost. The seat
  retains final say.
- **Cheap**: Luna handles bounded readers, extraction, mechanical
  transforms, single-criterion checks and spec-bounded mechanical
  implementation that a deterministic gate checks. Use independent slices
  when they repay coordination. Its findings are candidates for the seat or a
  workhorse to judge. Open-ended decisions go to a workhorse.

## Delegates

| Model | Lane | Default effort | Role | Availability fallback |
|---|---|---|---|---|
| `gpt-6-astra` | Codex | high; xhigh for difficult reasoning | Demanding research and synthesis, hard root-cause work, critical review and architectural counter-cases; cross-family verification of Claude-produced work | `opus` at high/xhigh; `fable` for fuzzy intent |
| `gpt-6-sol` | Codex | high; xhigh for a harder slice | Routine cross-family review of Claude-produced work when Astra is not needed, focused research and relay work; writes code only under a tight spec whose wrong result a test or lint gate catches | `gpt-6-astra`; `opus` if the Codex lane is down |
| `fable` | Claude | medium/high | Design taste, fuzzy intent and highest-stakes user-facing judgment. Delegate only a distinct question the seat cannot resolve as efficiently; a Fable seat seldom needs another Fable | `opus` |
| `opus` | Claude | medium; high for substantive work, xhigh for a named hard problem | Default workhorse for long-horizon implementation, migrations, codebase audits, frontend builds, user-facing copy and API-shape proposals; work needing Claude harness tools; cross-family verification of Codex-produced work | `gpt-6-astra`, with degraded family coverage when applicable |
| `gpt-6-luna` | Codex | high | Map readers, extraction, classification, bulk transforms, small criterion-based reviews, and mechanical implementation under a tight spec whose wrong result a test or lint gate catches; findings are candidates, never decisions | `gpt-6-sol`; `opus` if the Codex lane is down |
| `sonnet` | Claude | low for transport | Budget seat or foreground Codex adapter, not an execution worker | `opus` |
| `haiku` | Claude | — | Off-limits, adapters included; Luna covers cheap work | `gpt-6-luna` |

Astra is the first choice when the difficulty is reasoning, uncertainty or
costly mistakes; `opus` for implementation, bounded or long-horizon; Luna
when the work is mechanical and gated; Sol for routine review of Claude
output when Astra is not needed. Do not run Sol or `opus`
first merely to justify Astra through a failed attempt. Fable's taste and
intent role does not imply a general reasoning advantage over Astra. State
scope and acceptance criteria for any of them; a stronger model still needs
a bounded job. Research requiring
live web or other harness tools uses a lane verified to provide them; the
Codex probe does not test tool availability.

## Routing rules

**Lane naming.** Claude rows use harness aliases accepted by the Agent
`model` parameter. Use the alias rather than a versioned ID and report the
resolved model only when verified. Codex rows use exact IDs passed to
`codex --model`. Resolve informal names here, or from the active CLI's
models cache when absent. An ambiguous name needs clarification; an invalid
ID fails loudly, never silently selects another model.

**Pin every stage.** Pin `model`, and `effort` where the instrument accepts
it. Workflow `agent()` calls and Codex helper calls pin both. Plain Agent
calls pin the model and inherit the session's effort; a Claude stage that
needs another effort uses a one-agent Workflow with effort pinned.
Omitting a model inherits the seat and can accidentally buy its price or
lose cross-family coverage.

**Effort follows difficulty.** Use the table defaults, judged on the
difficulty left after the brief: a tight specification has already made
the decisions, so its implementer may run a notch below the default; a
thin brief earns no discount. `medium` is suitable
for bounded substantive work; `low` for transport and tightly mechanical
work with deterministic validation. Raise to `xhigh` for a named difficult
reasoning problem. `max` needs a specific reason beyond file count or
importance; it is not the default for every review or cheap writer. Astra,
Sol and Luna accept `max`; `fable` supports `medium` and `high` only.
Codex `ultra` stays off-limits because it may introduce nested delegation.

**Escalate a quality miss once.** Name the missed acceptance criterion and
why the next model can resolve it. Luna goes to `opus`; a Sol review miss
and reasoning failures go to Astra. Taste or intent failures go to
Fable. A second miss goes back to the seat to fix the brief or investigate,
not another reroll. Inspect partial writes before any retry; a failed
`workspace-write` run never earns a blind rerun.

**Availability fallback** is for a model or lane that is unavailable or
throttled, distinct from quality escalation. State the replacement and any
lost coverage. A whole Codex outage uses the Claude lane even when a table
row's first fallback is another Codex model. Provider-side substitution is
not verified by the requested model echoed in the helper envelope.

## Review and spend

- **Quality before price for work that ships.** Prefer the least costly
  route that meets the acceptance criteria. Choose on expected total work,
  including reconnaissance, verification and likely rework.
- **Verification is risk-triggered and cross-family when owed.** A wrong
  result that can ship or is expensive to unwind earns it. Other work uses
  acceptance criteria, tests and mandatory seat review. Include the seat's
  contributions when determining the producer family: Claude-produced work
  goes to Astra, or Sol for routine review; Codex-produced work goes to `opus`, or Fable for design and
  intent. Same-family coverage is degraded, usable when the other lane is
  unavailable and labeled as such. Report cross-provider, same-provider or
  none. Agreement never replaces checking evidence.
- **Reduce repeated context.** Batch independent source reads into bounded
  outputs and pass relevant excerpts and source locations. Command count is
  a diagnostic, not a bill: context size, caching, output and reasoning all
  affect usage. Every command round replays the worker's growing context,
  so fewer, larger reads are the lever. Prompt budgets and Map routing live in `SKILL.md`.
- **Adapter seat: `sonnet` at `low`.** A foreground adapter runs the helper
  once and relays one envelope. The run directory owns the result if that
  relay garbles. Main-loop dispatch remains the default, without a relay.
- **Image-generation relay exception.** When the worker only prompts a
  separate image model, use `gpt-6-sol` at `medium`. The image model does
  the substantive work; this exception never applies to a stage doing its
  own research or implementation.
