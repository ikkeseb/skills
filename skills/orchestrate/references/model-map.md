# Model map

Roles and fallbacks are the contract. They encode routing judgment, not
benchmarks. Record field evidence and dated price comparisons in the commit
body, not this file. Compare models on accepted tasks, including rework;
token price alone does not establish which model is cheaper for the job.

## Tiers

- **Seat**: the session model. Owns design, specification, cuts and seams,
  integration and final review. This skill never selects or replaces it.
  Fable 5.1 is preferred for design taste and reading user intent; `sonnet`
  is a budget seat. The seat verifies its own conclusions against evidence.
- **Workhorse**: judgment-bearing execution and review. `opus` is the
  default for implementation, migrations and long-horizon codebase work;
  Astra handles the hardest reasoning and cross-family review of Claude
  output; Sol handles well-bounded execution when the Codex lane is the
  better fit. The seat retains final say.
- **Cheap**: Terra and Luna handle bounded readers, extraction, mechanical
  transforms and single-criterion checks. Use independent slices when they
  repay coordination. Their findings are candidates for the seat or a
  workhorse to judge. Open-ended decisions go to a workhorse.

## Delegates

| Model | Lane | Default effort | Role | Availability fallback |
|---|---|---|---|---|
| `gpt-6-astra` | Codex | high; xhigh for difficult reasoning | Demanding research and synthesis, hard root-cause work, critical review and architectural counter-cases; cross-family verification of Claude-produced work | `opus` at high/xhigh; `fable` for fuzzy intent |
| `gpt-5.6-sol` | Codex | high | Bounded implementation, known-pattern migrations, focused research and routine review where the approach and acceptance criteria are clear, when the Codex lane is wanted: cross-family production ahead of a Claude review, or a throttled Claude lane | `opus` |
| `fable` | Claude | medium/high | Design taste, fuzzy intent and highest-stakes user-facing judgment. Delegate only a distinct question the seat cannot resolve as efficiently; a Fable seat seldom needs another Fable | `opus` |
| `opus` | Claude | medium; high for substantive work, xhigh for a named hard problem | Default implementation workhorse: bounded and long-horizon implementation, migrations, codebase audits, frontend builds, user-facing copy and API-shape proposals; work needing Claude harness tools; cross-family verification of Codex-produced work | `gpt-6-astra` for reasoning-heavy work, `gpt-5.6-sol` for bounded implementation, with degraded family coverage when applicable |
| `gpt-5.6-terra` | Codex | high | First cheap stop for bounded code, Map readers, bulk transforms and small criterion-based reviews | `gpt-5.6-sol`; `opus` if the Codex lane is down |
| `gpt-5.6-luna` | Codex | high | Extraction, classification and narrow sanity checks; prefer Terra for code | `gpt-5.6-terra`; `opus` if the Codex lane is down |
| `sonnet` | Claude | low for transport | Budget seat or foreground Codex adapter, not an execution worker | `opus` |
| `haiku` | Claude | — | Off-limits, adapters included; Luna covers cheap work | `gpt-5.6-luna` |

Astra is the first choice when the difficulty is reasoning, uncertainty or
costly mistakes; `opus` when it is implementation. Do not run Sol or `opus`
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
calls pin the model and inherit the session's effort. Deep Claude verification
under a seat below `high` uses a one-agent Workflow with effort pinned.
Omitting a model inherits the seat and can accidentally buy its price or
lose cross-family coverage.

**Effort follows difficulty.** Use the table defaults. `medium` is suitable
for bounded substantive work; `low` for transport and tightly mechanical
work with deterministic validation. Raise to `xhigh` for a named difficult
reasoning problem. `max` needs a specific reason beyond file count or
importance; it is not the default for every review or cheap writer. Astra,
Sol, Terra and Luna accept `max`; `fable` supports `medium` and `high` only.
Codex `ultra` stays off-limits because it may introduce nested delegation.

**Escalate a quality miss once.** Name the missed acceptance criterion and
why the next model can resolve it. Luna goes to Terra, bounded Terra work
to `opus` (Sol on the Codex lane), and reasoning failures to Astra. Taste or intent failures go to
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
  goes to Astra; Codex-produced work goes to `opus`, or Fable for design and
  intent. Same-family coverage is degraded, usable when the other lane is
  unavailable and labeled as such. Report cross-provider, same-provider or
  none. Agreement never replaces checking evidence.
- **Reduce repeated context.** Batch independent source reads into bounded
  outputs and pass relevant excerpts and source locations. Command count is
  a diagnostic, not a bill: context size, caching, output and reasoning all
  affect usage. Prompt budgets and Map routing live in `SKILL.md`.
- **Adapter seat: `sonnet` at `low`.** A foreground adapter runs the helper
  once and relays one envelope. The run directory owns the result if that
  relay garbles. Main-loop dispatch remains the default, without a relay.
- **Image-generation relay exception.** When the worker only prompts a
  separate image model, use `gpt-5.6-sol` at `medium`. The image model does
  the substantive work; this exception never applies to a stage doing its
  own research or implementation.
