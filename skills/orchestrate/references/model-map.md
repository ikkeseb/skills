# Model map

Roles and fallbacks are the contract: routing judgment, not benchmarks.

## Seat

The session model owns design, briefs, cuts and seams, integration and
final review; this map never selects or replaces it. `opus` is the
strongest all-round seat; `fable` may read intent and the big picture a
little better at higher cost; `sonnet` is a budget seat.

## Delegates

`opus` is the default delegate. A same-family reader briefed to argue
against the work is a real adversarial read, an `opus` reader for an
`opus` seat included. A reader from another family adds blind spots the
seat's family does not share, and it is owed, while that lane is up, for
work whose wrong result can ship or is expensive to unwind (state, data
shape, wire-adjacent, security-sensitive, a test that could stop catching
a regression) and for the counter-case to a plan a build will rest on.
Label every review cross-family, same-family or none.

Quality work gets more than one strong model, unasked. The seat puts
`gpt-6-astra` beside `opus` on a plan a build will rest on, and on the
review of any change whose miss could lose data, break security or not be
undone, however small the change; it adds `fable` where taste or intent is
at stake. One or two Astra stages in a run is normal; routine fixes get
none. Sol verifies the rest of what is owed, and an Astra review counts as
the owed verification for what it read. Astra writes and reviews code close to `opus` but
costs more and has weaker taste: a voice beside `opus` and `fable`, not
their replacement.

`sonnet` at `high` takes simpler mechanical delegated work that does not
need `opus`: additional reviews, bounded implementation with a clear
done-criterion, and reads that ask more understanding than `haiku` has. In
doubt, `opus`. Sol at `medium` writes code only for the simplest jobs where
little rides on the result, and `opus` reviews what's important; other
writes go to `sonnet` or `opus`. Cheap reads go to `haiku`. Open-ended
decisions go to a workhorse.

Gemini Flash runs on its own quota and is never the only source for a
fact. The agy Claude rows are a reserve; their quota has been reported to
drain fast. Floors for both: `gemini-exec.md`, `model_floor`.

Rule text and docs (instruction files, skill text, user-facing prose) are
written by the seat, `opus` or `fable`; other models give input and
review, never the wording. Research that needs live web or other harness
tools uses a lane verified to provide them; the Codex probe does not test
tool availability.

| Model | Lane | Default effort | Role | Availability fallback |
|---|---|---|---|---|
| `gpt-6-astra` | Codex | high; medium for bounded work; xhigh only on the user's word | The extra strong voice on quality work: plans and architectural counter-cases, large reviews, thorough implementation, and root-cause, research or synthesis where a missed defect costs most; the outside-family second opinion for a Claude seat | `opus` at high/xhigh; `fable` for fuzzy intent |
| `gpt-6.1-sol` | Codex | high; xhigh on the seat's judgment for hard work; medium for cheap mechanical writes | Standing cross-family reviewer and verifier of Claude-produced work, diffs and rule text included; investigation, root-cause second views, focused research, relay work; writes code only under a tight spec whose wrong result a test or lint gate catches | `gpt-6-astra`; `opus` if the Codex lane is down |
| `fable` | Claude | medium/high | Design taste, fuzzy intent and highest-stakes user-facing judgment; a second opinion beside `opus` or Astra. Delegate only a distinct question the seat cannot resolve as efficiently; a Fable seat seldom needs another Fable | `opus` |
| `opus` | Claude | medium; high for substantive work, xhigh for a named hard problem | Default workhorse: long-horizon implementation, root-cause work, migrations, codebase audits, frontend builds, user-facing copy, API shapes; judgment-bearing work needing Claude harness tools; cross-family verification of Codex-produced work | `gpt-6-astra` |
| `haiku` | Claude | high; xhigh for parallel readers across many files and wide retrieval; never below high | Read-only: parallel readers across many files, retrieval, extraction, classification, small criterion-based reviews, the test of one claimed finding, screenshots and UI images. Also transport for an outside stage inside a Workflow, where it runs the wait script and nothing else. Never writes code or documents, never owed verification | `sonnet` |
| `gemini-3.8-flash-high` | agy (read-only) | in the id: `-high` | Extra third-family voice in ideation, product and UX rounds; extra reader of screenshots and UI images beside `haiku`; research from supplied sources and general knowledge; first-pass review triage. Never ahead of `haiku` for bounded reads unless the user sends work here | `haiku` |
| `claude-opus-5-5-high`, `claude-opus-5-5-medium`, `claude-sonnet-5-5-high` | agy (read-only) | in the id | Reserve Claude readers on the Google quota when Anthropic quota is tight or the user sends work here: recon, parallel reads, summaries, Claude-judgment reads | `opus` or `sonnet` on the Claude lane |
| `sonnet` | Claude | high only | The simpler mechanical work § Delegates names, the same mechanical edit across many files and shell-heavy agentic work included. Never design, fuzzy intent or owed verification | `opus` |

The agy rows never write, never count or inventory (no shell) and are
never the owed cross-family verifier.

## Routing rules

**Lane naming.** Claude rows use harness aliases accepted by the Agent
`model` parameter, never a versioned ID; Codex rows use exact IDs passed
to `codex --model`; agy rows use an exact id from the Gemini helper's
`probe`, effort included. The Codex rows are an allowlist: dispatch only a
Codex model the table or the user names, never `gpt-5.6-terra`, whoever
names it. `codex debug models` confirms an ID exists and never adds a
model; its cache can lag a new release. An ambiguous or unmapped name
needs clarification; an invalid ID fails loudly, never silently selects
another model.

**Effort follows difficulty** left after the brief: a tight brief lets
its implementer run one notch below the table default, never below
`medium` (Sol: `high` outside cheap mechanical writes); a thin brief earns
no discount. `low` and `max` are off-limits on every lane, and Codex `ultra` is
off-limits because it may nest delegation.
`fable` takes `medium` and `high` only. Image relay stages:
`imagegen.md`.

**Escalate a quality miss once.** Name the missed acceptance criterion and
why the next model can resolve it. `haiku` and `sonnet` go to `opus`; a Sol
review miss and reasoning failures go to Astra; taste or intent failures go
to Fable. A second miss goes back to the seat to fix the brief or
investigate, not another reroll.

**Availability fallback** covers a model or lane that is down or
throttled, never a quality miss: take the row's fallback, the Claude lane
during a whole Codex outage, and state the replacement and the coverage
lost.

## Review and spend

- **Quality before price for work that ships.** Take the least costly
  route that meets the acceptance criteria, judged on total work per
  accepted task (reconnaissance, verification, likely rework), never on
  token price alone. Quota is there to be used; it is an input only when
  the user says it is tight, and then optional depth goes first, said
  once. Owed verification still runs, or the task is reported blocked.
- **Verification routing.** The producer family includes the seat's
  contributions: Claude-produced work goes to Sol, or to Astra in the
  cases § Delegates names and for large reviews; Codex-produced work goes to
  `opus`, or Fable for design and intent. With the other lane down, a
  same-family adversarial read is the fallback, labeled same-family.
  Agreement never replaces checking evidence.
- **Second opinions** on the seat's design, plan or big-picture judgment
  come from the strongest models, one or several by stakes, never from Sol
  unless the user says so: an `opus` seat asks Astra, `fable`, `opus` or
  several; a `fable` seat asks `opus` and may add Astra. On a Claude seat
  the owed counter-case before a build is Astra's.
