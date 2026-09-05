# Codex lane: platform lanes and failure handling

Read on any failure envelope from `codex-worker.sh`, before the first
dispatch on a Windows machine, and before trusting a write gate or
after-diff in a repo that uses `.gitattributes` filters. The dispatch
contract itself is `codex-exec.md`.

## Platform lanes

**Native Windows read lane.** Codex ≥0.149 spawns every exec command
through `pwsh.exe -Command`, and on read-only runs its exec policy forbids
every command no allow-rule matches. Install the bundled read allowlist
once per machine:

```bash
cp scripts/worker-read.rules "${CODEX_HOME:-$HOME/.codex}/rules/"
```

Rules files load in worker runs (`--ignore-user-config` covers only
`config.toml`) and are evaluated against the pwsh-lowered inner commands,
so the allowlisted reads (`git status/diff/log/show/rev-parse/ls-files/grep`,
`cat`, `rg`, `ls`, `Get-Content`, `Get-ChildItem`, `Select-String`) run
while everything else stays forbidden. The helper appends the constraint
to the task automatically (one plain allowlisted command per exec call, no
pipelines, redirection, separators, subshells or other executables) and
stops the worker as `read_policy_denied` when stderr shows a policy
rejection. Even with the rules file, fan-out reads are fragile on this
lane (a field run lost three of four Map readers), so a machine with a WSL
VM routes reads there too.

