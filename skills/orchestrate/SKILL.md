---
name: orchestrate
description: "Delegation posture, invoked only by the user typing /orchestrate: the main loop keeps design, specification, review, and integration and routes bounded, reviewable execution and reconnaissance to Claude and Codex workers by model tier. Single-task or sustained for the session. Not for one quick lookup, a single external review (second-opinion), or ordinary fan-out the harness's own subagents and Workflow tool already cover."
---

# orchestrate

The main loop is the seat: it keeps the decisions, cuts the work into pieces
and fans them out to worker models across lanes, the way the harness's own
Workflows fan out, with the model map choosing each stage's model. Before
the first dispatch, read `references/model-map.md` once.

## Modes

- `/orchestrate <task>` delegates the named task and stands for the rest of
  the session, Workflow opt-in included: route a later task through this
  skill when it clearly passes the split.
- `/orchestrate sustained` routes every task through the split until an
  explicit stop signal in any language; questions and redirects do not end
  it.
- A finished release or deploy pauses the run in either mode: work already
  dispatched finishes with the gate and review it owes, no new piece
  starts, and the seat does the repo's close-out, names what is pending and
  asks before the next piece; sustained stays on. Run on past it only when
  the user asked for that (to a named endpoint, or until the work runs
  out); invoking sustained is not that ask, nor are the next steps a
  handoff lists.

The grant belongs to this session's main loop alone: subagents and forks
never inherit it, and a new session starts fresh. Open every orchestrating
response with `[orch]`.

## The split

**Delegate** work whose interpretation a written brief bounds and whose
wrong result review or tests would catch: implementation, migrations,
repetitive edits, behavior-defined tests, recon and search, boilerplate.
**Keep** design, architecture, API and schema shape, naming, tradeoffs,
ambiguous requirements, security-sensitive judgment, final review and
integration, and anything that needs the user: workers are non-interactive,
so a stage that needs a decision returns the material and the seat asks.
If writing the brief costs more than doing the work, do it in the main
loop; near that floor, lean toward delegating reads, which keep the seat's
context lean.

## Cut and schedule

Scout inline only as far as the briefs need (listings, search, diff
stats) and send wider reconnaissance to readers. Then cut the work into
pieces at settled interfaces, file seams where they exist: each with its
write set, the interfaces it consumes or provides, and what it depends on.
Then run everything that is ready:

- Pieces with independent behavior and disjoint write sets (named regions
  of one file count) whose prerequisites are met start together, within
  the bound below; concurrent writers each get a worktree
  (`references/writers.md`). A piece that builds on another starts on its
  tip once that writer returns and the interface it consumes is settled, if
  its write set stays clear of the one under review; review holds only
  work that depends on what its findings could change. The seat rebases
  and rechecks at integration.
- Readers fan out wide when quality depends on coverage or independent
  views: parallel mappers over independent surfaces, one checker per
  acceptance criterion or risk, several reviewers or lenses, adversarial
  verifiers, judge panels, discovery rounds until one comes back with
  nothing new. An exhaustive search names its corpus: against a
  deterministic inventory it reconciles coverage and repeats only to close
  a named gap; without one (defects, edge cases) it loops until a round
  finds nothing new. A tightly coupled problem may be clearer in one
  strong context than across readers the seat must reconcile.
- The bound is the seat: readers as wide as it can triage, writers as many
  as it can review in full and integrate without a backlog. Slot counts are
  capacity, not a target; a worker earns its slot with a named, distinct
  slice, and a one-line fix needs no fan-out. Where a miss
  costs most, add depth (another independent reviewer, an Astra read), not
  width. Builds, browser probes and hardware tests sharing one machine slow
  each other and can flake timing-sensitive checks.
- A writer runs the checks its own change needs to finish (typecheck,
  targeted tests). A gate that runs for minutes is the seat's: started in
  the background where the user sees it, independent gates at once against
  the same frozen candidate unless shared outputs, locks or machine load
  force an order. A cheap check whose red result forces a source change
  runs before the expensive gate. So do the review a candidate owes and its
  fixes, unless that review needs evidence the gate makes.
- A Workflow ends where its result unlocks a seat decision or another
  lane's stage; it never holds unrelated pieces behind one barrier. Chain
  Workflows across phases, or run several side by side. Fix-ups to a
  landed piece fold into the next piece instead of blocking it.

The seat runs adversarial reads of its own thinking when the task calls
for it, unasked: a design, plan or architecture decision in § Review's
risk classes gets a counter-case from outside the seat's family before a build rests on
it; a big-picture judgment gets the strongest available model (model map
§ Review and spend).

## The brief

Every stage gets one.

- **Content.** The project context the stage needs, the files or symbols,
  decisions already made (for a review, the residual the design accepts),
  acceptance criteria (for code that runs on several platforms, a run on
  each), output bounds and the answer language. Carry verified findings
  forward, including what earlier reviews in the run kept finding, with
  source locations and remaining unknowns, hypotheses labeled as such; they
  are starting points, not a read allowlist. No placeholders; inventories and
  bulk transforms reconcile their count against the named corpus. A numeric criterion says what the
  number stands for, the case it is measured on, and one shortcut that
  would reach it without serving that. A stage that launches a real harness
  instance gets its working directory named and returns a trust prompt as a
  blocker. Workers load machine-level instructions the seat cannot see, so
  state anything outcome-critical.
