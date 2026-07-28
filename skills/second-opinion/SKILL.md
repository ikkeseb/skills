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

The call blocks the session until the worker returns; one blocking call is what
keeps delivery in one place. Say so in a line before dispatching, so the pause
reads as work rather than a hang.

```bash
DIR="$(mktemp -d)"          # write the question to $DIR/prompt.md first
"$HELPER" run --model default --sandbox read-only --workspace "$PWD" \
  --prompt-file "$DIR/prompt.md" --run-dir "$DIR/run" --timeout 540
```

`--model default` takes whatever the CLI currently defaults to, so a new
provider model needs no change here; name a real one only when reproducibility
or a specific capability is the point. The flag itself is required — omitting
it is a usage error, not an implicit default. `--effort` defaults to `high`,
which is right for review work.

**Done when:** the call returned `ok: true` and its `result`, or a stated
failure. Keep the Bash timeout at 600000 — the helper's 540 fits inside it.
A question needing longer than that is a delegation job, not a second opinion.
Stdout and `--run-dir`'s `result.json` are the same envelope printed from the
same file, so read the file when stdout comes back truncated or garbled — never
re-run the call to get a clean copy. `--timeout` is a *total* deadline that
includes waiting for a free worker slot, so a `timeout` failure can mean the
slots were busy rather than the question being too big — don't report it as the
latter.

## Write the question properly

This is the whole skill. The worker starts empty and sees only the prompt plus
a read-only checkout — it has none of this session's reasoning.

- Paste the actual artifact (the diff, the design, the claim). A path alone
  makes it guess what mattered.
- State the decision it should pressure-test, and what you already believe.
- Ask it to argue the strongest case *against* your position, not to grade it.
  "Is this good?" returns agreement; "where does this break?" returns signal.
  On security-adjacent work this framing is also what gets through: the
  provider's classifier kills runs that read as an attack, so make the
  artifact the subject and ask for failure modes, never for bypasses.
- Name what is out of scope, or it will redesign things you did not ask about.

## Answer, don't relay

Read the result and form your own view. Say where it changed your mind, where
you are overruling it and why, and where you both agree — agreement between two
model families is weak evidence, not proof. Where it makes a factual claim about
the codebase, check the file before repeating it.

Never paste the worker's output as the answer. If it produced nothing usable,
say that plainly rather than dressing up a thin result.