**Native Windows write lane** is unsupported: the elevated sandbox turns
multi-CODEX_HOME machines into a logon-failure → UAC loop
(openai/codex#36865), the unelevated token crashes MSYS/Cygwin child
processes, and unpinned, `--ignore-user-config` drops the user's
`[windows]` sandbox choice and workspace-write silently degrades to
read-only behind an `ok` envelope. No worker lane may raise UAC. Escape
hatch: `CODEX_WORKER_NATIVE_WINDOWS_WRITE=elevated` restores the elevated
pin for a deliberately repaired single-CODEX_HOME machine, an explicit
human choice; under it `.git` stays write-denied, so the worker edits
files but cannot stage or commit.

**WSL bridge.** A WSL VM is a Linux lane: landlock sandbox, supported
workspace-write, per-machine verification (probe plus one write e2e)
before trusting it. With `CODEX_WORKER_LANE=wsl` in the machine's
environment (`CODEX_WORKER_WSL_DISTRO` selects a non-default
distribution), every `probe`, `verify` and `run` re-executes inside the VM
and returns the ordinary envelope with `lane: "wsl-bridge"`. Path-valued
options are translated to the drvfs mount, the run dir stays on the
Windows side (`run_dir` Windows, `run_dir_wsl` the VM's view), and a
stopped VM auto-starts on the first call. Nothing is auto-detected: without
the variable the native lane runs; with it a VM that does not answer fails
closed as `wsl_bridge_failed`. Traps the bridge does not absorb:

- The VM's login-shell PATH is what workers see; `codex_missing` under the
  lane means the VM's profile does not export the codex install.
- The interop token follows the Windows session that launched the helper;
  drive the lane from a locally started session, never under sshd.
- Worker-slot semaphores are per VM, not shared with native runs; VM-side
  `$CODEX_HOME/AGENTS.md` and rules residue load in bridged workers; git
  over drvfs is slow, so prefer VM-side checkouts for heavy repos.
- A worktree the worker will use must be created with
  `git worktree add --relative-paths` (or `worktree.useRelativePaths=true`,
  git ≥ 2.48): an absolute gitdir written by Windows git is unreadable from
  the VM, and a VM-created worktree under `/home/...` is invisible to
  Windows git. List and clean worktrees from the side that created them.

## Failure classes

- `rate_limit`: transient. Read-only stages retry once with backoff or
  route to the Claude lane; pick one.
- `auth`, `codex_missing`, `missing_dependency`: lane down; degrade to the
  Claude lane and report it.
- `config`: the invocation is wrong (bad model ID, unsupported effort;
  `api_error` carries the server's text). Fix the call.
- `contract_mismatch`: the CLI dropped a flag the helper passes and a write
  run was refused; read-only workers may proceed. Fix the invocation, then
  `verify`. Not an outage, not retryable.
- `read_policy_denied`: a native-Windows read left the allowlist. Route the
  stage over the WSL lane or re-specify it as plain allowlisted commands;
  never repeat the unchanged native run.
- `wsl_bridge_failed`: no envelope came back from the VM; the message
  carries wsl.exe's diagnostic. A machine problem: fix the VM or unset the
  lane, and say so.
- `unsupported_lane`: native Windows workspace-write. Policy, never
  retryable; route over WSL, the Claude lane or a verified worker host.
- `sandbox_denied`: the OS sandbox degraded under a write run and rejected
  every write while the CLI exited 0. Environment failure, never retryable
  on this machine; check probe's `sandbox_write`, fix the sandbox, or route
  write stages to the Claude lane.
- `base_sha_mismatch`, `git_error`, `workspace_locked`, `dirty_worktree`,
  `unsafe_git_state` (an in-progress merge/rebase/cherry-pick/revert/bisect,
  or `skip-worktree` / `assume-unchanged` index entries hiding changes):
  the workspace is not in the expected state. Fix the orchestration
  (finish or abort the git operation, or give the worker a throwaway
  worktree), not the worker.
- `usage`: the dispatch is malformed (bad flag, unreadable prompt or
  schema, strict-mode lint rejection, non-empty run dir). Fix the call;
  nothing ran and no `run_dir` exists.
- `slot_root_hijacked`: the lock directory is a symlink or owned by another
  user. Local integrity problem: stop and surface it, no retry, no
  degrade.
- `interrupted`: the runner took a termination signal. Whether the worker
  survived is unknown; establish ground truth from the run dir before
  redispatching, and inspect the worktree first on write runs.
- `timeout`, `codex_failed`, `schema`, `slots_exhausted`: judgment call;
  read `run_dir` evidence first. On `codex_failed` or suspicious stderr,
  check § Known stderr signals before deciding.

## Lost delivery

A foreground adapter that dies, returns no JSON, or sits idle after its
run is terminal is a lost delivery, not a paused one: never ping or
re-invoke it. Recover from the orchestrator-minted run dir, the same
terminal-state check a seat harvest uses:

1. `RUN_DIR/result.json` exists: the helper finished and that file is the
   authoritative envelope; gate on `ok`. Done.
2. No `result.json`: read the captured stdout. Failures before the run dir
   passes its gates (`usage`, `codex_missing`, `missing_dependency`) and
   `interrupted` emit their envelope on stdout only, with no `run_dir`
   field. A stdout envelope is the verdict.
3. Neither: the helper died mid-run. Establish death first (helper and
   codex processes gone). Then with a `turn.completed` event in
   `events.jsonl`
   (`jq -Rrse '[split("\n")[] | fromjson? | .type] | index("turn.completed") != null' RUN_DIR/events.jsonl`),
   `RUN_DIR/final.json` holds the model payload: usable but degraded, so
   apply the stage's schema expectations yourself and say the envelope was
   lost. For write runs the workspace diff is the artifact.
4. No `result.json`, no `turn.completed`, no live process: the run died;
   treat as `codex_failed` with `events.jsonl` and `stderr.log` as
   evidence. A live process with a quiet log is not dead; recheck the PID
   before any cleanup.
5. Cleanup is identity-scoped: kill only processes traceable to this run
   (children of the recorded helper PID, or processes whose cwd or args
   reference `RUN_DIR`), never by name-matching.

## Known stderr signals

- `failed to load/renew models cache: missing field supports_reasoning_summaries`
  recurring on every run is harmless noise (stale `~/.codex` models cache
  against a newer CLI schema); do not let it mask the real failure line.
- On Windows, repeated `code-mode host closed its stdout` with exit code
  `-1073741502` (0xC0000142, STATUS_DLL_INIT_FAILED) is an intermittent
  Codex-CLI runtime crash seen under heavy `max`-effort runs. Availability
  failure, not a quality miss: re-route the stage to the Claude lane
  instead of retrying.
- On Windows read-only runs, repeated
  `exec_command failed for ...: CreateProcess { message: "Rejected(\"... blocked by policy\")" }`
  means the exec policy is forbidding every command no allow-rule matches;
  the envelope can still come back `ok: true` with empty results. Fix:
  § Platform lanes, the read allowlist.

## Lossy clean filters

- A lossy clean filter (`.gitattributes` `filter=`, e.g. one stripping
  volatile keys from a config file) breaks both the dirty-tree gate and the
  after-diff. Git compares filtered content, so `git diff` never shows a
  write inside the stripped region, and `git status` shows it only when the
  byte length changes: a bare ` M` against an empty diff. That `M` is what
  the gate refuses on, so such a repo blocks every write run until someone
  `git add`s the file. It looks like stale stat data and is not: git takes
  a size shortcut and never runs the filter.
- The length-preserving case is the dangerous one: invisible to gate and
  after-diff alike, and it survives `checkout`, `restore`, `stash` and
  `reset --hard`, so the worker's change is discarded with the worktree
  rather than merged. To see it, neutralise the driver
  (`git -c filter.<name>.clean=cat diff`, sound only where the filter has
  no smudge side) or compare the file against `git show HEAD:<path>`.
  Injective filters, `filter=lfs` among them, never do this: the blindness
  needs a many-to-one clean transform.
