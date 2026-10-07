---
name: second-opinion
description: "Send existing work (a design, plan, diff, diagnosis, or claim) to one of the strongest models for one independent read-only review, synthesized back. The session model picks the reader: GPT-6 Astra through the Codex CLI, Fable or Opus through a Claude subagent. The Astra path sends the work off the machine to OpenAI. Not for delegating execution (orchestrate)."
---

# second-opinion

One read-only call per reader pressure-tests existing work; the main agent
synthesizes the answer, and agreement is not authority. Not for lookups,
work that does not exist yet, or taste.

## Route

A second opinion comes from the strongest models, picked by the session's
own model:

- An `opus` session asks `gpt-6-astra`, `fable`, `opus`, or several.
- A `fable` session asks `opus`, and may also ask `gpt-6-astra`.
- Any other session model asks `gpt-6-astra`.

Stakes set how many: a costly plan or review takes more than one reader.
`gpt-6-astra` runs through § Codex path, `fable` and `opus` through
§ Claude path; several readers get one call each over the same packet.
`gpt-6.1-sol` gives a second opinion only on the user's explicit word.

`fable` and `opus` are one model family: label a Claude-path read
same-family, and never let it stand in for outside-family verification the
work owes. When the producer used OpenAI, label the Astra read same-family;
a cross-family Claude review is a separate choice, never an automatic
substitute.

## Packet

In a foreground Bash call, create a private temp directory and record its
literal absolute path, and on the Codex path the helper's; shell variables
do not survive tool calls, so later commands use the literals. Write a
self-contained question (§ The question) to `<temp-dir>/prompt.md`. The
packet as dispatched is the review's subject, not whatever exists at
harvest; for repo state also record the base SHA and the hash of any
embedded diff.

## Codex path

The prompt and everything it quotes go to the user's own OpenAI/Codex
account, so include only what the review needs.

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

**Run** one Bash background job through the tool's background mode,
never an appended `&`, with the Bash call's own `timeout` set to
3,600,000 ms: in an unattended session the 30-minute background default
kills a longer review and loses its result.

```bash
# second-opinion MODEL@high — TOPIC
HELPER_ABS_PATH run --model MODEL --effort high --sandbox read-only \
  --workspace WORKSPACE --prompt-file TEMP_DIR/prompt.md --run-dir TEMP_DIR/run \
  --timeout 3300
```

`MODEL` is `gpt-6-astra`. The no-op first line is the job's visible label:
name the real model, effort and topic. `WORKSPACE` is the current
workspace. The user's explicit wording may change `--model` or `--effort`.
`gpt-6-astra` may run at `medium` for a small bounded review and takes
`xhigh` only when the user names it; a user-named `gpt-6.1-sol` may run at
`xhigh` when the review is hard.
Never use `low` or `max`, and never `gpt-5.6-terra`, whoever names it. Ask when the wording is ambiguous; an invalid value fails loudly and
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
  (stderr lines plus stdout), where early failures report.
- Neither: report `codex_failed` with the job state and run-dir evidence.
  Never redispatch just to recover delivery.

Done when the one job was harvested with `ok: true` and a `result`, or
its failure is stated.

## Claude path

One Agent call with `model` pinned to `fable` or `opus` and `effort` to
`high`, its description `second-opinion MODEL@high — TOPIC`. Its prompt
names the packet file by absolute path and says: read that file and
answer it; this is a read-only review, so write nothing and spawn nothing.
Where the Agent call takes no `effort`, leave it unset and label the
effort `unknown`; spend is `unknown` unless the harness reports it. Its returned text is
the review. A call that returns nothing useful is a stated failure, never
redispatched just to recover delivery.

Done when the one call returned its review, or its failure is stated.

## The question

The reader gets only the prompt, a checkout (read-only by sandbox on the
Codex path, by instruction on the Claude path) and machine-level
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
  output size and stop condition. Leave time out: a worker cannot measure
  it. Answer from the packet, inspect only what tests the conclusion, and at
  the bound return findings plus open questions instead of widening into an
  audit. These are prompt targets; `--timeout` is the separate hard
  deadline.

Another call to a reader that has answered needs genuinely new evidence:
paste the first result and that evidence into a fresh prompt and ask
whether the conclusion changes. Disagreement alone does not earn one.

## Synthesize

Before using a finding, mark the review **fresh** (the dispatched subject
is unchanged), **stale** (it moved) or **unknown** (identity cannot be
established); recheck a finding that depends on moved material against the
current artifact, or earn a new call. Check codebase
claims against the files. The main agent owns the answer: say which reader
gave each review and its family label, what changed your view, what you
reject and why, and where the reviewers agree, which is weak evidence, not
proof. Never relay the worker output as the answer; if it produced nothing
useful, say so.
