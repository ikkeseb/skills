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
Claude output. `opus` is the default for long-horizon implementation,
frontend and judgment-bearing builds. Sol handles routine
cross-family review of Claude output at low cost when Astra is not needed.
Do not run Sol or `opus` first merely to justify Astra through a failed
attempt. Fable's taste and intent role does not imply a general reasoning
advantage over Astra.

**Claude-lane mid tier.** `sonnet` takes the bounded, gate-checked
execution its row lists when a weaker model handles the task fine, and runs
at `high` only: work that would need a higher `sonnet` effort goes to
`opus`, which reaches that level for less. It draws on the same Claude
quota as `opus` and gives no cross-family coverage, so Luna stays first for
cheap mechanical work while the Codex lane is up.

**Cheap tier.** Luna handles bounded readers, extraction, mechanical
transforms, single-criterion checks and spec-bounded mechanical
implementation that a deterministic gate checks. Its findings are
candidates for the seat or a workhorse to judge; open-ended decisions go to
a workhorse. Gemini Flash is a read-only third-family voice on its own
quota, separate from the Codex and Claude lanes: a standing extra in ideation, product and UX
discussion, vision work, research from supplied sources and general
knowledge, and first-pass review triage that a stronger model verifies. It
is not a Luna replacement or a code writer: no shell, no writes, too weak to
carry verification, and never the only source for a fact. Its
floor is `gemini-3.8-flash-high`: never an older version (Pro included),
a lower effort or agy's non-Gemini models; the helper refuses them.

Research requiring live web or other harness tools uses a lane verified to
provide them; the Codex probe does not test tool availability.

| Model | Lane | Default effort | Role | Availability fallback |
|---|---|---|---|---|
| `gpt-6-astra` | Codex | high; xhigh/max only on the user's word | Demanding research and synthesis, hard root-cause work, critical review and architectural counter-cases; cross-family verification of Claude-produced work | `opus` at high/xhigh; `fable` for fuzzy intent |
| `gpt-6.1-sol` | Codex | high; xhigh/max only on the user's word | Routine cross-family review of Claude-produced work when Astra is not needed, focused research and relay work; writes code only under a tight spec whose wrong result a test or lint gate catches | `gpt-6-astra`; `opus` if the Codex lane is down |
| `fable` | Claude | medium/high | Design taste, fuzzy intent and highest-stakes user-facing judgment. Delegate only a distinct question the seat cannot resolve as efficiently; a Fable seat seldom needs another Fable | `opus` |
| `opus` | Claude | medium; high for substantive work, xhigh for a named hard problem | Default workhorse for long-horizon implementation, migrations, codebase audits, frontend builds, user-facing copy and API-shape proposals; judgment-bearing work needing Claude harness tools; cross-family verification of Codex-produced work | `gpt-6-astra`, with degraded family coverage when applicable |
| `gpt-6-luna` | Codex | high | Map readers, extraction, classification, bulk transforms, small criterion-based reviews, and mechanical implementation under a tight spec whose wrong result a test or lint gate catches; findings are candidates, never decisions | `gpt-6.1-sol`; `sonnet` if the Codex lane is down |
| `gemini-3.8-flash-high` | agy (read-only) | in the id: `-high` | Extra third-family voice in ideation, product and UX rounds, reading screenshots and UI images, research from supplied sources and general knowledge, and first-pass review triage; never ahead of Luna for bounded reads and extraction unless the user sends work here (Codex usage spent, or Google models asked for); never writes code, never counts or inventories (no shell) and never the owed cross-family verifier; findings are candidates, never decisions | `gpt-6-luna` |
| `sonnet` | Claude | high only; low for transport | Execution whose wrong result a test or lint gate catches: spec-bounded implementation, Sweep transforms, shell-heavy agentic work and bounded work needing Claude harness tools; also the budget seat and the foreground Codex adapter. Never design, fuzzy intent or owed verification; findings are candidates, never decisions | `opus` |
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
On the Claude lane, raise to `xhigh` for a named difficult reasoning
problem; `max` needs a specific reason beyond file count or importance and
is not the default for every review or cheap writer. On the Codex lane,
`high` is the ceiling unless the user explicitly asks for a higher level:
every run draws on the user's weekly subscription quota, and `xhigh` and
`max` drain it fastest. When a Codex stage looks too hard for `high`, say so
and let the user choose, or route the hard part to `opus` at `xhigh`. Astra, Sol and Luna accept `max`; `fable`
supports `medium` and `high` only. Codex `ultra` stays off-limits because
it may introduce nested delegation.

**Escalate a quality miss once.** Name the missed acceptance criterion and
why the next model can resolve it. Luna and `sonnet` go to `opus`; a Sol
review miss and reasoning failures go to Astra; taste or intent failures go
to Fable. A second miss goes back to the seat to fix the brief or
investigate, not another reroll.

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
  separate image model, use `gpt-6.1-sol` at `medium`. The image model does
  the substantive work; this exception never applies to a stage doing its
  own research or implementation. The Gemini lane generates images too
  (`gemini-exec.md`), on a small quota and only when the user sends image
  work there. Which image model suits which job is
  unmeasured.
