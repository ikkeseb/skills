#!/usr/bin/env bash
# codex-worker.sh — deterministic runner for one non-interactive Codex CLI worker.
# Single source of truth for the worker invocation: flags, environment,
# concurrency slots, git gates, and result validation all live here, not in
# prompts.
#
# Usage:
#   codex-worker.sh run --model <model|default> --prompt-file <file>
#       --model <model|default>  required. `default` explicitly selects the
#                                CLI's built-in model (NOT config.toml, which
#                                --ignore-user-config bypasses); name a model
#                                when the tier or reproducibility matters.
#       [--effort <level>]  passed through; the server rejects what a model
#                           does not support        (default: high)
#       [--sandbox read-only|workspace-write]               (default: read-only)
#       [--workspace <dir>]                                 (default: $PWD)
#       [--expected-base-sha <sha>]  fail unless HEAD matches at launch time
#       [--schema-file <json-schema file>]  linted locally for OpenAI strict mode
#       [--timeout <seconds>]  TOTAL wall-clock deadline including any
#                              worker-slot queue wait     (default: 3600)
#       [--run-dir <dir>]  caller-minted run dir (must be empty/nonexistent);
#                          lets the orchestrator harvest from disk if the
#                          adapter relaying stdout is lost (default: mktemp)
#   codex-worker.sh probe     auth + CLI contract, no model call
#   codex-worker.sh verify    end-to-end smoke test (one tiny billed run)
#
# Environment (per machine, never per call):
#   CODEX_WORKER_LANE=wsl       native Windows only: run every command inside
#                               the machine's WSL VM (see the WSL lane section)
#   CODEX_WORKER_WSL_DISTRO     VM to use with that lane (default: wsl.exe's
#                               default distribution)
#
# Output: exactly one JSON object on stdout. Everything else goes to stderr.
# Dependencies: Bash and jq for every command; Codex for probe/run/verify;
# git plus shasum or sha256sum for workspace-write runs.
set -euo pipefail

# The recipe's real dependency is this flag surface, not a version number.
# Gating writes on version equality made every routine Codex release a
# self-inflicted outage (the 0.144 pin silently refused every write-capable
# worker) while still passing a same-series release that dropped a flag.
#
# Two rules keep the check honest:
#   * The invocation below uses ONLY these long forms — never a short alias —
#     so "what we check" and "what we send" cannot drift apart.
#   * ALWAYS = passed on every run; these gate write-capable work. CONDITIONAL
#     = passed only for some runs; probe reports them, but a missing one must
#     not block a run that would never have used it (that is the outage the
#     version pin caused, rebuilt).
ALWAYS_EXEC_FLAGS="--ignore-user-config --ephemeral --disable --config
                   --sandbox --cd --json --output-last-message"
ALWAYS_ROOT_FLAGS="--ask-for-approval"
CONDITIONAL_EXEC_FLAGS="--model --output-schema --skip-git-repo-check"
MAX_SLOTS="${CODEX_WORKER_MAX_SLOTS:-4}"
SLOT_WAIT_SECS="${CODEX_WORKER_SLOT_WAIT:-1800}"
# Per-uid suffix + ownership check (ensure_slot_root): a world-writable /tmp
# must not let another user squat the lock tree or plant a symlink there.
SLOT_ROOT="${TMPDIR:-/tmp}/codex-worker-slots-$(id -u)"

ensure_slot_root() {
  mkdir -p "$SLOT_ROOT"
  chmod 700 "$SLOT_ROOT" 2>/dev/null || true
  if [ -L "$SLOT_ROOT" ] || [ ! -d "$SLOT_ROOT" ] || [ ! -O "$SLOT_ROOT" ]; then
    fail_json slot_root_hijacked \
      "$SLOT_ROOT is a symlink or not owned by this user — refusing to use it"
  fi
}

SLOT_DIR="" WS_LOCK="" CODEX_PID="" VERIFY_TMP=""
CODEX_BIN="" WORKSPACE_HASH_BIN="" WORKSPACE_HASH_KIND=""
JQ_BIN="" GIT_BIN=""
GREP_BIN="" HEAD_BIN="" TAIL_BIN="" TR_BIN="" CUT_BIN="" AWK_BIN="" CAT_BIN=""
# Script-scope, not `local`: the EXIT trap fires after the function returns, so
# a function-local would be unbound there and `set -u` would abort the run.
verify_cleanup() { [ -z "${VERIFY_TMP:-}" ] || rm -rf "$VERIFY_TMP"; }
# Unique ownership token: locks are only ever released by their creator, so
# a contender that cached a stale observation can't delete a lock someone
# else just legitimately acquired.
LOCK_TOKEN="$$-$RANDOM-$RANDOM"

FAIL_RUN_DIR=""  # set once the run dir exists; lets every later failure mirror there
fail_json() { # fail_json <error_class> <message> [run_dir]
  local rd="${3:-$FAIL_RUN_DIR}" out
  out="$("$JQ_BIN" -n --arg class "$1" --arg msg "$2" --arg run_dir "$rd" \
    '{ok: false, error_class: $class, error: $msg}
     + (if $run_dir == "" then {} else {run_dir: $run_dir} end)')"
  # Mirror the verdict into the run dir (atomically) so a harvest that never
  # sees stdout still gets the full envelope, not just the model payload.
  if [ -n "$rd" ] && [ -d "$rd" ]; then
    printf '%s\n' "$out" > "$rd/result.json.tmp" 2>/dev/null \
      && mv -f "$rd/result.json.tmp" "$rd/result.json" 2>/dev/null || true
  fi
  printf '%s\n' "$out"
  exit 0
}

# Every command resolves jq here first, so fail_json below always has a binary.
# Same direct-executable contract as resolve_codex: `command -v` would happily
# return a same-name shell function exported from the parent environment.
require_jq() {
  JQ_BIN="$(type -P jq || true)"
  [ -n "$JQ_BIN" ] || {
    printf '{"ok":false,"error_class":"missing_dependency","error":"jq is required"}\n'
    exit 0
  }
}

is_pos_int() { case "${1:-}" in ''|0|*[!0-9]*) return 1 ;; *) return 0 ;; esac; }

is_windows() { case "$(uname -s 2>/dev/null)" in MINGW*|MSYS*|CYGWIN*) return 0 ;; *) return 1 ;; esac; }
current_read_mode() {
  if is_windows; then printf '%s' allowlisted-single-command
  else printf '%s' full-shell
  fi
}

# Native Windows workspace-write is an unsupported lane by default
# (2026-08-17): every elevated sandbox setup rotates the machine-global
# sandbox users' passwords and stores them only in the invoking CODEX_HOME,
# so a second home or runtime on the machine turns each engagement into a
# logon-failure → UAC-setup loop (confirmed in upstream source,
# codex-rs windows-sandbox-rs identity.rs/sandbox_users.rs; openai/codex
# #36865 reports the same loop). The unelevated restricted token is no
# substitute for write workers: MSYS/Cygwin children die in shared-memory
# setup (CreateFileMapping error 5, re-measured 2026-08-17), and repo
# tooling is often bash. Leaving workspace-write unpinned is worse still:
# --ignore-user-config drops the user's `[windows] sandbox` choice, and with
# no implementation selected exec has no OS sandbox there — writes silently
# degrade to rejected-with-ok-envelope (field 2026-08-04, codex 0.146.0;
# stderr shows "patch rejected: writing is blocked by read-only sandbox").
# So write runs fail closed (`unsupported_lane`) and write work routes to
# the Claude lane or a verified macOS/Linux worker. Read-only runs stay
# unpinned and CLI-policy-enforced — measured working, zero sandbox-log
# growth. Escape hatch for a deliberately repaired single-home machine:
# CODEX_WORKER_NATIVE_WINDOWS_WRITE=elevated restores the old elevated pin
# (an explicit human choice, never a default).
WINDOWS_SANDBOX_CONFIG='windows.sandbox="elevated"'
native_windows_write_allowed() {
  [ "${CODEX_WORKER_NATIVE_WINDOWS_WRITE:-}" = "elevated" ]
}