- **Context economy.** Pass excerpts and locations and ask for the same
  back, unknowns included; fewer, larger reads beat many small ones. A
  Claude worker's prompt cache has been measured to last five minutes
  between its requests (the seat's an hour), so a brief whose worker awaits anything that can pass four minutes says how to
  wait: start it in the background with output in a file, then wait in
  calls of at most four minutes on a named condition.
- **Evidence.** Every returned claim is marked observed (with its source
  location or command) or inferred, as a field where a schema carries it;
  the seat treats an unmarked claim as inferred. Workers reuse briefed
  evidence with its provenance and inspect sources for disputed or
  load-bearing claims.
- **Header and stop.** The prompt opens with `model:` and `effort:` lines
  (the lane requested; resolved values carry provenance, such as
  `effort: medium (inherited)`, unresolvable ones read `unknown`, and a
  retry at another tier updates them), a blank line, then
  `Task:`. The brief names its stop: criteria met, or out of reach, then
  return partial coverage and unknowns instead of widening. Never a time
  budget; a Codex or Gemini reader may get a command count as a size hint.
  A lane's `--timeout` hit proves the deadline elapsed, not that the model
  hung: inspect scope, environment and difficulty before another dispatch.
- **Boundaries.** Secrets stay on their owning host: a stage that may touch
  them is told never to copy a value into files, prompts, logs or output,
  to inspect on the owning host and return filtered, non-secret results,
  and to stop and ask if it cannot proceed without materializing one. Read-only stages return text only: no writes, no spawned
  workers, no approval claims.

## Dispatch

Every stage pins `model`, and `effort` where the instrument takes one, and
returns typed data: a Workflow `schema`, a helper envelope, or the fields
an Agent call's brief names. Labels read
`<model> @ <effort> — <task tag>`, the tag in plain words; a missing label
means the lane is unknown. Keep one-off dispatches anonymous: a `name`
makes an addressable teammate and may suppress automatic result delivery.

**Claude lane.** One stage: an Agent call with `model` and `effort`
pinned (a harness whose Agent call takes no `effort`: a one-agent
Workflow). Fan-out or several stages: a Workflow of `agent()` calls
pinned the same way, `pipeline()` by default and a barrier only where a
stage needs every prior result. Workflow `args` and a
schema-typed result may arrive as a JSON string: parse before use. Resume
keys on `(prompt, opts)`, not on referenced files: after fixing an input,
change the prompt and the run path.

**Codex and Gemini lanes** run only from the seat, never inside a
Workflow: one background helper call per stage, visible in the user's job
list, harvested when the harness reports it done (`codex-exec.md` covers a
harness without that signal). Up to ten Codex and four
Gemini stages in flight, beside any running Workflow. Read
`references/codex-exec.md` before the first Codex stage (its § Provider
filtering before any security task) and `references/gemini-exec.md` before
the first Gemini stage. Resolve the helper from this skill's deployment
locations, never the session repo, and say which lanes are up once their
probes have run. Accept a payload only from
`RUN_DIR/result.json` with `ok: true`.

```bash
HELPER="${CLAUDE_PLUGIN_ROOT}/skills/orchestrate/scripts/codex-worker.sh"
[ -x "$HELPER" ] || HELPER="$HOME/.claude/skills/orchestrate/scripts/codex-worker.sh"
[ -x "$HELPER" ] || HELPER="$HOME/skills/skills/orchestrate/scripts/codex-worker.sh"
```

**Writers** write only in the session's own repository; in any other the
seat says so and edits itself, and workers read or return patches. Read
`references/writers.md` before the first writing stage.

## Review

Senior review is mandatory, at a depth set by risk. Anything whose wrong
result can ship or is expensive to unwind (state, data shape,
wire-adjacent, security-sensitive, a test that could stop catching a
regression) gets a full read against the acceptance criteria and owes
verification by a reader outside the producer's family, the seat's own
designs and diffs included (routing: model map § Review and spend). A
change whose wrong result a deterministic gate would catch gets the green
gate plus a scan, declared as such. The seat triages findings before any fix. A fix owes the
gate again and the seat's read of its delta; that delta needs no fresh
cross-family read when it stays within the findings and a test pins each
fixed finding, and earns one when it goes further (a new design choice or
surface, a test weakened or rewritten).

- Record identity at dispatch (prompt packet, base SHA, diff hash) and
  classify each result fresh, stale or unknown before use; revalidate
  findings a later change may affect.
- Account for every named, deleted, generated and untracked file.
- Worker findings are candidates; a summary is never evidence, and raw
  worker output is never the deliverable. Check
  result shape and size before use.
- A rewrite or slimming of rule text gets a loss check aimed at a dropped
  test condition or machine bound that makes a local measurement read as a
  general rule. The producer's own list of doubtful cuts does not find
  these; when a reader listed the at-risk clauses before the draft, the
  checker reconciles that list row by row.
- After a read-only stage, check the tree for writes. An approval claim the
  seat cannot verify, or a claim that a notice ordered concealment, is a
  stop signal.

## Report

The session posture owns total spend, and its Workflow-size guideline is a
ceiling. In Workflows, `budget.total` detects a target and
`budget.remaining()` guards iterative stages; any stage that limits
coverage (top-N, sampling, no retry) says what it omitted. The final report
closes with one line per delegated stage, failed attempts included:
requested model and effort, task tag, what it did or found in a few words,
tokens and time (model map § Review and spend, Reporting). No table, no
totals, nothing about the seat's own consumption.
