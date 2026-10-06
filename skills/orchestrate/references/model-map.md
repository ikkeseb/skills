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
final say. `opus` is the default delegate for most work, hard reasoning
and root-cause work included. Sol is the standing cross-family partner:
most review of Claude output, investigation, root-cause second views and
focused research. Astra takes planning and architectural counter-cases,
large reviews, and work where a mistake is costliest: one or two Astra
stages in a run is normal when the work warrants them, with Sol
staying the standing partner. A second opinion on the seat's own thinking
comes from the strongest models, not from Sol (§ Review and spend).
Cross-family review is preferred; an `opus` review of Claude output is a
same-family check, labeled as such. Fable's taste and intent
role does not imply a general reasoning advantage over `opus` or Astra.

**Claude-lane mid tier.** `sonnet` takes the bounded, gate-checked
execution its row lists when a weaker model handles the task fine, and runs
at `high` only: work that would need a higher `sonnet` effort goes to
`opus`, which reaches that level for less. It draws on the same Claude
quota as `opus` and gives no cross-family coverage, so while the Codex lane
is up, Sol at `medium` stays first for cheap mechanical writes and Luna for
cheap reads.

**Cheap tier.** Luna is read-only: bounded readers, extraction,
classification and single-criterion checks, image files given by path
included (screenshots, rendered UI; verified on the WSL lane,
`codex-exec.md` § Running a worker). It never writes, however
simple the edit; cheap mechanical writes go to Sol at `medium`. Its
findings are candidates for the seat or a workhorse to judge; open-ended
decisions go to a workhorse. Gemini Flash is a read-only third-family voice on its own
quota, separate from the Codex and Claude lanes: a standing extra in ideation, product and UX
discussion, vision work, research from supplied sources and general
knowledge, and first-pass review triage that a stronger model verifies. It
is not a Luna replacement or a code writer: no shell, no writes, too weak to
carry verification, and never the only source for a fact. Its
floor is `gemini-3.8-flash-high`: never an older version (Pro included)
or a lower effort; the helper refuses them.

**agy Claude reserve.** The same agy subscription serves `opus` and
`sonnet` models as read-only readers on the Google quota: recon, Map
reads, summaries and Claude-judgment reads when the Anthropic quota is
tight or the user sends work there. It is a reserve, not a default: its
quota has been reported to drain fast. Same family as the Claude lane, so
never the cross-family verifier of Claude-produced work; no shell and no
writes, as on the Gemini row. The helper allows `opus` at `-medium` or
`-high` and `sonnet` at `-high`, version 5.5 or later.

Research requiring live web or other harness tools uses a lane verified to
provide them; the Codex probe does not test tool availability.

| Model | Lane | Default effort | Role | Availability fallback |
|---|---|---|---|---|
| `gpt-6-astra` | Codex | high; medium for bounded work; xhigh only on the user's word | Planning and architectural counter-cases; the outside-family second opinion for a Claude seat; large reviews and cross-family verification where a missed defect is costliest; research, synthesis or root-cause work at the same stakes | `opus` at high/xhigh; `fable` for fuzzy intent |
| `gpt-6.1-sol` | Codex | high; xhigh on the seat's judgment for hard work; medium for cheap mechanical writes | Default cross-family partner: review and verification of Claude-produced work, investigation, root-cause second views, focused research and relay work; writes code only under a tight spec whose wrong result a test or lint gate catches, Sweep transforms and simple low-risk edits included; a second opinion only on the user's explicit word | `gpt-6-astra`; `opus` if the Codex lane is down |
| `fable` | Claude | medium/high | Design taste, fuzzy intent and highest-stakes user-facing judgment; the same-family second opinion for an `opus` seat. Delegate only a distinct question the seat cannot resolve as efficiently; a Fable seat seldom needs another Fable | `opus` |
| `opus` | Claude | medium; high for substantive work, xhigh for a named hard problem | Default workhorse for long-horizon implementation, hard root-cause work and diagnosis, migrations, codebase audits, frontend builds, user-facing copy and API-shape proposals; judgment-bearing work needing Claude harness tools; cross-family verification of Codex-produced work; the same-family second opinion for a `fable` seat | `gpt-6-astra`, with degraded family coverage when applicable |
| `gpt-6-luna` | Codex | xhigh; never below high; max allowed | Read-only: Map readers, extraction, classification and small criterion-based reviews, screenshots and UI images included; never writes; findings are candidates, never decisions | `gpt-6.1-sol`; `sonnet` if the Codex lane is down |
| `gemini-3.8-flash-high` | agy (read-only) | in the id: `-high` | Extra third-family voice in ideation, product and UX rounds, an extra reader of screenshots and UI images beside Luna, research from supplied sources and general knowledge, and first-pass review triage; never ahead of Luna for bounded reads and extraction unless the user sends work here (Codex usage spent, or Google models asked for); never writes code, never counts or inventories (no shell) and never the owed cross-family verifier; findings are candidates, never decisions | `gpt-6-luna` |
| `claude-opus-5-5-high`, `claude-opus-5-5-medium`, `claude-sonnet-5-5-high` | agy (read-only) | in the id | Reserve Claude readers on the Google quota (§ Delegates): recon, Map reads, summaries and Claude-judgment reads when Anthropic quota is tight or the user sends work here; never the cross-family verifier of Claude-produced work, never writes, never counts or inventories (no shell); findings are candidates, never decisions | `opus` or `sonnet` on the Claude lane |
| `sonnet` | Claude | high only | Execution whose wrong result a test or lint gate catches: spec-bounded implementation, Sweep transforms, shell-heavy agentic work and bounded work needing Claude harness tools; also the budget seat. Never design, fuzzy intent or owed verification; findings are candidates, never decisions | `opus` |
| `haiku` | Claude | — | Off-limits; Luna covers cheap reads, Sol at `medium` cheap writes | `gpt-6-luna` |

