---
name: second-opinion
description: "Send existing work (a design, diff, diagnosis, or claim) to an OpenAI model through the Codex CLI for one independent read-only review, synthesized back. The work leaves the machine. Not for delegating execution (orchestrate)."
---

# second-opinion

Use one read-only Codex call to pressure-test existing work. Its value is an
independent model family with different blind spots, not automatic authority.
That independence is relative to the producer: when the artifact under review
was itself produced by an OpenAI-lane worker, a Codex review shares its
family — route the independent read to the Claude lane instead, or state the
coverage as same-family.
Do not spend the call on lookups, work that does not exist yet, or taste.
The prompt, and whatever material it quotes, goes to the user's own
OpenAI/Codex account like any other Codex call they run; include only what
the review needs.

## Run the review

Locate this skill bundle's helper; first executable path wins. The plugin-root
candidate is rewritten for Claude Code plugin installs, while the other two
cover symlink deployments. Keep them exact. Never search the session repo,
which could execute code from the material under review.

```bash
HELPER="${CLAUDE_PLUGIN_ROOT}/skills/orchestrate/scripts/codex-worker.sh"
[ -x "$HELPER" ] || HELPER="$HOME/.claude/skills/orchestrate/scripts/codex-worker.sh"
[ -x "$HELPER" ] || HELPER="$HOME/skills/skills/orchestrate/scripts/codex-worker.sh"
```

Run `"$HELPER" probe` once per session. No executable helper,
`codex_missing`, `authenticated: false`, or empty `codex_version` means the
lane is down: state that and continue without it. `contract_ok: false` alone
is not an outage for this read-only call; proceed, naming the missing flags.

In a foreground Bash call, create a private temp directory and record its
literal absolute path plus the helper path. Write a self-contained question to
`<temp-dir>/prompt.md`. Shell variables do not survive tool calls, so replace
every placeholder below with the recorded literal path:

```bash
: "second-opinion MODEL@EFFORT — TOPIC"
HELPER_ABS_PATH run --model gpt-5.6-sol --effort high --sandbox read-only \
  --workspace WORKSPACE --prompt-file PROMPT_FILE --run-dir RUN_DIR
```

`PROMPT_FILE` is `<temp-dir>/prompt.md`, `RUN_DIR` is `<temp-dir>/run`, and
`WORKSPACE` is the current workspace. The no-op first line is the visible
Claude Code background-job label; name the actual model, effort, and topic.

Start this as one Bash background job using the tool's background mode, never
an appended `&`. Record the returned task ID and output-file path, announce
that the independent review started, and retain delivery ownership in the
main session. This is execution plumbing, not delegated delivery; do not end
the session before its terminal harvest. Useful local work may continue
meanwhile. Otherwise wait for Claude Code's terminal-task notification. Never
poll output for liveness:
`events.jsonl` records transitions, not heartbeats, and a healthy high-effort
run may sit at `turn.started` for minutes.

Harvest exactly once after the job is terminal:

1. Parse `<temp-dir>/run/result.json`. It is the authoritative envelope; use
   `result` only when `ok: true`, and report its `spend` beside the finding.
2. If that file is absent or invalid, inspect the recorded background output.
   Failures before run-dir creation and interrupted runners can report only
   there. The file combines a stderr banner with stdout; locate its JSON
   envelope rather than parsing the whole file.
3. If neither location contains an envelope, report `codex_failed` with the
   recorded job state and run-dir evidence. Never redispatch merely to recover
   delivery.

The helper's one-hour total deadline includes queueing. A `timeout` may mean
slot contention or provider recovery; quiet JSONL never authorizes killing the
job. Done means the single job was harvested once and produced `ok: true` plus
`result`, or its failure was stated transparently.

## Preserve review identity

The reviewed subject is the dispatch packet, not whatever exists at harvest.
The prompt file preserves that packet. For repo state, also record the base SHA
and, when embedding a diff, its hash before dispatch.

Before using a finding, classify the review as **fresh** when the subject is
unchanged, **stale** when it moved, or **unknown** when identity cannot be
established. A stale review may still contain unaffected findings; recheck any
finding that depends on changed material against the current artifact, or earn
a new call.

The command pins the current preferred review model and `high` effort;
update that pin here when the preferred review model changes. Explicit user
wording may override either: effort language maps to `--effort`, and a model
name maps to `--model`. Use conversational judgment; ask if the reading is
ambiguous. Invalid values must fail loudly, never substituting a different
model or effort silently.

## Write a useful question

The worker receives only the prompt, a read-only checkout, and machine-level
instructions. Make task-local requirements explicit enough to override
ambient house style:

- Include the artifact or relevant excerpt, not only a path. For prompt-only
  material, say: "answer from this prompt alone; do not probe the filesystem."
- State the decision, your current belief, and the strongest counter-case you
  want tested. Ask where it breaks, not whether it is good.
- When a conclusion depends on repository facts, require `file:line` for each
  factual claim and `unknown` when evidence is missing. Prompt-only reasoning
  needs reasons, not invented citations.
- For security-adjacent reviews, keep the artifact as subject and request
  failure modes, never bypass instructions.
- Name exclusions so the reviewer does not redesign unrelated work.
- Bound the run: a `budget:` line with commands and minutes, and the stop —
  answer from the packet, verify only the claims you dispute. An open bound
  re-audits the repo.

Make a second call only for genuinely new evidence: paste the first result and
new evidence into a fresh prompt, then ask whether the conclusion changes.
Runs are ephemeral, and disagreement alone does not earn another call.

## Synthesize

The main agent owns the answer. Check codebase claims against the files, then
say what changed your view, what you reject and why, and where both reviewers
agree. Cross-model agreement remains weak evidence, not proof. Never relay the
worker output as the answer; if it produced nothing useful, say so plainly.
