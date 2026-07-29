---
name: orchestrate
description: Delegation posture — the main loop keeps everything critical (design, spec, review, integration) and routes mechanical execution to worker models, primarily through dynamic Workflow scripts, across Claude and Codex lanes. Single-task or sustained for the session.
---

# orchestrate

Posture for how the main loop spends itself. Main-loop attention is the
scarce premium resource — spend it on judgment, never on labor. What stays
senior and what delegates is defined in The split below; mechanical execution
routes to worker models per `references/model-map.md` (read it once before
the first delegation of a run).

## The instrument

**Dynamic Workflow scripts are the primary instrument.** Invoking
`/orchestrate` is the explicit opt-in the Workflow tool requires. One-off
subagents or agent teams are a judgment call for work a workflow fits poorly
(e.g. a single delegated stage with nothing to fan out). And when delegation
itself is a poor fit, push back: say so and propose running sequentially in
the main loop instead of forcing the ceremony.

Worker invocations run inside delegated stages (Workflow `agent()` calls or
subagents), with one standing exception: Codex-lane background dispatch,
where the main loop starts the worker helper and harvests its run dir per
the lane's delivery contract — dispatch-and-harvest is delegation mechanics,
not main-loop labor. Doing the work itself in the main loop is legitimate
only as that explicitly declared sequential fallback, never silent drift.
Every delegated stage pins `{model, effort}` explicitly and returns typed
data — Workflow stages via the `schema` option, Codex stages via the
helper's envelope — not prose to re-parse.

## Instrument pitfalls (field-observed)

- **Workflow `args` may arrive JSON-stringified** despite being passed as an
  object. Open scripts that consume structured `args` with
  `if (typeof args === 'string') args = JSON.parse(args)` — or hardcode the
  values as constants.
- **Workflow resume caches on `(prompt, opts)` only.** Fixing a file the
  prompt merely *references* (schema file, prompt file, data file) is
  invisible to the cache: resume replays the stale failure. Bust it by
  editing the stage prompt (e.g. a `[dispatch v2 — <what changed>]` marker),
  and mint attempt-suffixed run dirs/paths so no two attempts share disk
  state.