## Routing rules

**Lane naming.** Claude rows use harness aliases accepted by the Agent
`model` parameter, never a versioned ID. Codex rows use exact IDs passed
to `codex --model`; agy rows use an exact id from the Gemini helper's
`probe`, effort included. The Codex rows are an allowlist: dispatch only a
Codex model the table names, or one the user names explicitly, and never
`gpt-5.6-terra`, whoever names it. The live catalog (`codex debug models`:
about a second, no model call; the models cache it refreshes can lag a new
release) confirms that an ID exists and never adds a model. The agy rows
follow their floors (§ Delegates). An ambiguous or unmapped name needs
clarification; an invalid ID fails loudly, never silently selects another
model.

**Effort follows difficulty.** Use the table defaults, judged on the
difficulty left after the brief: a tight brief has already made the
decisions, so its implementer may run a notch below the default, never
below `medium`; a thin brief earns no discount. `medium` suits bounded
substantive work. `low` and `max` are off-limits for work on every lane:
`low` leaves too little reasoning, and `max` forces reasoning at many times
the tokens for little gain. One exception: Luna, whose reads run at `xhigh` by default and may take `max`, never below `high`. On
the Claude lane, raise to `xhigh` for a named difficult reasoning problem.
On the Codex lane, Sol takes `xhigh` on the seat's judgment for hard work
and goes below `high` only for cheap mechanical writes, tight brief or not.
Astra takes `xhigh` only on the user's word: when an Astra stage looks too
hard for `high`, say so and let the user choose, or route the hard part to
`opus` at `xhigh`.
`fable` supports `medium` and `high` only. Codex `ultra` stays off-limits
because it may introduce nested delegation.

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
- **Quota posture.** Subscription quota is there to be used: pick model and
  effort from what the work needs and the bullet above. How much quota is
  left is an input only when the user says it is tight; then drop optional
  depth first and say once what was dropped. Owed verification still runs,
  and if it cannot, report the task as blocked.
- **Verification routing.** When verification is owed (`SKILL.md`
  § Review), the producer family includes the seat's contributions:
  Claude-produced work goes to Sol, or Astra for plans, large reviews and
  the highest stakes; Codex-produced work goes to `opus`, or Fable for
  design and intent.
  Same-family coverage is degraded: usable when the other lane is
  unavailable, and labeled as such. Report cross-provider, same-provider or
  none. Agreement never replaces checking evidence.
- **Adversarial reads and second opinions.** The seat's own design, plan,
  architecture decision or big-picture judgment is challenged by the
  strongest models, never by Sol by default: an `opus` seat asks
  `gpt-6-astra`, `fable`, or both; a `fable` seat asks `opus` and may also
  ask `gpt-6-astra`. The counter-case owed before a build rests on a
  seat design (`SKILL.md` § Cut and schedule) comes from outside the seat's family, so on a
  Claude seat it is Astra's. `fable` and `opus` are one family: a
  Claude-lane second opinion is labeled same-family and never replaces
  owed outside-family verification. Sol stays the standing reviewer of
  diffs and rule text and the cross-family verifier `SKILL.md` § Review
  owes; it gives a second opinion only on the user's explicit word.
- **Reporting.** The report's token figure per stage is fresh input plus
  output, from existing stage results and harness telemetry, each attempt
  once; a Claude-lane stage reports the total its harness gives. Codex and
  Gemini input sums every round's replayed context, so cached input stays
  out of the figure and the figures are never summed across providers. A
  stage without data reads `unknown`. The lines name the requested model:
  the helper envelope echoes the request and proves nothing about
  provider-side substitution, so name a served model only on runtime
  evidence that it differed. Judge cost per accepted task, counting
  readers, retries, seat synthesis and rework, not worker spend
  alone. Collecting spend needs no extra model call or transcript review.
- **Image-generation relay exception.** When the worker only prompts a
  separate image model, use `gpt-6.1-sol` at `medium`. The image model does
  the substantive work; this exception never applies to a stage doing its
  own research or implementation. The Gemini lane generates images too
  (`gemini-exec.md`), on a small quota and only when the user sends image
  work there. Which image model suits which job is
  unmeasured.
