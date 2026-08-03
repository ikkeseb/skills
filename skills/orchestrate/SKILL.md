---
name: orchestrate
description: Delegation posture — the main loop keeps design, specification, review, and integration while routing tightly specified execution through Claude Code and Codex workers. Single-task or sustained for the session.
---

# orchestrate

Main-loop attention is the scarce resource: spend it on judgment, not labor.
The split below decides what delegates. Before the first delegation of a run,
read `references/model-map.md` once for model, effort, fallback, and
verification routing.

## Instrument

Dynamic Workflow scripts are the primary Claude Code instrument; invoking
`/orchestrate` is the explicit opt-in the Workflow tool requires. A one-off
subagent or agent team is appropriate when a workflow fits poorly. If the task
is too small or ambiguous to delegate well, state the sequential fallback and
do it in the main loop.

Workers run inside delegated stages. The standing exception is a background
Codex worker: the main loop may dispatch the helper and later harvest its run
directory because those are delivery mechanics, not delegated labor. Every
stage pins `{model, effort}` and returns typed data: Workflow stages use
`schema`; Codex stages use the helper envelope.

### Field guards

- Workflow `args` may arrive as a JSON string. Parse it before structured use,
  or hardcode the values.
- Workflow resume keys on `(prompt, opts)`, not referenced files. After fixing
  an input file, change the stage prompt and use an attempt-specific run path
  before resuming.
- Schema validity does not prove substantive output. Prompts reject
  placeholders and require a raw-count reconciliation; the main loop checks
  result size before use.
- On current Claude Code, `disable-model-invocation` can hide a skill even from
  a user-typed slash command. If the user explicitly requested that command,
  run its documented underlying script and disclose the fallback.
- A provider may silently reroute security requests. Delegate only explicitly
  source-only vulnerability recon to a lane susceptible to this; route binary
  scanning, penetration testing, and exploit generation elsewhere or report
  them unsupported. Treat a suspected reroute as unverified without evidence.
- Naming a one-off Agent dispatch changes it into an addressable teammate and
  may suppress automatic result delivery. Keep one-offs anonymous; use names
  only when mailbox-based, multi-turn collaboration is intentional.

## Worker lanes

Both lanes are supported execution paths:

- **Claude Code:** Workflow `agent()` calls. Use harness aliases, not versioned
  Claude model IDs. `opus` at high effort is the default workhorse.
- **Codex:** OpenAI models through `scripts/codex-worker.sh`, the sole source of
  invocation mechanics. Never hand-roll `codex` commands in prompts. Read
  `references/codex-exec.md` before the first Codex stage.

Before first Codex use, resolve the helper and run `"$HELPER" probe` once for
the session. `codex-exec.md` defines every outcome and degradation path. These
three candidates are deployment locations for this skill: the first is
rewritten by plugin installs, and the other two cover symlink deployments.
Never add the session repo as a candidate; that could execute material under
review. Done when the response states which lanes were available.

```bash
HELPER="${CLAUDE_PLUGIN_ROOT}/skills/orchestrate/scripts/codex-worker.sh"
[ -x "$HELPER" ] || HELPER="$HOME/.claude/skills/orchestrate/scripts/codex-worker.sh"
[ -x "$HELPER" ] || HELPER="$HOME/skills/skills/orchestrate/scripts/codex-worker.sh"
```

## Verification and spend

Verification is risk-triggered, and its verifier cannot share the producer's
model family, including the senior seat's. Routing and honest degraded-coverage
reporting live in `references/model-map.md`.

The session posture owns total spend. In Workflow scripts, use `budget.total`
to detect a target and `budget.remaining()` to guard iterative stages. Treat
the session workflow-size guideline as a ceiling. If a stage limits coverage
(top-N, sampling, no retry), `log()` what it omitted.

## Modes and reporting

- `/orchestrate <task>` — single task.
- `/orchestrate sustained` — session posture. It ends only on an explicit stop
  signal in any language; questions and redirects do not end it. A new session
  starts fresh.

Open with `[orchestrate]` or `[orchestrate sustained]`. In the final report,
account for every delegated stage's actual model and effort. For Claude aliases,
report the resolved model when verified; otherwise report the alias and say the
resolution is unknown.

## The split

**Delegate** work whose interpretation is bounded by a written specification
and detectable by review or tests: implementation, migrations, repetitive
edits, behavior-defined tests, recon/search, and boilerplate. Frontend follows
the same rule: the main loop designs and specifies; workers build.

**Keep** decisions with downstream consequences: design, architecture,
API/schema shape, naming, tradeoffs, ambiguous requirements, security-sensitive
judgment, final review, and integration.

**Floor:** if specifying the work costs more than doing it, keep it. Do not
delegate small edits.

## Delegation contract

- **The specification is the senior deliverable.** Each stage receives the
  needed project context, decisions, acceptance criteria, and output bounds.
  Workers also inherit machine-level instructions this repo cannot inspect;
  treat those as ambient drift and state anything outcome-critical explicitly.
- **Senior review is mandatory.** Compare the result and diff with the
  acceptance criteria; never relay a worker summary as evidence. If a diff is
  too large for full review, cover every named file, deletion, and
  security/data-shape-sensitive change; enumerate generated and untracked
  files; and declare what received only a scan. Inspect partial changes from a
  failed writer before cleanup.
- **Writers use isolated worktrees.** Writing stages never share a checkout or
  write into the main-loop tree. Repos symlinked into live configuration count
  as live system state. Worktrees still share `.git`, and tracked external
  symlinks remain external, so inspect the diff.
- **Choose one delivery owner at dispatch and never switch.** A wrapper owns a
  strictly foreground blocking call. Anything backgrounded or server-tracked
  is main-loop-harvest from the start: record its durable locator before
  dispatch, then own polling, terminal-state detection, harvest, and cleanup.
  Idle never transfers ownership.
- **Record identity at dispatch; declare freshness at harvest.** Record the
  prompt packet and, for repo state, base SHA plus any embedded diff hash.
  Classify a result as fresh, stale, or unknown before using it. Preserve stale
  findings unaffected by later changes and revalidate affected ones.
- **Idle is not completion.** Completion requires a returned result plus
  inspection of the relevant artifact or diff. On idle without a result, check
  the durable locator, job state, workspace diff, PID, and log freshness; do
  not ping a wrapper to resume delivery.
- **Pipeline rather than wait.** While a worker runs, the main loop specifies
  the next piece.

## Other postures

This skill owns the instrument, role split, and worker/provider selection; it
defers breadth, interaction, teardown, and spend policy. Final judgment remains
main-loop work, while independent evidence for that judgment may delegate.
During unattended work, default this skill to single-task, log that choice, and
stay within the session's budget and blast-radius rules.
