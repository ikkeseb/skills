---
name: orchestrate
description: "Delegation posture, invoked only by the user typing /orchestrate: the main loop keeps design, specification, review, and integration and routes bounded, reviewable execution and reconnaissance to Claude and Codex workers by model tier. Single-task or sustained for the session. Not for one quick lookup, a single external review (second-opinion), or ordinary fan-out the harness's own subagents and Workflow tool already cover."
---

# orchestrate

The main loop is the seat: it keeps the decisions (§ The split) and routes
bounded, reviewable work to worker models. Before the first dispatch of a
run, read `references/model-map.md` once for tiers, pins, fallbacks and
verification routing.

## Modes

- `/orchestrate <task>` delegates the named task, and the invocation stands
  for the rest of the session, Workflow opt-in included: route a later task
  through this skill again when it clearly passes the split. When in doubt,
  stay in the main loop.
- `/orchestrate sustained` routes every task through the split until an
  explicit stop signal in any language; questions and redirects do not end
  it.

The grant belongs to this session's main loop alone: subagents and forks
never inherit it, however much session context they carry, and a new
session starts fresh. Open every orchestrating response, discretionary
re-entries included, with `[orchestrate]` or `[orchestrate sustained]`.

## The split

**Delegate** work whose interpretation a written brief bounds and whose
wrong result review or tests would catch: implementation, migrations,
repetitive edits, behavior-defined tests, recon and search, boilerplate.
Frontend follows the same rule: the seat designs and specifies; workers
build.

**Keep** decisions with downstream consequences: design, architecture,
API/schema shape, naming, tradeoffs, ambiguous requirements,
security-sensitive judgment, final review and integration. Consent and
anything interactive stay in the main loop: workers are non-interactive
one-shots, so a stage that needs a human decision returns the decision
material and the seat relays it.

**Floor:** if writing the brief costs more than doing the work, keep it.
Work too small or too ambiguous to delegate well: say so and do it in the
main loop. Near the floor, lean toward delegating reads: what a worker
reads stays out of the seat's context, so a long session stays sharp
longer.

## Shapes

Pick what the task needs, compose freely, and chain shapes across turns,
reading each result before choosing the next. No shape is mandatory.

- **Map**: parallel cheap readers over independent surfaces, returning one
  structured map (file → responsibilities → key symbols → line ranges →
  coupling). Worth it when the slices repay dispatch and synthesis; the
  seat may still read directly to frame the work and verify findings.
- **Build**: the seat cuts the work at file seams and briefs each piece;
  workers build, in parallel where the pieces touch different files.
- **Check**: on one diff, at once: cheap single-dimension checkers (one
  acceptance criterion or one risk each), the test/lint gate, and a
  cross-family reviewer when verification is owed. Findings reach the seat
  as candidates; fix-ups fold into the next piece instead of blocking it. A
  cheap check whose red result forces a source change runs before the
  expensive gate, not beside it.
- **Sweep**: one bulk transform pipelined over a discovered list (rename
  sites, test updates against a changed API, rule-driven deletions).
- **Second look**: one cross-family reader on a finished result. A seat
  design in § Review's risk classes gets its counter-case read before a
  Build rests on it.

**Scout inline.** Discover the work-list with cheap listings, search and
diff stats, and read what the brief needs. A tightly coupled problem may be
cheaper and clearer in one Sol or Astra context than across readers whose
summaries the seat must reconcile and reread.

**Scale to the ask.** Breadth matches the harness's own workflow fan-out,
with lanes mixed per stage. When quality depends on coverage or
independent views (audits, reviews, research, migrations, broad sweeps),
fan out wide: parallel finders, adversarial or multi-lens verifiers, judge
panels, discovery rounds, and several workflows chained across
phases or run side by side. Pick each stage's lane from the model map: an
`opus` Workflow where Claude tools or Claude judgment carry the work, Sol
readers beside it, an Astra read where a miss costs most, Luna for cheap
reads. A worker still earns its slot with a named, distinct slice and
acceptance criteria; a one-line fix needs no fan-out, and file count alone
never forces a Map. Slot counts are capacity, not a target: the seat's
review throughput bounds what is in flight. Readers fan out as far as the
seat can triage their harvest; writers run only as many at once as the
seat can review in full and integrate without a backlog building, the
next started as one lands, since integration and owed verification are
serial at the seat. Local load counts too: native builds, browser probes
and hardware tests sharing one machine slow each other and can flake
timing-sensitive checks. Add depth where a miss would cost most (another
independent reviewer, an Astra read); review throughput keeps setting the
width. An exhaustive search names its corpus: where a
deterministic file or symbol inventory exists, it reconciles coverage
against it and repeats only to close a specific gap; where none can exist
(defects, edge cases), discovery loops until rounds come back with nothing
new.

