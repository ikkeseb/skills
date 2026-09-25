# Model map

Roles and fallbacks are the contract. They encode routing judgment, not
benchmarks; field evidence and dated price comparisons belong in the commit
body, not this file.

## Seat

The session model owns design, briefs, cuts and seams, integration and
final review; this skill never selects or replaces it. Opus 5.5 is a strong
seat at far lower cost; Fable 5.1, the larger model, may still read intent
and the big picture a little better; `sonnet` is a budget seat. An `opus`
seat delegating to `opus` buys parallelism and context isolation, not a
second opinion. The seat verifies its own conclusions against evidence.

## Delegates

**Workhorses** carry judgment-bearing execution and review; the seat keeps
final say. Astra is the first choice when the difficulty is reasoning,
uncertainty or costly mistakes, and handles critical cross-family review of
Claude output. `opus` is the default for implementation, bounded or
long-horizon, frontend and judgment-bearing builds. Sol handles routine
cross-family review of Claude output at low cost when Astra is not needed.
Do not run Sol or `opus` first merely to justify Astra through a failed
attempt. Fable's taste and intent role does not imply a general reasoning
advantage over Astra.

**Cheap tier.** Luna handles bounded readers, extraction, mechanical
transforms, single-criterion checks and spec-bounded mechanical
implementation that a deterministic gate checks. Its findings are
candidates for the seat or a workhorse to judge; open-ended decisions go to
a workhorse. Gemini Flash is a low-priority read-only extra, not a Luna
replacement: no shell, no writes, and too weak to carry verification.

Research requiring live web or other harness tools uses a lane verified to
provide them; the Codex probe does not test tool availability.

| Model | Lane | Default effort | Role | Availability fallback |
|---|---|---|---|---|
| `gpt-6-astra` | Codex | high; xhigh for difficult reasoning | Demanding research and synthesis, hard root-cause work, critical review and architectural counter-cases; cross-family verification of Claude-produced work | `opus` at high/xhigh; `fable` for fuzzy intent |
| `gpt-6-sol` | Codex | high; xhigh for a harder slice | Routine cross-family review of Claude-produced work when Astra is not needed, focused research and relay work; writes code only under a tight spec whose wrong result a test or lint gate catches | `gpt-6-astra`; `opus` if the Codex lane is down |
| `fable` | Claude | medium/high | Design taste, fuzzy intent and highest-stakes user-facing judgment. Delegate only a distinct question the seat cannot resolve as efficiently; a Fable seat seldom needs another Fable | `opus` |
| `opus` | Claude | medium; high for substantive work, xhigh for a named hard problem | Default workhorse for long-horizon implementation, migrations, codebase audits, frontend builds, user-facing copy and API-shape proposals; work needing Claude harness tools; cross-family verification of Codex-produced work | `gpt-6-astra`, with degraded family coverage when applicable |
| `gpt-6-luna` | Codex | high | Map readers, extraction, classification, bulk transforms, small criterion-based reviews, and mechanical implementation under a tight spec whose wrong result a test or lint gate catches; findings are candidates, never decisions | `gpt-6-sol`; `opus` if the Codex lane is down |
| `gemini-3.8-flash-high` | agy (read-only) | in the id: `-high` | Low priority, never ahead of Luna unless the user sends work here (Codex usage spent, or Google models asked for): an extra third-family opinion on a read, or bounded reads, extraction and general-knowledge questions; never counts or inventories (no shell) and never the owed cross-family verifier; findings are candidates, never decisions | `gpt-6-luna` |
| `sonnet` | Claude | low for transport | Budget seat or foreground Codex adapter, not an execution worker | `opus` |
| `haiku` | Claude | — | Off-limits, adapters included; Luna covers cheap work | `gpt-6-luna` |

## Routing rules

**Lane naming.** Claude rows use harness aliases accepted by the Agent
`model` parameter, never a versioned ID. Codex rows use exact IDs passed
to `codex --model`; the agy row uses an exact id from the Gemini helper's
`probe`, effort included. Resolve informal names here, or from the active
CLI's models cache when absent. An ambiguous name needs clarification; an invalid ID fails loudly,
never silently selects another model.

**Effort follows difficulty.** Use the table defaults, judged on the
difficulty left after the brief: a tight brief has already made the
decisions, so its implementer may run a notch below the default; a thin
brief earns no discount. `medium` suits bounded substantive work; `low`
suits transport and tightly mechanical work with deterministic validation.
Raise to `xhigh` for a named difficult reasoning problem. `max` needs a
specific reason beyond file count or importance; it is not the default for
every review or cheap writer. Astra, Sol and Luna accept `max`; `fable`
supports `medium` and `high` only. Codex `ultra` stays off-limits because
it may introduce nested delegation.

**Escalate a quality miss once.** Name the missed acceptance criterion and
why the next model can resolve it. Luna goes to `opus`; a Sol review miss
and reasoning failures go to Astra; taste or intent failures go to Fable. A
second miss goes back to the seat to fix the brief or investigate, not
another reroll.

**Availability fallback** is for a model or lane that is unavailable or
throttled, distinct from quality escalation. State the replacement and any
lost coverage. A whole Codex outage uses the Claude lane even when a table
row's first fallback is another Codex model.

## Review and spend

- **Quality before price for work that ships.** Take the least costly
  route that meets the acceptance criteria, judged on expected total work
  per accepted task (reconnaissance, verification, likely rework), never on
  token price alone.
- **Verification routing.** When verification is owed (`SKILL.md`
  § Review), the producer family includes the seat's contributions:
  Claude-produced work goes to Astra, or Sol for routine review;
  Codex-produced work goes to `opus`, or Fable for design and intent.
  Same-family coverage is degraded: usable when the other lane is
  unavailable, and labeled as such. Report cross-provider, same-provider or
  none. Agreement never replaces checking evidence.
- **Image-generation relay exception.** When the worker only prompts a
  separate image model, use `gpt-6-sol` at `medium`. The image model does
  the substantive work; this exception never applies to a stage doing its
  own research or implementation.
