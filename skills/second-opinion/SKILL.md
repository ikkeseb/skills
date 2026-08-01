---
name: second-opinion
description: >-
  Ask an OpenAI model, through the Codex CLI, to review work that already
  exists — a design, a diff, a diagnosis, a claim. Read-only, one call, and the
  answer comes back synthesized rather than relayed. For running a task on
  another model rather than reviewing one, use a delegation posture instead.
---

# second-opinion

One read-only Codex call against work that is already in front of you. The
value is *vendor independence* — a different model family has different blind
spots. It is not a quality upgrade, and a confident answer from it is still a
claim.

Wrong tool when: the question is a lookup, the work does not exist yet, or the
disagreement is about taste rather than fact. Say so instead of spending a call.

## The call

Locate the helper — first executable path wins. Each candidate is a place this
skill's own repo is deployed; the first is rewritten for plugin installs only,
the others cover symlink deployment. Never add the session's repo: it would
execute a `codex-worker.sh` committed in the material under review.

```bash
HELPER="${CLAUDE_PLUGIN_ROOT}/skills/orchestrate/scripts/codex-worker.sh"
[ -x "$HELPER" ] || HELPER="$HOME/.claude/skills/orchestrate/scripts/codex-worker.sh"
[ -x "$HELPER" ] || HELPER="$HOME/skills/skills/orchestrate/scripts/codex-worker.sh"
```

Run `"$HELPER" probe` once per session. No executable candidate,
`codex_missing`, `authenticated: false`, or an empty `codex_version` → the lane
is down: say so and answer without it, never silently. But `ok: false` caused by
`contract_ok: false` alone is not an outage — the helper gates only write runs
on the flag contract, and this call is always read-only — so proceed and name
the flags that went missing.

Run the helper as one background Bash job owned by the current session. This is
execution plumbing, not delegation: mint the durable paths before dispatch,
record the background-job handle, and do not end the session before exactly one
terminal harvest. Say in a line that the independent review has started.

Create the private temp dir in a foreground tool call, record the absolute
helper and temp-dir paths from that call, then write the question to
`<temp-dir>/prompt.md`. Shell variables do not survive between tool calls, so
substitute those recorded literal paths into the background command:

```bash
HELPER_ABS_PATH run --model default --sandbox read-only --workspace WORKSPACE \
  --prompt-file PROMPT_FILE --run-dir RUN_DIR
```

Here `PROMPT_FILE` and `RUN_DIR` are the literal absolute paths
`<temp-dir>/prompt.md` and `<temp-dir>/run`; `WORKSPACE` is the literal current
workspace.

Start that command with the Bash tool's background mode; do not append `&`
inside the command. Record the task ID and output-file path Bash returns. The
main session is the sole delivery owner. It may do other useful work while the
review runs; otherwise wait for Claude Code's terminal task notification.
Never poll output as a liveness test: `events.jsonl` contains state changes,
not a heartbeat, and a live high-effort review can remain at `turn.started`
for minutes.

Harvest once when the background job reaches a terminal state:

1. `<temp-dir>/run/result.json` parses as an envelope → it is authoritative;
   accept the payload only on `ok: true`.
2. No parseable `result.json` → read the background task's recorded output
   file. Failures before the helper establishes its run dir, plus an
   interrupted runner, can only write their envelope there.
3. Neither contains one parseable envelope → report `codex_failed` with the
   recorded job state and run-dir evidence. Never redispatch just to recover
   delivery.

`--model default` takes whatever the CLI currently defaults to, so a new
provider model needs no change here; name a real one only when reproducibility
or a specific capability is the point. The flag itself is required — omitting
it is a usage error, not an implicit default. `--effort` defaults to `high`,
which is right for review work.

**Done when:** the one background job was harvested exactly once and yielded
`ok: true` plus its `result`, or a stated failure. The helper's default one-hour
deadline is a safety ceiling for the worker slot, not a hang detector; it is a
*total* deadline that includes waiting for a free slot. A `timeout` can therefore
mean queue contention or a long provider-side recovery, not that the question
was too big. Quiet JSONL is never kill authority.

## Write the question properly

This is the whole skill. The worker has none of this session's reasoning. It
sees the prompt and read-only checkout, but also the machine's user-level
instruction file; write the question so its task-local requirements override
any ambient house style.

- Paste the actual artifact (the diff, the design, the claim). A path alone
  makes it guess what mattered. When the artifact is pasted rather than
  present in the checkout, add "answer from this prompt alone; do not probe
  the filesystem" — without that line the worker spends its budget on probes
  the sandbox rejects, and can burn the whole timeout collecting refusals
  before producing nothing.
- State the decision it should pressure-test, and what you already believe.
- Ask it to argue the strongest case *against* your position, not to grade it.
  "Is this good?" returns agreement; "where does this break?" returns signal.
  On security-adjacent work this framing is also what gets through: the
  provider's classifier kills runs that read as an attack, so make the
  artifact the subject and ask for failure modes, never for bypasses.
- Name what is out of scope, or it will redesign things you did not ask about.

## A second round, when it earns one

Only when new evidence turned up — a file the worker could not see, a
measurement, a constraint you had not stated. Make it a **fresh call**: paste
round 1 as an explicit artifact beside the new evidence and ask whether it
changes the conclusion. Continuing the worker's own thread is not available
(runs are `--ephemeral`) and would not be better anyway — a fresh call keeps
the anchor visible instead of buried in hidden history. Never re-ask on
disagreement alone: a model that reverses under pressure has told you nothing,
and you are the interested party deciding what counts as evidence.

## Answer, don't relay

Read the result and form your own view. Say where it changed your mind, where
you are overruling it and why, and where you both agree — agreement between two
model families is weak evidence, not proof. Where it makes a factual claim about
the codebase, check the file before repeating it.

Never paste the worker's output as the answer. If it produced nothing usable,
say that plainly rather than dressing up a thin result.