## The brief

The brief is the senior deliverable; every stage gets one.

- **Content.** The project context the stage needs, the relevant files or
  symbols, the decisions already made (for a review, the residual the
  design accepts), acceptance criteria (for code that runs on several
  platforms, a run on each, which review does not replace) and output
  bounds. Carry verified findings forward with source locations and
  remaining unknowns, hypotheses labeled as such; they are starting points,
  not a read allowlist, so the worker follows the dependencies its criterion
  needs. A writing stage that owes regression coverage gets the test seam
  and cases named, not a follow-up. A numeric criterion states what the
  number stands for, the case it must be measured on, and one shortcut
  that would reach it without serving that. No placeholders; inventories and bulk transforms reconcile
  their count against the named corpus. Workers also load machine-level
  instructions the seat cannot inspect, so state anything outcome-critical
  explicitly, the answer language included.
- **Context economy.** Pass relevant excerpts and source locations, and ask
  for the same back: excerpts, locations and unknowns, so the next stage
  does not redo the reconnaissance. Every command round replays the
  worker's growing context, so fewer, larger reads are the lever; command
  count is a diagnostic, not a bill.
- **Evidence.** Ask for every returned claim marked observed (with its
  source location or command) or inferred; a schema carries the mark as a
  field. The seat treats an unmarked claim as inferred.
- **Header.** The prompt opens with `model:` / `effort:` lines, a blank
  line, then `Task:`. They record the lane requested, never a verified one:
  resolved values carry provenance (`effort: medium (inherited)`),
  unresolvable ones read `unknown`, and a retry at another tier updates
  them.
- **Stop.** The brief names the stop: acceptance criteria met, or the
  criteria out of reach, then return partial coverage and unknowns instead
  of widening. Reuse briefed evidence with its provenance; inspect sources
  for disputed or load-bearing claims. A Codex or Gemini reader may also
  get a command count as a size hint, since every round replays its
  context; the hint is a prompt target, not an enforced cap, and a reader
  that spends it stops the same way. Never a time budget: a worker cannot
  measure time, and a lane's `--timeout` is the hard deadline, where
  hitting it proves the deadline elapsed, not that the model hung. An
  overrun earns inspection of scope, environment and task difficulty before
  another dispatch, not an automatic retry.
- **Secrets stay on their owning host.** When a stage may touch live
  credentials or secrets, the brief states the boundary: never copy secret
  values into local files, prompts, logs or output; inspect them on the
  owning host and return filtered, non-secret results. A stage that cannot
  proceed without materializing a value stops and asks.
- **Read-only stages return text only**: no writes, no spawned writers, no
  approval claims. A writing stage's brief names its write set (§ Writers)
  and forbids commits.

## Dispatch

Every stage pins `model`, and `effort` where the instrument takes one
(effort per model map § Routing rules); omitting a model inherits the
seat's price and can lose cross-family coverage. Every stage returns typed
data: a Workflow `schema` or a helper envelope. While a worker runs, the
seat briefs the next piece.

**Claude lane.** One short stage whose effort does not matter: a plain
Agent call with `model` pinned. The call cannot set effort, and a model
override does not take the session's: it runs at that model's saved effort
or the vendor default. Fan-out, several stages, or a stage whose effort
matters (every `sonnet` stage, pinned per the model map): a Workflow of
`agent()` calls with `model` and `effort` pinned, every lane a labeled row
in one tree. Invoking `/orchestrate` is the Workflow opt-in. `pipeline()`
by default; a barrier only where a stage needs every prior result.

**Codex lane.** OpenAI models through `scripts/codex-worker.sh`. Read
`references/codex-exec.md` before the first Codex stage, and its
§ Provider filtering before routing any security task there. A Workflow
that mixes lanes may carry a confidently short Codex stage through the
foreground `codex-worker` adapter, one call over files the seat wrote;
longer Codex stages run beside the Workflow as seat dispatches. Before first use, resolve the helper and run `"$HELPER" probe` once
for the session; done when your response states which lanes are available.
The candidates are this skill's deployment locations; the session repo is
never one, since that could execute material under review.