# --- WSL lane (native Windows only) ------------------------------------------
# CODEX_WORKER_LANE=wsl re-executes this helper inside the machine's WSL VM.
# There `uname` is Linux, the landlock sandbox applies, and read runs get the
# full shell — the native lane's unsupported write path and single-command
# read allowlist both disappear. The switch is explicit and per machine (set
# it once the VM's lane has passed runner verification); nothing is
# auto-detected, so an absent or unverified VM can never be trusted silently.
# The VM side runs the plain Linux code path: wsl.exe does not forward the
# Windows environment, so the switch is invisible there and never re-enters.
#
# What crosses the boundary: every path-valued option is translated to the
# VM's drvfs mount (/mnt/<drive>/...); a run dir the caller did not mint is
# minted on the Windows side, so harvest is a local read that survives a VM
# restart; the VM shell is a login shell (user PATH exports usually live in
# profile files — a non-login shell fails as codex_missing); MSYS path
# conversion is suppressed for the call so `/mnt/c/...` arrives verbatim;
# and `-e` skips the VM's default-shell expansion, so no argument is
# expanded twice. The envelope returns with `lane: "wsl-bridge"`, `run_dir`
# rewritten to the Windows path the caller can open, `run_dir_wsl` for
# VM-side diagnosis, and the same rewritten envelope mirrored to
# result.json so stdout and the harvest file stay one authoritative object.
#
# Inherited, not fixed here: the VM's interop token follows the Windows
# session that launched this helper (a session started under sshd carries
# its restrictions into every Windows executable a worker calls through
# interop); worker-slot semaphores live per VM; and a worktree the worker
# should use must carry a relative gitdir (`git worktree add
# --relative-paths`) — the absolute gitdir Windows git writes by default is
# unreadable from the VM (measured 2026-09-01).
wsl_lane_requested() {
  is_windows && [ "${CODEX_WORKER_LANE:-}" = wsl ]
}

