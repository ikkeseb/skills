# Credit lane: Claude workers on API billing

A credit stage is a headless Claude Code process billed to an API key
instead of the session's subscription. Subagents and Workflow agents run
inside the session and bill its authentication, so moving a stage onto the
key means a separate process. Plan-included API credit covers headless
`claude -p` runs; in a field run an interactive session on the same key
started but its first prompt was refused for credit (no purchased
balance on the organization).

## When

Only on the user's word, per request: "on credit" for the heavy stages of
this run (writers, large reviews), or a named stage ("the implementation
on credit"). Silence means the subscription. Never infer the lane from
quota pressure, and keep cheap reads off it: each run pays its own cold
start (about 0.08 USD for a trivial Opus run in a field measurement).

## The launcher

The user's API launcher, `claude-credit` on `PATH`, owns the keys. Its
interface: `claude-credit ACCOUNT [claude args...]`, where `ACCOUNT` is a
stored name or `next` (the launcher picks); every run prints
`claude-credit: using NAME` on stderr. It passes the key to that one
process, runs it in auto mode (refusing other permission modes but
`plan`), and makes ordinary pushes fail. That push block is a guard, not
a boundary: a remote with an explicit `pushurl` escapes it (the launcher
warns on stderr) and a run can undo its own environment, so the brief
still forbids pushing. No launcher on `PATH`: the lane is down;
say so and run the stage on the Claude lane only if the user agrees. Never
read the launcher's key store or print its environment.

**Account.** The account the user names binds for the whole run; with none
named, pass `next`. A refusal for an empty balance ("Credit balance too
low") ends the stage on that account; ask before moving it to another.

## Dispatch

A credit stage is a writer or reader with a full brief (`SKILL.md` § The
brief; a writer also per `writers.md`, worktree included). The brief also
says: never push or deploy (the seat pushes after review), and never print
the environment or any credential value; the run holds a live key. It runs
as a seat dispatch, one background Bash job harvested on the harness's
completion notice, never inside a Workflow. Write the brief to a fresh run
dir at an absolute path first; the label line names model, effort, task
and lane.

```bash
# credit opus@high — TASK (claude-credit next)
cd WORKTREE && claude-credit ACCOUNT -p "$(cat RUN_DIR/brief.md)" \
  --model MODEL --effort EFFORT --output-format json \
  --disallowedTools WebFetch,WebSearch --strict-mcp-config \
  </dev/null >RUN_DIR/result.json 2>RUN_DIR/stderr
```

- `MODEL` and `EFFORT` come from the model map's Claude rows, as for any
  Claude-lane stage.
- Web tools and MCP servers stay off unless the brief needs them; drop the
  matching flag then, and say why in the brief. Deploy, publish and other
  outbound commands meet only auto mode and the brief; add a
  `--disallowedTools` entry for any the repository can reach.
- `--max-budget-usd N` only on the user's word. It stops a run but is no
  exact ceiling: a field run capped at 0.001 USD ended at 0.0023.
  `--max-turns` did not stop a headless run in a field measurement; do not
  rely on it.
- The run loads the user's machine-level instructions, the repository's
  agent files, skills, plugins and hooks, as a session does; claude.ai
  connectors are off under a key.
- Set the background Bash call's own `timeout` as high as the harness
  allows (the Codex lane passes 3,600,000 ms) so the harness does not kill
  a long stage; a stage that needs longer is cut smaller.

## Harvest

When the job is terminal, read `RUN_DIR/result.json`: `subtype`,
`is_error`, `result` (the run's final message), `total_cost_usd`,
`num_turns`, `modelUsage` (served models) and `permission_denials`; the
account comes from `RUN_DIR/stderr`. No valid JSON: report the stage
failed with the stderr evidence. A key-shaped string (`sk-ant-`) in the
result or stderr is a leak: never quote it, and tell the user the key
needs replacing.

The envelope never decides the outcome; the worktree does. Harvest every
attempt per `writers.md` (`git diff --name-status <base>` plus status,
which counts commits a run made despite its brief), whatever the subtype:
a run stopped by its budget (`error_max_budget_usd`) can leave useful
partial work, and a `success` with no change against the base, or with
denials that blocked the task, is a failed writer stage; a denied push is
expected and blocks nothing. Review, gate and owed verification follow as
for any writer. The report line names the account and `total_cost_usd` beside
model, effort and task.