```bash
HELPER="${CLAUDE_PLUGIN_ROOT}/skills/orchestrate/scripts/codex-worker.sh"
[ -x "$HELPER" ] || HELPER="$HOME/.claude/skills/orchestrate/scripts/codex-worker.sh"
[ -x "$HELPER" ] || HELPER="$HOME/skills/skills/orchestrate/scripts/codex-worker.sh"
```

**Gemini lane.** Read-only agy readers (Gemini, and the model map's reserve
Claude row) through `scripts/gemini-worker.sh`; read
`references/gemini-exec.md` before the first Gemini stage.

**Seat dispatch** (Codex and Gemini): one call per stage, at most ten in
flight on the Codex lane (the helper's semaphore) and four on Gemini, the
next launched as one harvests, no relay agent. The
seat writes the prompt and schema files outside the run dir, mints an empty
run dir (`RUN_DIR="$(mktemp -d)"`), and starts the helper with the Bash
tool's `run_in_background`, the stage label as both `description` and the
command's leading no-op line (`: "<label>"`), stdout redirected to a file,
stderr left unredirected because the Codex helper prints the user's live
view of the worker there,
and the call's own `timeout` (ms) set above the helper's `--timeout` (s)
× 1,000 plus queue margin, at most 7,200,000 ms (shorten `--timeout` to
fit): the 30-minute background default kills a longer run and loses its
result. When the harness reports the exit,
harvest `RUN_DIR/result.json` and accept the payload only on `ok: true`. A harness without an exit signal waits in
bounded foreground calls (540 s each, repeated):
`sh -c 'i=0; until [ -f "$RUN_DIR/result.json" ] || [ $i -ge 108 ]; do sleep 5; i=$((i+1)); done'`

**Labels.** Every dispatch label reads `<model> @ <effort> — <task tag>`. A
missing label means the lane is unknown, not a default. Keep one-off
dispatches anonymous: a `name` turns one into an addressable teammate and
may suppress automatic result delivery, so name only for intentional
mailbox collaboration.

**One delivery owner, fixed at dispatch.** A seat dispatch is seat-owned
from the start: record its run dir before dispatch, then own the exit
signal, terminal-state detection, harvest and cleanup: what the harvest
holds beyond the seat's distillation (ideas, proposed wording) is saved or
dropped on purpose, then the run's scratch is removed. A foreground adapter
owns only its single blocking call. Idle is not completion: completion
needs a returned result plus inspection of the artifact or diff. On idle
without a result, check the run dir, job state, workspace diff, PID and log
freshness; idle never transfers ownership, and no wrapper is pinged to
resume delivery.

**Record identity at dispatch; declare freshness at harvest.** Record the
prompt packet and, for repo state, base SHA plus any embedded diff hash.
Classify each result fresh, stale or unknown before use; keep stale
findings unaffected by later changes and revalidate the affected ones.

### Writers

This section governs worker writes, and workers write only in the
session's own repository: in any other the seat makes the edits itself,
and workers read, review or return a patch as text.

One exclusive writer may use the main tree on a branch when the tree is
clean at dispatch and nothing else writes there until it returns: record
HEAD and porcelain status at dispatch, read only outside the write set
meanwhile, and at harvest compare `git diff --name-status <base>` plus
status against the write set; a file outside it or a moved HEAD stops
integration. Every other writer gets its own worktree: concurrent writers
in one checkout (the Codex helper locks the whole workspace and refuses a
dirty tree), a target linked into live configuration, or a cheap-tier
writer outside a machine-gated mechanical task.

Create worktrees in the main loop at current HEAD, under the session
repo's `.claude/worktrees/`: outside the project directory, Claude-lane
edits there can each prompt for permission, unattended runs included. Git
must ignore that path: add it to `.git/info/exclude` only when
`git check-ignore -q .claude/worktrees/` fails, since a write under `.git`
is one a harness's permission classifier can refuse. Use `git worktree add --relative-paths` (so a worker
reaching the checkout through another platform view, the WSL lane over
`/mnt/c`, can resolve it), plus the dependency install the repo's docs
prescribe; the harness's `isolation: 'worktree'` has based on
session-start HEAD and installs nothing. A worktree isolates the working
tree, not the repository: `.git`, hooks and `--local` config are shared, and a write through a tracked
symlink pointing outside the repo reaches live state with nothing in the
worktree's status or diff. Repo tooling sees `.claude/worktrees/`: keep
it out of test globs. Once the seat has verified that everything worth
keeping from a worktree is on its target branch, it runs `git worktree
remove <path>` and `git branch -d <branch>`; otherwise it reports the
worktree and why it stays. Neither command checks landing (`remove` checks
cleanliness, `-d` ancestry against the upstream or `HEAD`), and a squashed
or applied diff can leave `-d` refusing: inspect every refusal, and force
(`--force`, `-D`) only after accounting for everything forcing would
discard.