- **Schema-valid is not real.** A schema-forced recon/inventory stage can
  return syntactically valid placeholder output. Put an anti-stub clause in
  the prompt ("placeholder values are a failed task; reconcile your count
  against a raw `rg -c` run and state both numbers") and sanity-check result
  sizes in the main loop before consuming.
- **Plugin commands with `disable-model-invocation` can't be invoked at all.**
  The flag hides the skill from the model, so even a user-typed slash command
  fails — the run goes through the model's Skill tool, which cannot see it.
  When the user has explicitly asked for that pass, run the command's
  documented underlying script directly via Bash with the same arguments,
  and say that's what happened.
- **A provider can swap the model underneath a running request.** Safety
  classifiers reroute flagged requests to a different model mid-session with
  no error and no signal — on current Claude Code, security work that moves
  from source-code analysis into binary scanning, penetration testing, or
  exploit generation is the known trigger. Partition security work *before*
  dispatch: source-code vulnerability recon may be delegated with an
  explicitly source-only scope; the other three are not dispatched to a lane
  that will silently reroute them, but routed to an instrument that supports
  them or reported as unsupported. When diagnosing anomalous output from a
  security stage, treat a classifier swap as one unverified hypothesis among
  several — a quality drop is not evidence that it happened.
- **Naming a one-off subagent silently disables result delivery.** An
  anonymous Agent-tool dispatch returns its result to the main loop on its
  own; passing `name` switches it into addressable "teammate" mode, where it
  is tracked outside that path entirely (invisible to `TaskList` and
  `TaskOutput`) and delivery depends on the *agent itself* choosing to call
  `SendMessage({to: "main"})`. The dispatcher cannot force that from its
  side — field-confirmed: a named agent finished a trivial task in seconds,
  never sent the message, and met a direct `SendMessage` asking for its
  result with nothing but further `idle_notification`s. So never pass `name`
  to a one-off dispatch; reserve names for genuinely multi-turn addressable
  work, where the mailbox is the point.

## Two worker lanes

- **Claude lane**: Workflow `agent()` calls — the `opus` alias at high effort
  is the default workhorse. Claude-lane calls name aliases, never versioned
  model strings; the map explains why.
- **Codex lane**: OpenAI models through the Codex CLI. All invocation
  mechanics live in `scripts/codex-worker.sh` — the single source of truth;
  never hand-roll `codex` commands in prompts. Read
  `references/codex-exec.md` before authoring the first Codex-lane stage.

Codex-lane preflight: resolve the helper, then run `"$HELPER" probe` once per
session before first use; `codex-exec.md` owns what each outcome means and how
to degrade. Each candidate is a place this skill's own repo is deployed — the
first is rewritten for plugin installs only, the others cover symlink
deployment, and without them the lane is unreachable from every repo but this
one. Never add the session's repo as a candidate: it would execute a
`codex-worker.sh` committed in the material under review. Done when: the
response states which lanes were available.

```bash
HELPER="${CLAUDE_PLUGIN_ROOT}/skills/orchestrate/scripts/codex-worker.sh"
[ -x "$HELPER" ] || HELPER="$HOME/.claude/skills/orchestrate/scripts/codex-worker.sh"
[ -x "$HELPER" ] || HELPER="$HOME/skills/skills/orchestrate/scripts/codex-worker.sh"
```

## Verification coverage

Verification is risk-triggered and the verifier must not share the producer's
model family — including the seat's own. Both rules, and how to report degraded
coverage, live in the routing rules in `references/model-map.md`.

## Spend

The session's posture sets how much may be spent; this skill only says how to
respect it. In Workflow scripts the `budget` global is the mechanism —
`budget.total` is null when no target was set, and `budget.remaining()` is what
a loop-until-budget stage guards on. Respect the session's workflow size
guideline as a real ceiling, not a suggestion. Where a run bounds its own
coverage (top-N, sampling, no-retry), `log()` what was dropped: silent
truncation reads as full coverage in the result.

## Modes

- `/orchestrate <task>` — single-task.
- `/orchestrate sustained` — session posture. Only an explicit user signal
  drops it (`orchestrate off`, `stop orchestrate`, or any unambiguous stop
  signal in any language); mid-session questions or redirects don't. New
  session starts fresh.

Open the first response with the marker `[orchestrate]` /
`[orchestrate sustained]`. When reporting a run, account for each delegated
stage's model and effort as it actually ran — the resolved model, not the
alias, per the provenance rule in `references/model-map.md`; if the Claude
lane's resolution can't be verified this session, give the alias and say so.
No prescribed output format beyond that.

## The split

**Delegate** what can be specced tightly enough that a wrong interpretation
gets caught by review or tests: implementation against a written spec,
migrations, repetitive edits, test-writing against defined behavior,
recon/search sweeps, boilerplate. Frontend is no exception — the main loop
designs and specs it, then the mechanical build-out delegates like anything
else.

**Keep** anything where the decision ripples: design, architecture,
API/schema shape, naming, tradeoffs, ambiguous requirements,
security-sensitive calls — and always final review and integration.

**Floor:** if writing the spec takes longer than doing the work, do it in the
main loop. Small edits are not delegated.

## The contract

- **Good instructions are the senior deliverable.** Every delegated stage
  carries its spec and acceptance criteria in the prompt. Workers start empty of
  *this session's* context — pass the skills, project context, and prior
  decisions they need, or they drift. They are not empty of their own: on both
  lanes a worker is handed the machine's user-level instruction file, content
  this repo neither controls nor sees (measured 2026-07-28 on each lane). Treat
  that as ambient drift rather than context — where a stage's output shape,
  scope, or volume matters, the prompt states it instead of inheriting a house
  rule the dispatcher never read.
- **Senior review is mandatory.** Check every result against its acceptance
  criteria — read the diff, not the worker's summary. "Done" from a worker is
  a claim, not evidence. Never relay raw worker output.
  When the diff is too large to read whole, review is *prioritised*, never
  skipped: cover every file the acceptance criteria name, every deletion, and
  everything security- or data-shape-sensitive, and enumerate untracked and
  generated files rather than reading them. State what got full review and
  what got only a scan — an unreviewed remainder is a declared gap, not a
  silent one. A failed writing worker's partial changes are inspected before
  any cleanup discards them.
- **A writing worker gets its own worktree.** Two writing stages never share a
  checkout, and none is aimed at the tree you are working in: a dotfiles-style
  repo whose files are symlinked into `~/.claude/` or `~/.config/` *is* live
  system state, so a worker writing there reconfigures the running harness
  with nothing for a tree-state check to catch. The isolation is partial —
  `.git` stays shared, and a tracked symlink pointing outside the repo is
  materialized verbatim — so it bounds blast radius without removing the need
  to read the diff.
- **One job, one delivery owner — chosen at dispatch, never switched.**
  A wrapper may deliver a result only while it stays strictly foreground:
  one blocking call, no interim "waiting" turn, until the worker exits. Any
  job that outlives its wrapper's turn (backgrounded, server-tracked,
  detached) is main-loop-harvest from the start: the main loop records a
  durable locator (run dir, task id) *before* dispatch and owns polling,
  terminal-state detection, harvest, and stray cleanup. Wrappers never
  babysit, and idle is never an ownership-transfer event.
- **Idle is not done — idle routes to evidence.** Agent and teammate idle
  notifications are scheduler state, not completion evidence. A stage is
  complete only when it has returned a result and the relevant diff or
  on-disk artifact has been inspected. On idle without a result, go straight
  to ground truth (the recorded locator, job state, workspace diff) — never
  ping the wrapper to resume delivery. The inverse guard stays: a state
  file claiming "running" is not liveness either — verify the PID and log
  freshness before waiting on it.
- **Pipeline, don't idle.** Workflows run in the background — while one runs,
  spec the next piece in the main loop.

## With other active postures

orchestrate owns the instrument, the role split, and worker/provider
selection; it defers everything else.

- **Breadth**: if an active posture authorizes wide exploration, it governs
  how many approaches or rounds — explored through workflows, per this
  posture.
- **Review**: final review and integration are main-loop work and never
  delegate. Producing *evidence* for a review — an independent adversarial
  pass, a second opinion — does delegate, per the routing rules; what cannot
  be delegated is the judgment that acts on it.
- **Unattended sessions**: never ask — default to single-task, log it, and
  keep workflow spend within the session's declared budget and blast-radius
  rules.
