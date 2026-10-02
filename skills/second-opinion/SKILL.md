---
name: second-opinion
description: "Send existing work (a design, plan, diff, diagnosis, or claim) through the Codex CLI to GPT-6.1 Sol, or GPT-6 Astra for plans and the highest stakes, for one independent read-only review, synthesized back. The work leaves the machine. Not for delegating execution (orchestrate)."
---

# second-opinion

One read-only Codex call pressure-tests existing work; the main agent
synthesizes the answer, and agreement is not authority. Not for lookups,
work that does not exist yet, or taste. When the producer used OpenAI, label
coverage same-family; a cross-family Claude review is a separate choice,
never an automatic substitute. The prompt and everything it quotes go to the
user's own OpenAI/Codex account, so include only what the review needs.

## Dispatch

**Helper.** The first executable candidate wins. Keep the three exact,
and never search the session repo, which could execute the material
under review:

```bash
HELPER="${CLAUDE_PLUGIN_ROOT}/skills/orchestrate/scripts/codex-worker.sh"
[ -x "$HELPER" ] || HELPER="$HOME/.claude/skills/orchestrate/scripts/codex-worker.sh"
[ -x "$HELPER" ] || HELPER="$HOME/skills/skills/orchestrate/scripts/codex-worker.sh"
```

Run `"$HELPER" probe` once per session. No executable helper,
`codex_missing`, `authenticated: false` or an empty `codex_version` means
the lane is down: say so and continue without it. `contract_ok: false`
alone is no outage for this read-only call; proceed and name the missing
flags.

**Packet.** In a foreground Bash call, create a private temp directory
and record its literal absolute path and the helper's; shell variables
do not survive tool calls, so later commands use the literals. Write a
self-contained question (§ The question) to `<temp-dir>/prompt.md`. The
packet as dispatched is the review's subject, not whatever exists at
harvest; for repo state also record the base SHA and the hash of any
embedded diff.

**Run** one Bash background job through the tool's background mode,
never an appended `&`, with the Bash call's own `timeout` set to
3,600,000 ms: the 30-minute background default kills a longer review and
loses its result.

```bash
: "second-opinion MODEL@high — TOPIC"
HELPER_ABS_PATH run --model MODEL --effort high --sandbox read-only \
  --workspace WORKSPACE --prompt-file TEMP_DIR/prompt.md --run-dir TEMP_DIR/run \
  --timeout 3300
```

`MODEL` is `gpt-6.1-sol`; use `gpt-6-astra` for a plan or architecture, a
large review, or work where a missed defect is costliest. The no-op first
line is the job's visible label: name the real model, effort and topic.
`WORKSPACE` is the current workspace. The user's explicit wording may
change `--model` or `--effort`; raise to `xhigh` only when the user names
it, since it drains the weekly Codex quota fastest. Never use `low`, `max`
only for a user-named `gpt-6-luna`, and never `gpt-5.6-terra`, whoever names
it. Ask when the wording is ambiguous; an invalid value fails loudly and
is never silently replaced. Record the task ID and
output-file path and say the independent review started. The main session
owns delivery: continue useful local work, otherwise wait for the terminal
notification, and do not end the session before harvest. Never poll output
for liveness: `events.jsonl` logs transitions, not heartbeats, and a
high-effort run can sit at `turn.started` for minutes. The helper's
deadline includes queueing, so a `timeout` may be slot
contention; never kill a job for being quiet.

**Harvest** exactly once, after the job is terminal:
- `<temp-dir>/run/result.json` is the authoritative envelope. Use
  `result` only on `ok: true` and report `spend` beside it; token counts
  are usage, not subscription charges, missing usage is `unknown`, and any
  cost comparison counts failed attempts. Label the model as requested
  unless runtime evidence verifies the served one.
- No valid file: find the JSON envelope in the recorded background output
  (a stderr banner plus stdout), where early failures report.
- Neither: report `codex_failed` with the job state and run-dir evidence.
  Never redispatch just to recover delivery.

Done when the one job was harvested with `ok: true` and a `result`, or
its failure is stated.

## The question

The worker gets only the prompt, a read-only checkout and machine-level
instructions, so state task-local requirements strongly enough to override
ambient house style.

- Include the artifact or excerpt, not just a path. For prompt-only
  material, say: "answer from this prompt alone; do not probe the
  filesystem."
- Give the decision, requirements and evidence before your belief, labeled
  a hypothesis. Ask for an independent assessment first, then the strongest
  counter-case.
- When a conclusion depends on repository facts, each factual claim needs
  `file:line` and `unknown` where evidence is missing; prompt-only
  reasoning needs reasons, not invented citations.
- Security-adjacent reviews keep the artifact as the subject and ask for
  failure modes, never bypass instructions.
- Name exclusions, and bound the run with a `budget:` line: commands,
  minutes, output size and stop condition. Answer from the packet, inspect
  only what tests the conclusion, and at the bound return findings plus open
  questions instead of widening into an audit. These are prompt targets;
  `--timeout` is the separate hard deadline.

A second call needs genuinely new evidence: paste the first result and that
evidence into a fresh prompt and ask whether the conclusion changes.
Disagreement alone does not earn one.

## Synthesize

Before using a finding, mark the review **fresh** (the dispatched subject
is unchanged), **stale** (it moved) or **unknown** (identity cannot be
established); recheck a finding that depends on moved material against the
current artifact, or earn a new call. Check codebase
claims against the files. The main agent owns the answer: say what changed
your view, what you reject and why, and where the reviewers agree, which is
weak evidence, not proof. Never relay the worker output as the answer; if it
produced nothing useful, say so.