to_wsl_path() { # Windows or MSYS path -> /mnt/<drive>/...; fails on non-drive paths
  local mixed drive
  mixed="$(cygpath -m -a -- "$1" 2>/dev/null)" || return 1
  case "$mixed" in [A-Za-z]:/*) ;; *) return 1 ;; esac
  drive="$(printf '%s' "${mixed%%:*}" | "$TR_BIN" '[:upper:]' '[:lower:]')"
  printf '/mnt/%s%s' "$drive" "${mixed#?:}"
}

from_wsl_path() { # /mnt/<drive>/... -> <DRIVE>:/... (mixed form: MSYS and Windows tools both open it)
  local rest drive
  case "$1" in
    /mnt/[A-Za-z]/*|/mnt/[A-Za-z])
      rest="${1#/mnt/}"
      drive="$(printf '%s' "${rest%%/*}" | "$TR_BIN" '[:lower:]' '[:upper:]')"
      rest="${rest#?}"
      printf '%s:%s' "$drive" "${rest:-/}" ;;
    *) printf '%s' "$1" ;;
  esac
}

bridge_to_wsl() { # $@ = this helper's own argv: run|probe|verify [options]
  require_jq
  resolve_text_tools
  local wsl_bin helper_wsl cmd="$1"
  shift
  wsl_bin="$(type -P wsl.exe || true)"
  [ -n "$wsl_bin" ] || fail_json wsl_bridge_failed \
    "CODEX_WORKER_LANE=wsl but wsl.exe is not on PATH"
  helper_wsl="$(to_wsl_path "${BASH_SOURCE[0]}")" \
    || fail_json wsl_bridge_failed "helper path has no drvfs form: ${BASH_SOURCE[0]}"

  # Only path-valued options are translated; everything else passes through.
  local -a argv=()
  local run_dir_win="" run_dir_wsl="" wsl_val
  if [ "$cmd" = run ]; then
    while [ $# -gt 0 ]; do
      case "$1" in
        --workspace|--prompt-file|--schema-file|--run-dir)
          [ $# -ge 2 ] || fail_json usage "missing value for $1"
          wsl_val="$(to_wsl_path "$2")" || fail_json wsl_bridge_failed \
            "$1 has no drvfs form (drive-letter paths only): $2"
          if [ "$1" = --run-dir ]; then
            # Created here so a bridge failure can mirror its verdict into it,
            # as a native failure would; the VM side still enforces emptiness.
            mkdir -p "$2" 2>/dev/null || fail_json usage "cannot create --run-dir: $2"
            run_dir_win="$2"; run_dir_wsl="$wsl_val"
          fi
          argv+=("$1" "$wsl_val"); shift 2 ;;
        *) argv+=("$1"); shift ;;
      esac
    done
    if [ -z "$run_dir_wsl" ]; then
      run_dir_win="$(mktemp -d "${TMPDIR:-/tmp}/codex-worker.XXXXXX")"
      run_dir_wsl="$(to_wsl_path "$run_dir_win")" || fail_json wsl_bridge_failed \
        "the minted run dir has no drvfs form: $run_dir_win"
      argv+=(--run-dir "$run_dir_wsl")
    fi
    FAIL_RUN_DIR="$run_dir_win"
  else
    argv=("$@")
  fi

  local -a wsl_args=()
  [ -z "${CODEX_WORKER_WSL_DISTRO:-}" ] || wsl_args+=(-d "$CODEX_WORKER_WSL_DISTRO")
  local err_file out rc=0
  err_file="$(mktemp)"
  # `$0` carries the helper's VM path into the login shell; the arguments
  # follow it untouched.
  out="$(MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL='*' \
    "$wsl_bin" ${wsl_args[@]+"${wsl_args[@]}"} -e bash -lc 'exec bash "$0" "$@"' \
    "$helper_wsl" "$cmd" ${argv[@]+"${argv[@]}"} 2>"$err_file")" || rc=$?
  # The VM-side helper's stderr (start banner, diagnostics) is replayed so a
  # background job's combined log reads the same as a native run.
  "$CAT_BIN" "$err_file" >&2
  if ! printf '%s' "$out" | "$JQ_BIN" -e 'type == "object"' >/dev/null 2>&1; then
    local diag
    diag="$("$TAIL_BIN" -c 500 "$err_file" 2>/dev/null | "$TR_BIN" -d '\r' || true)"
    rm -f "$err_file"
    fail_json wsl_bridge_failed \
      "wsl.exe exit $rc, no envelope from the VM-side helper: $diag" "$run_dir_win"
  fi
  rm -f "$err_file"
  # jq is a native Windows binary here, so MSYS would rewrite the /mnt/...
  # argument into a Git-install path unless conversion is suppressed.
  out="$(printf '%s' "$out" | MSYS_NO_PATHCONV=1 "$JQ_BIN" -c \
    --arg rd_wsl "$run_dir_wsl" --arg rd_win "$(from_wsl_path "$run_dir_wsl")" \
    '. + {lane: "wsl-bridge"}
     + (if $rd_wsl == "" then {} else {run_dir: $rd_win, run_dir_wsl: $rd_wsl} end)')"
  if [ -n "$run_dir_win" ] && [ -d "$run_dir_win" ]; then
    printf '%s\n' "$out" > "$run_dir_win/result.json.tmp" \
      && mv -f "$run_dir_win/result.json.tmp" "$run_dir_win/result.json"
  fi
  printf '%s\n' "$out"
}

# Same direct-executable contract as resolve_codex/resolve_git, for the text
# tools that shape gate verdicts and diagnostics: an exported same-name shell
# function could otherwise blank the contract-flag probe, hide skip-worktree
# entries from the marked-index grep, or rewrite error classification. These
# tools cannot clean a dirty tree, so this closes verdict integrity, not the
# write gate itself. Remaining bare utilities (ps, find, ls, date, seq, id,
# mktemp, coreutils file ops) are accepted surface. Call after require_jq.
resolve_text_tools() {
  local t bin
  for t in grep head tail tr cut awk cat; do
    bin="$(type -P "$t" || true)"
    [ -n "$bin" ] || fail_json missing_dependency "$t not found on PATH"
    printf -v "${t^^}_BIN" '%s' "$bin"
  done
}

# One-line, bounded, printable-ASCII excerpt of a git listing, for embedding in
# a refusal message. Non-ASCII bytes become '?' so a path in any encoding still
# yields an encodable message.
dirt_excerpt() {
  "$HEAD_BIN" -n 20 "$1" 2>/dev/null | "$TR_BIN" '\n' ';' \
    | LC_ALL=C "$TR_BIN" -c '\40-\176' '?' | "$CUT_BIN" -c 1-300
}

resolve_codex() {
  # Invoke the binary directly: user shells may wrap `codex` in a function
  # that injects extra profile/config flags, which must never reach workers.
  # `command -v` still returns a same-name shell function; `type -P` forces a
  # PATH search and therefore preserves the direct-executable contract.
  CODEX_BIN="$(type -P codex || true)"
  [ -n "$CODEX_BIN" ] || fail_json codex_missing "codex binary not found on PATH"
}

# Same reason as resolve_codex, with teeth: every write gate below is a git
# question, so an exported `git` shell function that lies about the tree would
# turn the whole gate into a formality. Returns non-zero when git is absent —
# read-only runs in a non-repo tolerate that, workspace-write does not.
resolve_git() {
  GIT_BIN="$(type -P git || true)"
  [ -n "$GIT_BIN" ]
}

resolve_workspace_hash() {
  # shasum is present in Git for Windows and preserves the lock-key format
  # used by existing installs. sha256sum is an explicit portable fallback.
  WORKSPACE_HASH_BIN="$(type -P shasum || true)"
  if [ -n "$WORKSPACE_HASH_BIN" ]; then
    WORKSPACE_HASH_KIND=shasum
    return 0
  fi
  WORKSPACE_HASH_BIN="$(type -P sha256sum || true)"
  if [ -n "$WORKSPACE_HASH_BIN" ]; then
    WORKSPACE_HASH_KIND=sha256sum
    return 0
  fi
  WORKSPACE_HASH_KIND=""
  return 1
}

workspace_hash() {
  "$WORKSPACE_HASH_BIN"
}

codex_version() { "$CODEX_BIN" --version 2>/dev/null | "$GREP_BIN" -oE '[0-9]+\.[0-9]+\.[0-9]+' | "$HEAD_BIN" -1 || true; }

# Prints the flags the installed CLI no longer advertises. $1 selects the set:
# "always" (gates writes) or "all" (probe reporting). Empty output means the
# checked surface still holds. Flag presence does not prove unchanged semantics
# — `verify` covers that — but it catches the breakage a version pin was
# standing in for, without blocking on releases that changed nothing.
#
# Matching is token-exact: a plain substring test would let `--model-provider`
# or a deprecation notice satisfy `--model`. A help invocation that fails
# outright is reported as the whole set missing rather than silently passing on
# truncated output.
missing_contract_flags() {
  local scope="${1:-always}" help_exec help_root out="" f
  local exec_set="$ALWAYS_EXEC_FLAGS"
  [ "$scope" != "all" ] || exec_set="$ALWAYS_EXEC_FLAGS $CONDITIONAL_EXEC_FLAGS"

  if ! help_exec="$("$CODEX_BIN" exec --help 2>&1)"; then
    printf '%s' "$(printf '%s' "$exec_set" | "$TR_BIN" -s '[:space:]' ' ')"
    return
  fi
  if ! help_root="$("$CODEX_BIN" --help 2>&1)"; then
    printf '%s' "$(printf '%s' "$ALWAYS_ROOT_FLAGS" | "$TR_BIN" -s '[:space:]' ' ')"
    return
  fi
  for f in $exec_set; do
    printf '%s' "$help_exec" | "$GREP_BIN" -qE -- "(^|[^[:alnum:]_-])$f([^[:alnum:]_-]|$)" || out="$out $f"
  done
  for f in $ALWAYS_ROOT_FLAGS; do
    printf '%s' "$help_root" | "$GREP_BIN" -qE -- "(^|[^[:alnum:]_-])$f([^[:alnum:]_-]|$)" || out="$out $f"
  done
  printf '%s' "${out# }"
}

# One explicit environment allowlist, shared by probe and run. Keeps the
# orchestrator's secrets (cloud creds, tokens) out of workers while preserving
# what Codex itself needs: auth (HOME/CODEX_HOME), TLS/proxy config, and the
# full PATH so worker subprocesses can reach the toolchain. API-key auth vars
# are forwarded only on explicit opt-in (CODEX_WORKER_ALLOW_API_KEY=1): a
# stray key in the parent env must not silently flip workers from
# subscription login to metered API billing.
WORKER_ENV=()
build_worker_env() {
  WORKER_ENV=(HOME="$HOME" PATH="$PATH" TERM=dumb LANG="${LANG:-en_US.UTF-8}")
  local v vars="CODEX_HOME CODEX_CA_CERTIFICATE SSL_CERT_FILE SSL_CERT_DIR CURL_CA_BUNDLE
                HTTP_PROXY HTTPS_PROXY NO_PROXY http_proxy https_proxy no_proxy LC_ALL"
  if [ "${CODEX_WORKER_ALLOW_API_KEY:-0}" = "1" ]; then
    vars="$vars CODEX_API_KEY CODEX_ACCESS_TOKEN"
  fi
  for v in $vars; do
    if [ -n "${!v:-}" ]; then WORKER_ENV+=("$v=${!v}"); fi
  done
}

# --- locks --------------------------------------------------------------------
lock_owner_pid()   { "$CUT_BIN" -d' ' -f1 "$1/owner" 2>/dev/null || true; }
lock_owner_token() { "$CUT_BIN" -d' ' -f2 "$1/owner" 2>/dev/null || true; }

release_lock_dir() { # only the token holder may delete a lock
  [ -n "$1" ] && [ -d "$1" ] || return 0
  [ "$(lock_owner_token "$1")" = "$LOCK_TOKEN" ] && rm -rf "$1" 2>/dev/null || true
}
release_locks() {
  release_lock_dir "$SLOT_DIR"; release_lock_dir "$WS_LOCK"
  SLOT_DIR="" WS_LOCK=""
}

list_descendants() { # $1 = pid; prints every descendant pid
  local kids k
  kids="$(ps -ax -o pid=,ppid= 2>/dev/null | "$AWK_BIN" -v p="$1" '$2 == p {print $1}')"
  for k in $kids; do
    printf '%s\n' "$k"
    list_descendants "$k"
  done
}

kill_worker_group() {
  [ -n "$CODEX_PID" ] || return 0
  # Snapshot descendants BEFORE killing: Codex's PTY backend setsids tool
  # commands into their own process groups, which a plain group kill misses.
  # (Best effort — a double-forked daemon that reparents can still escape.)
  local desc d
  desc="$(list_descendants "$CODEX_PID" || true)"
  kill -TERM -- -"$CODEX_PID" 2>/dev/null || true
  sleep 5
  kill -KILL -- -"$CODEX_PID" 2>/dev/null || true
  for d in $desc; do kill -KILL "$d" 2>/dev/null || true; done
  wait "$CODEX_PID" 2>/dev/null || true
  CODEX_PID=""
}

on_exit() { release_locks; }
on_signal() {
  kill_worker_group
  release_locks
  trap - EXIT
  "$JQ_BIN" -n '{ok: false, error_class: "interrupted", error: "runner received a termination signal"}'
  exit 1
}

# Reclamation is serialized under one lock, and ownership is revalidated
# under that lock immediately before deletion — two waiters can otherwise
# race to delete a slot a third process just legitimately acquired.
reclaim_stale_slots() {
  local lock="$SLOT_ROOT/.reclaim.lock"
  # A crashed reclaimer must not wedge reclamation forever.
  if [ -d "$lock" ] && [ -n "$(find "$lock" -maxdepth 0 -mmin +5 2>/dev/null)" ]; then
    rm -rf "$lock" 2>/dev/null || true
  fi
  mkdir "$lock" 2>/dev/null || return 0
  local d owner_pid
  # All lock dirs (slots and workspace locks) share one reclaim protocol,
  # serialized under this lock, with ownership re-read just before deletion.
  for d in "$SLOT_ROOT"/slot-* "$SLOT_ROOT"/ws-*; do
    [ -d "$d" ] || continue
    owner_pid="$(lock_owner_pid "$d")"
    if [ -n "$owner_pid" ]; then
      kill -0 "$owner_pid" 2>/dev/null || rm -rf "$d" 2>/dev/null || true
    elif [ -n "$(find "$d" -maxdepth 0 -mmin +2 2>/dev/null)" ]; then
      # Ownerless beyond the grace period: a crash between mkdir and the
      # owner write. Fresh ownerless locks are left alone.
      rm -rf "$d" 2>/dev/null || true
    fi
  done
  rmdir "$lock" 2>/dev/null || true
}

acquire_slot() {
  ensure_slot_root
  local waited=0 i slot
  while :; do
    for i in $(seq 1 "$MAX_SLOTS"); do
      slot="$SLOT_ROOT/slot-$i"
      if mkdir "$slot" 2>/dev/null; then
        SLOT_DIR="$slot"
        # Cleanup is armed before ownership is published.
        trap on_exit EXIT
        trap on_signal INT TERM HUP
        printf '%s %s' "$$" "$LOCK_TOKEN" > "$slot/owner"
        return 0
      fi
    done
    reclaim_stale_slots
    [ "$waited" -lt "$SLOT_WAIT_SECS" ] || fail_json slots_exhausted \
      "no worker slot free after ${SLOT_WAIT_SECS}s (max ${MAX_SLOTS} concurrent workers)"
    sleep 10; waited=$((waited + 10))
  done
}

acquire_workspace_lock() { # exclusive per-repository lock for writing workers
  # Key on the git worktree ROOT, not the caller-supplied path — otherwise
  # /repo and /repo/subdir would get different locks for the same tree.
  local ws_root
  ws_root="$("$GIT_BIN" -C "$1" rev-parse --show-toplevel 2>/dev/null || true)"
  [ -n "$ws_root" ] || fail_json git_error "cannot resolve worktree root for $1"
  local key lock tries=0
  resolve_workspace_hash || fail_json missing_dependency \
    "workspace-write requires shasum or sha256sum on PATH"
  key="$(printf '%s' "$ws_root" | workspace_hash | "$CUT_BIN" -c1-16)"
  lock="$SLOT_ROOT/ws-$key"
  while ! mkdir "$lock" 2>/dev/null; do
    # Stale recovery goes through the serialized reclaim protocol; this loop
    # only ever *acquires* via mkdir, so two contenders can't trade deletes.
    reclaim_stale_slots
    tries=$((tries + 1))
    [ "$tries" -lt 3 ] || fail_json workspace_locked \
      "another writing worker holds $ws_root"
    sleep 2
  done
  WS_LOCK="$lock"
  printf '%s %s' "$$" "$LOCK_TOKEN" > "$lock/owner"
}

# Functional write test through the real OS sandbox — dependency presence is
# not write capability: on native Windows every write can be rejected while
# git, jq and the hash tool all pass. So probe measures the actual write
# path the `run` command would use: on native Windows without the elevated
# opt-in that lane is unsupported and probe gates deterministically without
# engaging any sandbox; otherwise one unbilled `codex sandbox` spawn writes
# a marker file in a throwaway dir, with the same sandbox pin `run` uses.
# Child process is native per OS (cmd.exe / /bin/sh) so the verdict
# reflects the sandbox, not MSYS quirks. Verdicts:
# true (marker written), false (write denied, or the sandbox itself failed
# wholesale — both gate write_ready), null (couldn't measure: no `codex
# sandbox` output and no sandbox-failure signature, no shell, spawn failure —
# reported but NOT gating, so an unmeasurable test cannot rebuild the outage
# the version pin used to cause).
SANDBOX_WRITE=null
probe_sandbox_write() {
  local dir out child_bin
  # Native Windows default: the write lane is unsupported (policy comment at
  # WINDOWS_SANDBOX_CONFIG), so gate deterministically WITHOUT engaging any
  # sandbox implementation. Probing elevated from here was the one path that
  # raised UAC in read-only sessions (second-opinion preflight included).
  if is_windows && ! native_windows_write_allowed; then
    SANDBOX_WRITE=false
    return 0
  fi
  # The shell child is deliberate: workers spawn the repo's own (often bash)
  # tooling, so the probe measures what a worker child would get.
  child_bin="$(type -P bash || type -P sh || true)"
  [ -n "$child_bin" ] || return 0
  if is_windows; then
    # `type -P` yields an MSYS path (/usr/bin/bash) that the Windows sandbox's
    # CreateProcessAsUserW cannot resolve ("failed: 2"), turning every probe
    # into a false write-denied (field 2026-08-12). The sandbox needs the
    # native Windows path.
    child_bin="$(cygpath -w "$child_bin" 2>/dev/null || printf '%s' "$child_bin")"
  fi
  local -a args=(sandbox -c 'sandbox_mode="workspace-write"')
  ! is_windows || args+=(-c "$WINDOWS_SANDBOX_CONFIG")
  args+=(-- "$child_bin" -c \
    'echo probe > sbx-probe.txt && echo WROTE || echo DENIED')
  dir="$(mktemp -d)" || return 0
  # Bounded when a timeout binary exists; a missing one keeps probe usable.
  local -a tmo=()
  local tbin; tbin="$(type -P timeout || true)"
  [ -z "$tbin" ] || tmo=("$tbin" 60)
  out="$( (cd "$dir" && env -i "${WORKER_ENV[@]}" \
    ${tmo[@]+"${tmo[@]}"} "$CODEX_BIN" "${args[@]}") 2>"$dir/sbx-stderr.txt" || true)"
  case "$out" in
    *WROTE*)  [ ! -f "$dir/sbx-probe.txt" ] || SANDBOX_WRITE=true ;;
    *DENIED*) SANDBOX_WRITE=false ;;
    *) # No child verdict at all. A wholesale sandbox failure on stderr is a
       # MEASURED broken sandbox, not an unmeasurable probe, so it gates like
       # DENIED (field 2026-08-07, codex 0.146.1: sandbox helper unlaunchable,
       # every exec failed, probe still reported a healthy write lane).
       # Anything else stays null: unmeasurable, deliberately non-gating.
       ! "$GREP_BIN" -q 'sandbox failed' "$dir/sbx-stderr.txt" 2>/dev/null \
         || SANDBOX_WRITE=false ;;
  esac
  rm -rf "$dir"
}

# --- probe --------------------------------------------------------------------
cmd_probe() {
  require_jq
  resolve_text_tools
  resolve_codex
  build_worker_env
  local version authenticated=false auth_mode=login hash_command="" read_mode
  local git_ready=false hash_ready=false write_ready=false
  read_mode="$(current_read_mode)"
  version="$(codex_version)"
  if env -i "${WORKER_ENV[@]}" "$CODEX_BIN" login status >/dev/null 2>&1; then
    authenticated=true
  elif [ "${CODEX_WORKER_ALLOW_API_KEY:-0}" = "1" ] \
       && { [ -n "${CODEX_API_KEY:-}" ] || [ -n "${CODEX_ACCESS_TOKEN:-}" ]; }; then
    # API-key mode is only honoured by `codex exec`, so `login status` can't
    # verify it — report the mode and trust the key's presence.
    authenticated=true auth_mode=api_key
  fi
  if resolve_git; then git_ready=true; fi
  if resolve_workspace_hash; then
    hash_command="$WORKSPACE_HASH_KIND"
    hash_ready=true
  fi
  probe_sandbox_write
  if [ "$git_ready" = true ] && [ "$hash_ready" = true ] \
     && [ "$SANDBOX_WRITE" != false ]; then write_ready=true; fi
  local missing
  missing="$(missing_contract_flags all)"
  "$JQ_BIN" -n --arg v "$version" --arg missing "$missing" \
    --arg read_mode "$read_mode" \
    --arg auth_mode "$auth_mode" --argjson auth "$authenticated" \
    --arg hash_command "$hash_command" --argjson git_ready "$git_ready" \
    --argjson hash_ready "$hash_ready" --argjson write_ready "$write_ready" \
    --argjson sandbox_write "$SANDBOX_WRITE" \
    '{ok: ($auth and ($v != "") and ($missing == "")),
      codex_version: $v,
      authenticated: $auth, auth_mode: $auth_mode,
      contract_ok: ($missing == ""),
      missing_flags: (if $missing == "" then [] else ($missing | split(" ")) end),
      dependencies: {jq: true, git: $git_ready,
        workspace_hash: $hash_ready,
        workspace_hash_command: (if $hash_command == "" then null else $hash_command end)},
      read_mode: $read_mode, lane: "native",
      sandbox_write: $sandbox_write,
      write_ready: $write_ready}'
}

# --- verify -------------------------------------------------------------------
# End-to-end smoke test: one tiny billed read-only run through the real `run`
# path, asserting the whole envelope. This is what a version pin was trying to
# guarantee — flag presence proves the CLI still accepts our invocation, this
# proves the invocation still behaves. Run it after a Codex upgrade instead of
# re-verifying the recipe by hand.
#
# The run is a read canary: a fresh token is written to canary.txt in the
# workspace and the worker is asked to report it. A worker that cannot see
# the workspace (a dead read lane, measured 2026-08-24 on Windows: probe and
# the old capital-of-Norway verify both green while every run came back
# schema-valid but empty) can only guess, so `workspace_read` separates "the
# run completes" from "the worker could read the repo". Same single billed
# call as before.
cmd_verify() {
  require_jq
  resolve_text_tools
  resolve_codex
  local dir out missing verdict token
  missing="$(missing_contract_flags all)"

  # Nothing to learn from a billed run when the invocation is already known
  # broken — report the contract failure and stop.
  if [ -n "$missing" ]; then
    "$JQ_BIN" -n --arg v "$(codex_version)" --arg missing "$missing" \
      '{ok: false, codex_version: $v, contract_ok: false,
        missing_flags: ($missing | split(" ")),
        envelope_ok: false, schema_honoured: false, workspace_read: false,
        error: "contract check failed; skipped the billed run"}'
    return
  fi

  dir="$(mktemp -d)"; VERIFY_TMP="$dir"
  trap verify_cleanup EXIT           # named function, so a TMPDIR containing a
                                     # quote can never become shell injection
  token="canary-$(date +%s)-$$-$RANDOM"
  printf '%s\n' "$token" > "$dir/canary.txt"
  # The prompt deliberately never mentions the response shape, so conformance
  # is evidence that --output-schema actually took effect rather than the model
  # echoing a shape it was shown.
  printf 'Read the file canary.txt in the current working directory and report its exact contents.\n' > "$dir/prompt.md"
  printf '%s\n' '{"type":"object","additionalProperties":false,"required":["canary","confident"],"properties":{"canary":{"type":"string"},"confident":{"type":"boolean"}}}' > "$dir/schema.json"

  out="$(bash "${BASH_SOURCE[0]}" run --model default --effort low \
           --sandbox read-only --workspace "$dir" \
           --prompt-file "$dir/prompt.md" --schema-file "$dir/schema.json" \
           --run-dir "$dir/run" --timeout 300 2>/dev/null || true)"

  # One jq pass over the raw stdout: a non-JSON, empty, or multi-document relay
  # degrades to false instead of failing an --argjson under `set -e`, so verify
  # keeps its promise of exactly one JSON object on stdout.
  verdict="$(printf '%s' "$out" | "$JQ_BIN" -sR --arg token "$token" '
      (try (fromjson? // {}) catch {}) as $_ |
      (. | try fromjson catch {}) as $e |
      {envelope_ok: ($e.ok == true),
       schema_honoured: (($e.result | type) == "object"
                         and ($e.result.canary | type) == "string"
                         and ($e.result.confident | type) == "boolean"),
       workspace_read: ((($e.result.canary // "") | tostring | gsub("^\\s+|\\s+$"; "")) == $token),
       error: ($e.error // "")}' 2>/dev/null \
    || printf '%s' '{"envelope_ok":false,"schema_honoured":false,"workspace_read":false,"error":"unparseable runner output"}')"

  "$JQ_BIN" -n --arg v "$(codex_version)" --argjson d "$verdict" \
    '{ok: ($d.envelope_ok and $d.schema_honoured and $d.workspace_read),
      codex_version: $v, contract_ok: true, missing_flags: [],
      envelope_ok: $d.envelope_ok, schema_honoured: $d.schema_honoured,
      workspace_read: $d.workspace_read}
     + (if $d.error == "" then {} else {error: $d.error} end)'
}

# --- run ----------------------------------------------------------------------
cmd_run() {
  require_jq
  resolve_text_tools
  resolve_codex
  is_pos_int "$MAX_SLOTS" || fail_json usage "CODEX_WORKER_MAX_SLOTS must be a positive integer"
  is_pos_int "$SLOT_WAIT_SECS" || fail_json usage "CODEX_WORKER_SLOT_WAIT must be a positive integer"

  local model="" effort="high" sandbox="read-only" workspace="$PWD"
  local read_mode
  read_mode="$(current_read_mode)"
  local prompt_file="" schema_file="" timeout_secs=3600 expected_sha="" run_dir_opt=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --model|--effort|--sandbox|--workspace|--prompt-file|--schema-file|--timeout|--expected-base-sha|--run-dir)
        [ $# -ge 2 ] || fail_json usage "missing value for $1"
        case "$1" in
          --model)             model="$2" ;;
          --effort)            effort="$2" ;;
          --sandbox)           sandbox="$2" ;;
          --workspace)         workspace="$2" ;;
          --prompt-file)       prompt_file="$2" ;;
          --schema-file)       schema_file="$2" ;;
          --timeout)           timeout_secs="$2" ;;
          --expected-base-sha) expected_sha="$2" ;;
          --run-dir)           run_dir_opt="$2" ;;
        esac
        shift 2 ;;
      *) fail_json usage "unknown argument: $1" ;;
    esac
  done
  [ -n "$model" ] || fail_json usage "--model is required (use 'default' for the CLI's built-in model)"
  [ -f "$prompt_file" ] || fail_json usage "--prompt-file missing or unreadable: $prompt_file"
  [ -z "$schema_file" ] || [ -f "$schema_file" ] || fail_json usage "--schema-file unreadable: $schema_file"
  # OpenAI structured output runs in strict mode: the root must be an object
  # schema (no root anyOf), and every object schema must set
  # additionalProperties:false and list EVERY property key in required
  # (optional keys are expressed as required-but-nullable, never omitted).
  # Violations otherwise surface only as a 400 invalid_json_schema after a
  # full worker startup round-trip — lint locally and fail fast instead.
  # The traversal is schema-keyword-aware (properties/items/anyOf/allOf/
  # $defs/definitions), so a data field literally named "properties" is not
  # mistaken for a schema node. $ref targets outside $defs/definitions are
  # not resolved — those pass the lint and rely on the server check.
  if [ -n "$schema_file" ]; then
    local schema_lint
    schema_lint="$("$JQ_BIN" -r '
      def walk_s($p):
        if type != "object" then empty
        else
          [$p, .],
          ((.properties? // {}) | select(type == "object") | to_entries[]
            | .key as $k | .value | walk_s($p + ["properties", $k])),
          ((.items? // empty) | walk_s($p + ["items"])),
          ((.anyOf? // []) | select(type == "array") | to_entries[]
            | .key as $i | .value | walk_s($p + ["anyOf", $i])),
          ((.allOf? // []) | select(type == "array") | to_entries[]
            | .key as $i | .value | walk_s($p + ["allOf", $i])),
          ((."$defs"? // {}) | select(type == "object") | to_entries[]
            | .key as $k | .value | walk_s($p + ["$defs", $k])),
          ((.definitions? // {}) | select(type == "object") | to_entries[]
            | .key as $k | .value | walk_s($p + ["definitions", $k]))
        end;
      . as $doc
      | [ (if ($doc | type) != "object"
              or ($doc | has("anyOf"))
              or (($doc | has("type")) and $doc.type != "object")
           then "(root): must be a single object schema (type \"object\", no root anyOf)"
           else empty end),
          ($doc | walk_s([])
            | . as [$p, $o]
            | select(($o.type? == "object") or ($o | has("properties")))
            | [ (if $o.additionalProperties != false
                 then "additionalProperties must be false" else empty end),
                ((($o.properties? // {} | keys) - ($o.required? // []))
                 | if length > 0
                   then "required must list: " + join(", ") else empty end) ]
            | select(length > 0)
            | "\(if ($p | length) == 0 then "(root)"
                 else ($p | map(tostring) | join(".")) end): \(join("; "))")
      ] | join(" | ")' "$schema_file" 2>/dev/null)" \
      || fail_json usage "--schema-file is not valid JSON (or not lintable as a JSON Schema): $schema_file"
    [ -z "$schema_lint" ] || fail_json usage \
      "--schema-file violates OpenAI strict mode ($schema_lint) — object root, additionalProperties:false, and required listing every property key"
  fi
  [ -d "$workspace" ] || fail_json usage "--workspace is not a directory: $workspace"
  is_pos_int "$timeout_secs" && [ ${#timeout_secs} -le 6 ] && [ "$timeout_secs" -le 86400 ] \
    || fail_json usage "--timeout must be an integer between 1 and 86400"
  # Allowlist, deliberately. A new effort level cannot break existing calls —
  # nothing asks for a value that does not exist yet — so the staleness risk is
  # a one-line edit made alongside the first caller that wants it. A denylist
  # would instead accept typos, empty strings, and any future level whose
  # delegation or cost behaviour is as unwanted as `ultra`'s.
  case "$effort" in none|minimal|low|medium|high|xhigh|max) ;;
    *) fail_json usage "invalid --effort: $effort (ultra is deliberately unsupported)" ;; esac
  case "$sandbox" in read-only|workspace-write) ;; *) fail_json usage "invalid --sandbox: $sandbox" ;; esac
  if [ "$sandbox" = "workspace-write" ] && [ -z "$expected_sha" ]; then
    fail_json usage "--expected-base-sha is required for workspace-write"
  fi
  # Resolved for every run — the repo probe below needs it — but only
  # workspace-write treats an absent git as fatal.
  resolve_git || true
  if [ "$sandbox" = "workspace-write" ]; then
    [ -n "$GIT_BIN" ] \
      || fail_json missing_dependency "workspace-write requires git on PATH"
    resolve_workspace_hash \
      || fail_json missing_dependency "workspace-write requires shasum or sha256sum on PATH"
  fi

  local in_git=false
  if [ -n "$GIT_BIN" ] \
     && "$GIT_BIN" -C "$workspace" rev-parse --git-dir >/dev/null 2>&1; then in_git=true; fi
  if [ "$in_git" = false ]; then
    [ "$sandbox" = "read-only" ] || fail_json usage \
      "workspace-write requires a git workspace"
    [ -z "$expected_sha" ] || fail_json usage "--expected-base-sha given for a non-git workspace"
  fi
  local run_dir
  if [ -n "$run_dir_opt" ]; then
    # A caller-minted run dir is the durable receipt: the orchestrator knows
    # the path before dispatch, so a lost adapter can't strand the result.
    # Refuse a non-empty dir — reusing one would mix evidence across runs.
    mkdir -p "$run_dir_opt" 2>/dev/null \
      || fail_json usage "cannot create --run-dir: $run_dir_opt"
    [ -z "$(ls -A "$run_dir_opt" 2>/dev/null)" ] \
      || fail_json usage "--run-dir must be empty: $run_dir_opt"
    run_dir="$run_dir_opt"
  else
    run_dir="$(mktemp -d "${TMPDIR:-/tmp}/codex-worker.XXXXXX")"
  fi
  mkdir -p "$run_dir/tmp"
  FAIL_RUN_DIR="$run_dir"

  local effective_prompt_file="$prompt_file"
  if [ "$read_mode" = allowlisted-single-command ] && [ "$sandbox" = read-only ]; then
    effective_prompt_file="$run_dir/tmp/effective-prompt.md"
    "$CAT_BIN" "$prompt_file" > "$effective_prompt_file" \
      || fail_json usage "cannot read --prompt-file: $prompt_file" "$run_dir"
    printf '%s\n' \
      '' \
      '' \
      'Native Windows read contract:' \
      'Use one plain command per exec call from this list: git status/diff/log/show/rev-parse/ls-files/grep; cat; rg; ls; Get-Content; Get-ChildItem; Select-String.' \
      "Express filtering with that command's own flags or use separate calls." \
      'If the task requires a pipeline, redirection, a command separator, a subshell, or another executable, stop and report that this native read lane is insufficient. Do not retry through a different shell.' \
      >> "$effective_prompt_file"
  fi

  # Start banner on stderr: stdout is the envelope channel and stays clean,
  # but a background task's combined output file — and a human peeking at a
  # running job — should see what is running before the terminal envelope.
  printf '[codex-worker] start model=%s effort=%s sandbox=%s run-dir=%s\n' \
    "$model" "$effort" "$sandbox" "$run_dir" >&2

  # --timeout is the TOTAL wall-clock deadline, queue wait included: a
  # foreground caller sizing its tool timeout against --timeout must not be
  # blindsided by a long slot wait that starts before the run clock does.
  local start_ts
  start_ts="$(date +%s)"
  [ "$SLOT_WAIT_SECS" -le "$timeout_secs" ] || SLOT_WAIT_SECS="$timeout_secs"

  # Native Windows workspace-write fails closed before any queue wait — see
  # the policy comment at WINDOWS_SANDBOX_CONFIG (2026-08-17): elevated loops
  # UAC across CODEX_HOMEs, unelevated kills MSYS children, unpinned silently
  # degrades. Read-only stays available; route write stages to the Claude lane.
  if is_windows && [ "$sandbox" = "workspace-write" ] \
     && ! native_windows_write_allowed; then
    fail_json unsupported_lane \
      "native Windows workspace-write workers are unsupported (elevated sandbox loops UAC across CODEX_HOMEs; unelevated breaks MSYS children) — route write stages to the Claude lane, or set CODEX_WORKER_NATIVE_WINDOWS_WRITE=elevated on a deliberately repaired single-home machine" \
      "$run_dir"
  fi

  acquire_slot
  [ "$sandbox" != "workspace-write" ] || acquire_workspace_lock "$workspace"

  if [ "$sandbox" = "workspace-write" ]; then
    # Contract gate runs AFTER the queue wait — the binary can be upgraded
    # underneath a queued worker. A write run on a CLI that no longer accepts
    # one of our flags would fail mid-edit, so refuse up front; reads may
    # proceed (probe reports the same drift). Only the always-passed flags gate:
    # blocking a write because an optional flag it never sends disappeared would
    # rebuild the outage the version pin used to cause.
    local missing
    missing="$(missing_contract_flags always)"
    [ -z "$missing" ] || fail_json contract_mismatch \
      "codex $(codex_version) no longer advertises: $missing — re-verify the recipe before write-capable runs"
  fi

  # Git state is read AFTER the locks: a slot wait can be long, and gating on
  # pre-queue state would let the tree move underneath a queued writer.
  local base_sha="" dirty_before=false
  if [ "$in_git" = true ]; then
    base_sha="$("$GIT_BIN" -C "$workspace" rev-parse HEAD 2>/dev/null || true)"
    [ -n "$base_sha" ] || fail_json git_error "cannot resolve HEAD in $workspace" "$run_dir"
    if [ -n "$expected_sha" ] && [ "$base_sha" != "$expected_sha" ]; then
      fail_json base_sha_mismatch \
        "HEAD is $base_sha, expected $expected_sha — workspace moved" "$run_dir"
    fi
    # stdout and stderr stay separate: a warning on stderr — a flaky fsmonitor
    # hook is the common one — used to be folded into the porcelain output and
    # read as a dirty tree, refusing write runs against a clean one.
    # --no-optional-locks keeps preflight from taking an index lock in someone
    # else's repo. The explicit flags stop repo config from hiding untracked
    # files or dirty submodules from a gate whose job is to see them — and the
    # two -c overrides close the same hole through a third knob the flags don't
    # name. --untracked-files=normal is the mode that consults the untracked
    # cache, core.untrackedCache is settable per repo or globally, and
    # --no-optional-locks suppresses the index write that would refresh a stale
    # one, so this call could neither see the dirt nor repair the staleness.
    # Observed once in the field (2026-07-26): this invocation
    # reported none of three newly created files while -uall, ls-files --others
    # and add -A --dry-run all saw them; overriding either core.untrackedCache
    # or core.fsmonitor restored the truth, and the window then self-healed.
    # Which of the two carried the staleness is unresolved and a lab repro did
    # not reproduce it, so both are disabled rather than guessing. Cost is one
    # full lstat walk per gated dispatch — the right price for admitting a
    # writing worker, since an overwritten pre-existing untracked file leaves
    # the name list unchanged and is unrecoverable from the after-diff.
    local st_out="$run_dir/tmp/git-status.out"
    local st_err="$run_dir/tmp/git-preflight.err"
    local st_rc=0
    "$GIT_BIN" --no-optional-locks -C "$workspace" \
      -c core.untrackedCache=false -c core.fsmonitor=false \
      status --porcelain=v1 \
      --untracked-files=normal --ignore-submodules=none \
      >"$st_out" 2>"$st_err" || st_rc=$?
    [ "$st_rc" -eq 0 ] || fail_json git_error \
      "git status failed in $workspace (exit $st_rc): $("$TAIL_BIN" -c 500 "$st_err")" "$run_dir"
    [ ! -s "$st_out" ] || dirty_before=true

    if [ "$sandbox" = "workspace-write" ]; then
      if [ "$dirty_before" = true ]; then
        # Name the paths. A bare refusal makes the caller re-derive the tree
        # state by hand in someone else's repo; the porcelain it already read
        # is the whole answer. Bounded and forced to printable ASCII so an
        # exotic path cannot produce an unencodable message.
        fail_json dirty_worktree \
          "workspace-write requires a clean tree, untracked files included: $(dirt_excerpt "$st_out")" \
          "$run_dir"
      fi
      # An index entry marked skip-worktree (S) or assume-unchanged (lowercase)
      # is invisible to status, which would make the clean verdict above a lie.
      # Same fsmonitor/untracked-cache override as the status call above: a
      # global core.fsmonitor=true can hang this command past the run deadline,
      # which is only checked after synchronous git calls return (reproduced
      # 2026-08-03: --timeout 2 stuck at 4 s; 0.01 s with the override).
      local flags ls_rc=0
      flags="$("$GIT_BIN" --no-optional-locks -C "$workspace" \
        -c core.untrackedCache=false -c core.fsmonitor=false \
        ls-files --cached -v 2>>"$st_err")" \
        || ls_rc=$?
      [ "$ls_rc" -eq 0 ] || fail_json git_error \
        "git ls-files failed in $workspace (exit $ls_rc): $("$TAIL_BIN" -c 500 "$st_err")" "$run_dir"
      local marked
      marked="$(printf '%s\n' "$flags" | "$GREP_BIN" -E '^([a-z]|S) ' || true)"
      if [ -n "$marked" ]; then
        printf '%s\n' "$marked" > "$run_dir/tmp/git-marked.out"
        fail_json unsafe_git_state \
          "workspace-write refused: index carries skip-worktree or assume-unchanged entries, which hide changes from the clean check: $(dirt_excerpt "$run_dir/tmp/git-marked.out")" \
          "$run_dir"
      fi
      # Committing on top of a paused merge, rebase or bisect corrupts it.
      local gitstate state_path
      for gitstate in MERGE_HEAD CHERRY_PICK_HEAD REVERT_HEAD BISECT_LOG \
                      rebase-merge rebase-apply sequencer; do
        state_path="$("$GIT_BIN" -C "$workspace" rev-parse --path-format=absolute \
          --git-path "$gitstate" 2>/dev/null)" || continue
        if [ -e "$state_path" ]; then
          fail_json unsafe_git_state \
            "workspace-write refused during an in-progress git operation ($gitstate)" \
            "$run_dir"
        fi
      done
    fi
  fi

  local setup_elapsed remaining_secs
  setup_elapsed=$(( $(date +%s) - start_ts ))
  remaining_secs=$(( timeout_secs - setup_elapsed ))
  if [ "$remaining_secs" -lt 1 ]; then
    release_locks; trap - EXIT INT TERM HUP
    fail_json timeout \
      "deadline exhausted before launch (${setup_elapsed}s of ${timeout_secs}s spent on queue wait and gates)" "$run_dir"
  fi

  build_worker_env
  local -a env_args=("${WORKER_ENV[@]}" TMPDIR="$run_dir/tmp")

  # Long forms only, matching ALWAYS_EXEC_FLAGS / ALWAYS_ROOT_FLAGS exactly.
  # Short aliases (-a -s -C -m -c) would make the contract check and the real
  # invocation two different surfaces, so a dropped alias could pass the gate.
  local -a codex_args=(
    --ask-for-approval never exec
    --ignore-user-config
    --ephemeral
    --disable multi_agent
    --config "model_reasoning_effort=\"$effort\""
    --config 'shell_environment_policy.inherit="core"'
    --sandbox "$sandbox"
    --cd "$workspace"
    --json
    --output-last-message "$run_dir/final.json"
  )
  # Native Windows write runs reach this point only under the explicit
  # CODEX_WORKER_NATIVE_WINDOWS_WRITE=elevated opt-in (the default failed
  # closed before the queue wait); the opt-in lane keeps the elevated pin
  # because unpinned workspace-write silently degrades — see the policy
  # comment at WINDOWS_SANDBOX_CONFIG. Read-only runs never carry the pin.
  ! is_windows || [ "$sandbox" != workspace-write ] || codex_args+=(--config "$WINDOWS_SANDBOX_CONFIG")
  # `--model default` is an explicit opt-in to the CLI's built-in model, so a
  # lane call needs no repo change when the provider ships a new one. It is a
  # sentinel rather than a plain omission on purpose: a forgotten --model must
  # stay a usage error, not a silent run on a moving target.
  [ "$model" = default ] || codex_args+=(--model "$model")
  [ -z "$schema_file" ] || codex_args+=(--output-schema "$schema_file")
  # Deliberate non-git runs are allowed for read-only workers only.
  [ "$in_git" = true ] || codex_args+=(--skip-git-repo-check)
  codex_args+=(-)

  # Job control gives the worker its own process group, so teardown can kill
  # the whole tree — Codex's tool subprocesses included — not just the CLI.
  set +e
  set -m
  env -i "${env_args[@]}" "$CODEX_BIN" "${codex_args[@]}" \
    < "$effective_prompt_file" > "$run_dir/events.jsonl" 2> "$run_dir/stderr.log" &
  CODEX_PID=$!
  set +m
  local elapsed=0 timed_out=false read_policy_denied=false
  while kill -0 "$CODEX_PID" 2>/dev/null; do
    if [ "$read_mode" = allowlisted-single-command ] \
       && "$GREP_BIN" -qiE 'CreateProcess.*blocked by policy' \
            "$run_dir/stderr.log" 2>/dev/null; then
      read_policy_denied=true
      kill_worker_group
      break
    fi
    if [ "$elapsed" -ge "$remaining_secs" ]; then
      timed_out=true
      kill_worker_group
      break
    fi
    sleep 5; elapsed=$((elapsed + 5))
  done
  wait "$CODEX_PID" 2>/dev/null
  local exit_code=$?
  CODEX_PID=""
  set -e
  if [ "$read_policy_denied" = false ] \
     && [ "$read_mode" = allowlisted-single-command ] \
     && "$GREP_BIN" -qiE 'CreateProcess.*blocked by policy' \
          "$run_dir/stderr.log" 2>/dev/null; then
    read_policy_denied=true
  fi
  # Post-run tree check for write runs, taken BEFORE the workspace lock is
  # released so no other writer can own the dirt attributed to this worker.
  # ok proves the worker completed a turn, not that it did the work: the tree
  # entered clean, so workspace_changed=false alongside ok=true is an
  # empty-handed worker the orchestrator must inspect, not trust. null: a
  # read-only run, or the status call itself failed (never fail the envelope
  # over diagnostics).
  local workspace_changed=null
  if [ "$sandbox" = "workspace-write" ]; then
    if "$GIT_BIN" --no-optional-locks -C "$workspace" \
        -c core.untrackedCache=false -c core.fsmonitor=false \
        status --porcelain=v1 \
        --untracked-files=normal --ignore-submodules=none \
        > "$run_dir/tmp/git-status-after.out" 2>/dev/null; then
      if [ -s "$run_dir/tmp/git-status-after.out" ]; then
        workspace_changed=true
      else
        workspace_changed=false
      fi
    fi
  fi
  release_locks; trap - EXIT INT TERM HUP

  # Diagnostics parse tolerantly: a killed run can truncate the JSONL, and a
  # malformed line must never prevent the runner from emitting its verdict.
  local turn_completed=false
  if [ -s "$run_dir/events.jsonl" ] \
     && "$JQ_BIN" -Rrse '[split("\n")[] | fromjson? | .type] | index("turn.completed") != null' \
          "$run_dir/events.jsonl" >/dev/null 2>&1; then
    turn_completed=true
  fi
  # Spend: what the stage cost, from the same tolerant parse. The seat reads
  # it beside model and effort; a stage that outruns its budget line is a
  # spec problem to fix before the next dispatch (2026-09-02: one read stage
  # ran 27 command items and 3.4M cumulative input tokens with no budget).
  local spend='{"commands":0,"input_tokens":null,"cached_input_tokens":null,"output_tokens":null,"reasoning_output_tokens":null,"seconds":0}'
  if [ -s "$run_dir/events.jsonl" ]; then
    spend="$("$JQ_BIN" -Rsc --argjson seconds "$(( $(date +%s) - start_ts ))" '
      [split("\n")[] | fromjson?] as $ev
      | ([$ev[] | select(.type == "turn.completed")] | last | .usage // {}) as $u
      | {commands: ([$ev[] | select(.type == "item.completed" and .item.type == "command_execution")] | length),
         input_tokens: ($u.input_tokens // null),
         cached_input_tokens: ($u.cached_input_tokens // null),
         output_tokens: ($u.output_tokens // null),
         reasoning_output_tokens: ($u.reasoning_output_tokens // null),
         seconds: $seconds}' "$run_dir/events.jsonl" 2>/dev/null || printf '%s' "$spend")"
  fi
  local api_error=""
  if [ -s "$run_dir/events.jsonl" ]; then
    api_error="$("$JQ_BIN" -Rrs \
      '[split("\n")[] | fromjson? | select(.type == "error") | .message][0] // "" | .[0:2000]' \
      "$run_dir/events.jsonl" 2>/dev/null || true)"
  fi
  # With a schema, the final message must be one parseable JSON document —
  # `false` and `null` are valid results; validate parse+count, not
  # truthiness. Without a schema, codex writes the final message as plain
  # text: any non-empty message is valid and gets JSON-encoded as a string.
  local result_ok=false
  if [ -n "$schema_file" ]; then
    if [ -s "$run_dir/final.json" ] \
       && "$JQ_BIN" -es 'length == 1' "$run_dir/final.json" >/dev/null 2>&1; then
      result_ok=true
    fi
  elif [ -s "$run_dir/final.json" ]; then
    result_ok=true
  fi

  local ok=false error_class="" error=""
  if [ "$read_policy_denied" = true ]; then
    error_class=read_policy_denied
    error="native Windows read command rejected by the exec-policy allowlist; route the stage through a verified WSL bridge, or re-specify it as plain allowlisted commands"
  elif [ "$timed_out" = true ]; then
    error_class=timeout; error="worker exceeded the ${timeout_secs}s total deadline (${setup_elapsed}s of it queue wait and gates)"
  elif "$GREP_BIN" -q 'orchestrator_helper_launch_failed' "$run_dir/stderr.log" 2>/dev/null; then
    # The OS sandbox could not launch its helper, so command spawns failed
    # while the CLI still completed the turn — the model answers from the
    # prompt alone and the envelope would read ok. Applies to read-only runs
    # too (the field case). Matched against codex's own stderr tracing, never
    # tool output, so a worker merely reading about this failure cannot trip
    # it. Deterministic environment failure, never a model miss.
    error_class=sandbox_denied
    error="sandbox exec layer down: the OS sandbox helper failed to launch, so command spawns were rejected — check probe's sandbox_write and the machine's sandbox helper installation"
  elif [ "$sandbox" = "workspace-write" ] \
       && "$GREP_BIN" -q 'blocked by read-only sandbox' "$run_dir/stderr.log" 2>/dev/null; then
    # The OS sandbox degraded underneath a write run: every write was rejected
    # while the CLI still exits 0 with a completed turn — the envelope must not
    # call that ok. Deterministic environment failure, never a model miss.
    error_class=sandbox_denied
    error="workspace-write degraded to a read-only sandbox (writes rejected) — check probe's sandbox_write and the machine's sandbox setup"
  elif [ "$exit_code" -eq 0 ] && [ "$turn_completed" = true ] && [ "$result_ok" = true ]; then
    ok=true
  else
    error_class=codex_failed
    local diag
    diag="$api_error $("$TAIL_BIN" -c 2000 "$run_dir/stderr.log" 2>/dev/null || true)"
    if printf '%s' "$diag" | "$GREP_BIN" -qiE '401|unauthorized|not logged in'; then error_class=auth
    elif printf '%s' "$diag" | "$GREP_BIN" -qiE '429|rate.?limit|usage.?limit|quota'; then error_class=rate_limit
    elif printf '%s' "$diag" | "$GREP_BIN" -qiE 'unsupported_value|invalid_request|config|invalid value|unexpected argument'; then error_class=config
    elif [ "$result_ok" = false ] && [ "$exit_code" -eq 0 ]; then error_class=schema
    fi
    error="exit=$exit_code turn_completed=$turn_completed result_valid=$result_ok"
  fi

  # Normalize the result via a real file, not process substitution: native
  # Windows jq cannot open MSYS /proc/<pid>/fd paths, which made the final
  # emission — the delivery step itself — crash after a successful run.
  if [ -n "$schema_file" ]; then
    "$JQ_BIN" -c . "$run_dir/final.json" > "$run_dir/result.norm.json" 2>/dev/null \
      || printf 'null\n' > "$run_dir/result.norm.json"
  else
    "$JQ_BIN" -Rs . "$run_dir/final.json" > "$run_dir/result.norm.json" 2>/dev/null \
      || printf 'null\n' > "$run_dir/result.norm.json"
  fi
  # The full envelope (verdict included) is written atomically into the run
  # dir before it is printed: a harvester that never sees stdout reads
  # result.json and gets the same authoritative ok/error_class verdict, not
  # just the model payload in final.json.
  "$JQ_BIN" -n \
    --argjson ok "$ok" \
    --arg error_class "$error_class" --arg error "$error" \
    --arg model "$model" --arg effort "$effort" --arg sandbox "$sandbox" \
    --arg read_mode "$read_mode" \
    --arg workspace "$workspace" --arg base_sha "$base_sha" \
    --argjson dirty_before "$dirty_before" \
    --argjson workspace_changed "$workspace_changed" \
    --argjson exit_code "$exit_code" --argjson turn_completed "$turn_completed" \
    --argjson spend "$spend" \
    --arg run_dir "$run_dir" \
    --slurpfile result_doc "$run_dir/result.norm.json" \
    --arg stderr_tail "$("$TAIL_BIN" -c 2000 "$run_dir/stderr.log" 2>/dev/null || true)" \
    --arg api_error "$api_error" \
    '{ok: $ok, model: $model, effort: $effort, sandbox: $sandbox,
      read_mode: $read_mode, lane: "native",
      workspace: $workspace, base_sha: $base_sha, dirty_before: $dirty_before,
      workspace_changed: $workspace_changed,
      result: $result_doc[0],
      exit_code: $exit_code, turn_completed: $turn_completed, spend: $spend,
      run_dir: $run_dir, stderr_tail: $stderr_tail}
     + (if $ok then {}
        else {error_class: $error_class, error: $error, api_error: $api_error} end)' \
    > "$run_dir/result.json.tmp"
  mv -f "$run_dir/result.json.tmp" "$run_dir/result.json"
  cat "$run_dir/result.json"
}

case "${1:-}" in
  run|probe|verify)
    if wsl_lane_requested; then bridge_to_wsl "$@"; exit 0; fi ;;
esac
case "${1:-}" in
  run)    shift; cmd_run "$@" ;;
  probe)  cmd_probe ;;
  verify) cmd_verify ;;
  *)      require_jq; fail_json usage "usage: codex-worker.sh run|probe|verify (see header comment)" ;;
esac