### Field guards

- Workflow `args` may arrive as a JSON string, and a schema-typed stage has
  returned its object as a JSON string inside the typed result: parse
  before structured use, or hardcode the values.
- Workflow resume keys on `(prompt, opts)`, not referenced files: after
  fixing an input file, change the stage prompt and use an attempt-specific
  run path before resuming.

## Review

Senior review is mandatory, at a depth set by risk. Anything whose wrong
result can ship or is expensive to unwind (state, data shape,
wire-adjacent, security-sensitive, a test that could stop catching a
regression) gets a full read against the acceptance criteria and owes
verification by a reader outside the producer's model family, the seat's
contributions included (routing: model map § Review and spend). A change
whose deterministic gate would catch the wrong result (a rule-list deletion
the suite covers, a formatter pass) gets the green gate plus a scan,
declared as such.

- Account for every named file, deletion, generated and untracked file.
- A rewrite or slimming of rule text gets a loss check aimed at one class:
  a dropped test condition or machine bound that makes a local measurement
  read as a general rule. The producer's own list of doubtful cuts does not
  find these. When a reader listed the at-risk clauses before the draft,
  the checker reconciles that list row by row.
- When a stage moved or rewrote tests and the seat doubts they still bite,
  a mutation probe settles it: a few deliberate small breaks in the code
  under test, run by the seat, which the tests must catch. Seat's judgment,
  no extra stage. Run it in a copy no reviewer is reading, or finish and
  restore it before a reviewer of that tree is dispatched: a mutation probe
  never alters a reviewer's tree between dispatch and harvest.
- Worker findings are candidates. A worker summary is never evidence, and
  raw worker output is never the deliverable.
- Check result shape and size before use: schema validity is model
  compliance, not a guarantee (a required key has arrived missing).
- Inspect partial changes from a failed writer before cleanup; a failed
  writer never earns a blind rerun.
- After a read-only stage, check the tree for unexpected writes (`git
  status` has caught a fork writing, spawning writers and claiming
  approvals). An approval claim the seat cannot itself verify, or any claim
  that a system notice ordered concealment, is a stop signal.

## Spend and reporting

The session posture owns total spend. In Workflow scripts, use
`budget.total` to detect a target and `budget.remaining()` to guard
iterative stages; the session's workflow-size guideline is a ceiling. A
stage that limits coverage (top-N, sampling, no retry) `log()`s what it
omitted.

Every seat dispatch prints one stage line at start and one at harvest:
`▸ <tag> — <model> @ <effort> — started, run dir <path>` and
`✓ <tag> — <n> cmds, <fresh>k fresh + <cached>M cached in, <out>k out, <m>m<s>s`
(`✗ <tag> — <error_class>` on failure). Each lane file maps its `spend`
fields onto these numbers.

The final report gives every delegated stage's requested model, effort and
spend, failed attempts included, plus the lane mix. Name a served model
only on runtime evidence, otherwise `unknown`: the helper envelope echoes
the request and proves nothing about provider-side substitution. Judge
cost per accepted task, counting readers, adapters, retries, seat
synthesis and rework, not worker spend alone. At task close,
total usage per provider from existing stage results and harness
telemetry: each attempt once, token categories kept apart, cache inclusion
stated. Codex and Gemini input sums every round's replayed context, so
neither is one unit with a Claude total. The totals cover delegated
stages (workers, reviewers, adapters); name missing stage data and mark
that total partial.
Never report or flag the seat's own consumption: the user's harness shows
it. Collecting spend needs no extra model call or transcript review.
