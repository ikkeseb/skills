#!/usr/bin/env bash
# gemini-worker.sh — deterministic runner for one read-only Antigravity CLI
# (`agy`) worker. Single source of truth for the Gemini-lane invocation: flags,
# isolation, permission rules and result validation live here, not in prompts.
#
# Usage:
#   gemini-worker.sh run --model <agy model id> --prompt-file <file>
#       --model <id>             required; an exact id from `agy models`
#                                (the id carries the effort, e.g.
#                                gemini-3.8-flash-medium)
#       [--workspace <dir>]      the directory the worker may read (default: $PWD)
#       [--schema-file <file>]   JSON Schema for the final answer
#       [--timeout <seconds>]    total deadline (default: 900)
#       [--run-dir <dir>]        caller-minted run dir, empty or nonexistent
#                                (default: mktemp)
#   gemini-worker.sh probe       CLI present + authenticated, no model call
#   gemini-worker.sh verify      one small billed run: read canary + denied write
#
# Read-only by construction: every run gets a throwaway HOME whose
# settings.json denies file writes, shell commands, web, browser and MCP.
# The login lives in the OS keyring or, without one, in a token file the helper
# copies in, so the throwaway HOME keeps it while dropping the user's own agy
# settings, plugins and permission grants.
#
# Output: exactly one JSON object on stdout, mirrored to RUN_DIR/result.json.
# Dependencies: Bash, jq, agy; git for the workspace check in git workspaces.
set -euo pipefail

DENY_RULES='["write_file(*)","command(*)","unsandboxed(*)","read_url(*)","execute_url(*)","mcp(*)"]'
DEFAULT_TIMEOUT=900
VERIFY_MODEL="${GEMINI_WORKER_VERIFY_MODEL:-gemini-3.8-flash-low}"
TOKEN_FILE=.gemini/antigravity-cli/antigravity-oauth-token

JQ_BIN="" AGY_BIN="" RUN_DIR="" WORK_HOME="" AGY_PID=""

is_windows() { case "$(uname -s 2>/dev/null)" in MINGW*|MSYS*|CYGWIN*) return 0 ;; *) return 1 ;; esac; }
# agy is a native binary: on MSYS it needs Windows paths.
native_path() { if is_windows; then cygpath -w "$1"; else printf '%s' "$1"; fi; }
# jq on Windows may end lines with CRLF; scalars are compared after this.
jqr() { "$JQ_BIN" -r "$@" | tr -d '\r'; }

emit() { # emit <json>: print, and mirror into the run dir when there is one
  if [ -n "$RUN_DIR" ] && [ -d "$RUN_DIR" ]; then
    printf '%s\n' "$1" > "$RUN_DIR/result.json.tmp" && mv -f "$RUN_DIR/result.json.tmp" "$RUN_DIR/result.json"
  fi
  printf '%s\n' "$1"
}
fail_json() { # fail_json <error_class> <message>
  emit "$("$JQ_BIN" -cn --arg c "$1" --arg m "$2" --arg rd "$RUN_DIR" \
    '{ok: false, error_class: $c, error: $m} + (if $rd == "" then {} else {run_dir: $rd} end)')"
  exit 0
}

cleanup() {
  [ -z "$AGY_PID" ] || kill "$AGY_PID" 2>/dev/null || true
  [ -z "$WORK_HOME" ] || rm -rf "$WORK_HOME"
}
trap cleanup EXIT
trap 'exit 130' INT TERM

require_jq() {
  JQ_BIN="$(type -P jq || true)"
  [ -n "$JQ_BIN" ] || { printf '{"ok":false,"error_class":"missing_dependency","error":"jq is required"}\n'; exit 0; }
}

# Direct executable only: a shell function named agy must never reach workers.
# The install locations cover a fresh install whose PATH change has not yet
# reached this shell.
resolve_agy() {
  AGY_BIN="$(type -P agy || true)"
  if [ -z "$AGY_BIN" ]; then
    local c
    for c in "${LOCALAPPDATA:-}/agy/bin/agy.exe" "$HOME/.local/bin/agy"; do
      if [ -n "$c" ] && [ -x "$c" ]; then AGY_BIN="$c"; break; fi
    done
  fi
  [ -n "$AGY_BIN" ] || fail_json agy_missing "agy not found on PATH or in its install locations"
}

# A throwaway HOME holding the deny rules plus the user's global instruction
# file (agy reads ~/.gemini/GEMINI.md; workspace AGENTS.md loads on its own).
# HOME covers macOS and Linux, USERPROFILE covers Windows.
make_work_home() {
  WORK_HOME="$(mktemp -d)"
  mkdir -p "$WORK_HOME/.gemini/antigravity-cli"
  "$JQ_BIN" -n --argjson deny "$DENY_RULES" '{permissions: {deny: $deny}}' \
    > "$WORK_HOME/.gemini/antigravity-cli/settings.json"
  [ ! -f "$HOME/.gemini/GEMINI.md" ] || cp "$HOME/.gemini/GEMINI.md" "$WORK_HOME/.gemini/GEMINI.md"
  # Without an OS keyring (Linux, WSL) agy keeps its login in this file. A copy,
  # not a link: a token refresh inside a run never touches the real one.
  [ ! -f "$HOME/$TOKEN_FILE" ] || cp "$HOME/$TOKEN_FILE" "$WORK_HOME/$TOKEN_FILE"
  # macOS resolves the login keychain under HOME; a link, since keychain access
  # still goes through the OS (cleanup's rm -rf removes the link, not the target).
  if [ "$(uname -s)" = Darwin ] && [ -d "$HOME/Library/Keychains" ]; then
    mkdir -p "$WORK_HOME/Library"
    ln -s "$HOME/Library/Keychains" "$WORK_HOME/Library/Keychains"
  fi
}

# Worker environment: the throwaway HOME, no API key (a key would switch
# billing away from the subscription login), no auto-update mid-run.
# `exec env` keeps one process, so the watchdog's kill reaches agy itself.
agy_env() {
  local h; h="$(native_path "$WORK_HOME")"
  exec env -u GEMINI_API_KEY -u GOOGLE_API_KEY \
    HOME="$h" USERPROFILE="$h" AGY_CLI_DISABLE_AUTO_UPDATE=1 "$@"
}

agy_version() { "$AGY_BIN" --version 2>/dev/null | tr -d '\r' | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || true; }

# Workspace fingerprint: every file path with size and mtime, plus git HEAD.
# Compared before and after a run; any difference fails the run.
fingerprint() { # fingerprint <dir> <out>
  {
    git -C "$1" rev-parse HEAD 2>/dev/null || true
    { find "$1" -path "$1/.git" -prune -o -type f -newer "$2.marker" -print 2>/dev/null || true; } | sed 's/^/NEWER /'
    { find "$1" -path "$1/.git" -prune -o -type f -print 2>/dev/null || true; } | LC_ALL=C sort
  } > "$2"
}

# list_models: the model ids the login under WORK_HOME sees, as a JSON array in
# MODELS (MODELS_OUT keeps the raw output). Fails when agy is not logged in.
MODELS="" MODELS_OUT=""
list_models() {
  local rc=0
  MODELS_OUT="$( (agy_env "$AGY_BIN" models) 2>&1)" || rc=$?
  MODELS="$(printf '%s\n' "$MODELS_OUT" | tr -d '\r' | awk -F'\t' 'NF >= 2 && $1 ~ /^[a-z0-9][a-z0-9.-]*$/ {print $1}' \
    | "$JQ_BIN" -R . | "$JQ_BIN" -cs .)"
  [ "$rc" -eq 0 ] && [ "$MODELS" != "[]" ]
}
NOT_LOGGED_IN="agy is not logged in on this machine: run \`agy\` once interactively"

cmd_probe() {
  require_jq; resolve_agy; make_work_home
  local version
  version="$(agy_version)"
  if ! list_models; then
    emit "$("$JQ_BIN" -cn --arg v "$version" --arg m "$NOT_LOGGED_IN" --arg e "$(printf '%s' "$MODELS_OUT" | tr -d '\r' | tail -5)" \
      '{ok: false, error_class: "auth", agy_version: $v, authenticated: false, error: $m, detail: $e}')"
    exit 0
  fi
  emit "$("$JQ_BIN" -cn --arg v "$version" --arg bin "$AGY_BIN" --argjson m "$MODELS" \
    '{ok: true, agy_version: $v, agy_bin: $bin, authenticated: true, models: $m,
      read_only: "enforced by per-run deny rules"}')"
}

cmd_run() {
  require_jq
  local model="" prompt_file="" workspace="$PWD" schema_file="" timeout="$DEFAULT_TIMEOUT" run_dir_opt=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --model|--prompt-file|--workspace|--schema-file|--timeout|--run-dir)
        [ $# -ge 2 ] || fail_json usage "missing value for $1" ;;
    esac
    case "$1" in
      --model) model="$2"; shift 2 ;;
      --prompt-file) prompt_file="$2"; shift 2 ;;
      --workspace) workspace="$2"; shift 2 ;;
      --schema-file) schema_file="$2"; shift 2 ;;
      --timeout) timeout="$2"; shift 2 ;;
      --run-dir) run_dir_opt="$2"; shift 2 ;;
      *) fail_json usage "unknown argument: $1" ;;
    esac
  done
  [ -n "$model" ] || fail_json usage "--model is required (an id from \`agy models\`)"
  [ -f "$prompt_file" ] || fail_json usage "--prompt-file missing or unreadable: $prompt_file"
  [ -d "$workspace" ] || fail_json usage "--workspace is not a directory: $workspace"
  case "$timeout" in ''|0|*[!0-9]*) fail_json usage "--timeout must be a positive integer" ;; esac
  [ "$timeout" -le 86400 ] || fail_json usage "--timeout must be at most 86400"
  if [ -n "$schema_file" ]; then
    [ -f "$schema_file" ] || fail_json usage "--schema-file unreadable: $schema_file"
    "$JQ_BIN" -e 'type == "object"' "$schema_file" >/dev/null 2>&1 \
      || fail_json usage "--schema-file is not a JSON object: $schema_file"
  fi
  workspace="$(CDPATH= cd -- "$workspace" && pwd)"

  if [ -n "$run_dir_opt" ]; then
    mkdir -p "$run_dir_opt" 2>/dev/null || fail_json usage "cannot create --run-dir: $run_dir_opt"
    [ -z "$(ls -A "$run_dir_opt")" ] || fail_json usage "--run-dir must be empty: $run_dir_opt"
    RUN_DIR="$(CDPATH= cd -- "$run_dir_opt" && pwd)"
  else
    RUN_DIR="$(mktemp -d)"
  fi
  case "$RUN_DIR/" in
    "$workspace/"*) local rd="$RUN_DIR"; RUN_DIR=""; [ -z "$run_dir_opt" ] || rmdir "$rd" 2>/dev/null || true
      fail_json usage "--run-dir must be outside the workspace: $rd" ;;
  esac
  resolve_agy; make_work_home
  # Logged out, agy starts a login flow in the run itself and reads the prompt
  # on stdin as the authorization code; check before the prompt leaves.
  list_models || fail_json auth "$NOT_LOGGED_IN"

  # The prompt travels on stdin as one stream-json message: no command-line
  # length limit, and no slash-command expansion of a leading "/".
  "$JQ_BIN" -cn --rawfile p "$prompt_file" '{event: "user", message: {content: $p}}' > "$RUN_DIR/input.jsonl" \
    || fail_json usage "cannot read --prompt-file: $prompt_file"

  local args=(--input-format stream-json --output-format stream-json
    --model "$model" --add-dir "$(native_path "$workspace")"
    --print-timeout "${timeout}s")
  [ -z "$schema_file" ] || args+=(--json-schema "$(native_path "$(CDPATH= cd -- "$(dirname -- "$schema_file")" && pwd)/$(basename -- "$schema_file")")")

  touch "$RUN_DIR/before.marker"
  fingerprint "$workspace" "$RUN_DIR/before"
  # agy measures its own --print-timeout; this watchdog only catches a process
  # that outlives it.
  local start=$SECONDS deadline=$((SECONDS + timeout + ${GEMINI_WORKER_GRACE:-30})) rc=0 timed_out=false
  (cd "$workspace" && agy_env "$AGY_BIN" "${args[@]}") \
    < "$RUN_DIR/input.jsonl" > "$RUN_DIR/events.jsonl" 2> "$RUN_DIR/stderr.log" &
  AGY_PID=$!
  while kill -0 "$AGY_PID" 2>/dev/null; do
    if [ "$SECONDS" -ge "$deadline" ]; then
      timed_out=true; kill "$AGY_PID" 2>/dev/null || true; sleep 2; kill -9 "$AGY_PID" 2>/dev/null || true
      break
    fi
    sleep 1
  done
  wait "$AGY_PID" || rc=$?
  AGY_PID=""
  local wall=$((SECONDS - start))
  cp "$WORK_HOME/.gemini/antigravity-cli/cli.log" "$RUN_DIR/cli.log" 2>/dev/null || true

  cp "$RUN_DIR/before.marker" "$RUN_DIR/after.marker"
  touch -r "$RUN_DIR/before.marker" "$RUN_DIR/after.marker"
  fingerprint "$workspace" "$RUN_DIR/after"
  local changed
  changed="$( { diff "$RUN_DIR/before" "$RUN_DIR/after" || true; } | sed -n 's/^> \(NEWER \)\{0,1\}//p; s/^< \(NEWER \)\{0,1\}//p' | LC_ALL=C sort -u | head -20)"

  # The agy result travels through a file: a long answer passed as an argument
  # overflows the Windows command-line limit.
  local res="$RUN_DIR/agy-result.json"
  { "$JQ_BIN" -c 'select(.event == "result") | .result' "$RUN_DIR/events.jsonl" 2>/dev/null || true; } \
    | tail -1 | tr -d '\r' > "$res"
  "$JQ_BIN" -e 'type == "object"' "$res" >/dev/null 2>&1 || printf 'null\n' > "$res"

  # Envelope first, verdict second: every failure below still carries the
  # worker's own answer and spend for the seat to inspect.
  local base
  base="$("$JQ_BIN" -c --arg model "$model" --arg ws "$workspace" \
    --arg rd "$RUN_DIR" --argjson wall "$wall" --argjson schema "$([ -n "$schema_file" ] && echo true || echo false)" \
    --arg changed "$changed" '. as $r |
    {model: $model, lane: "agy", workspace: $ws, run_dir: $rd,
     status: ($r.status // null),
     result: (if $r == null then null
              elif $schema then ($r.structured_output // null)
              else ($r.response // "" | sub("\\s+$"; "")) end),
     denied_actions: ($r.denied_actions // []),
     workspace_changed: ($changed != ""),
     changed_files: ($changed | split("\n") | map(select(. != ""))),
     conversation_id: ($r.conversation_id // null),
     spend: {input_tokens: ($r.usage.input_tokens // null),
             cache_read_tokens: ($r.usage.cache_read_tokens // null),
             output_tokens: ($r.usage.output_tokens // null),
             thinking_tokens: ($r.usage.thinking_tokens // null),
             total_tokens: ($r.usage.total_tokens // null),
             wall_seconds: $wall}}' "$res")"

  local status err_text class="" msg=""
  status="$(jqr '.status // ""' <<<"$base")"
  err_text="$( { jqr '.error // ""' "$res"; tail -20 "$RUN_DIR/stderr.log" 2>/dev/null; } | tr -d '\r' | head -c 2000 || true)"

  if [ "$(jqr '.workspace_changed' <<<"$base")" = true ]; then
    class=workspace_changed; msg="workspace files changed during a read-only run (see changed_files); the seat's own edits also count"
  # Before the timeout test: a failed login flow also says "timed out".
  elif grep -qiE 'authentication required|authentication failed|not authenticated|log ?in' <<<"$err_text" && [ "$status" != SUCCESS ]; then
    class=auth; msg="$NOT_LOGGED_IN"
  # agy reports its own --print-timeout as status SUCCESS with partial output;
  # only this stderr line tells the two apart.
  elif [ "$timed_out" = true ] || grep -qF '[agy] print timeout' "$RUN_DIR/stderr.log" 2>/dev/null \
      || { [ "$status" != SUCCESS ] && grep -qiE 'timed? ?out|deadline' <<<"$err_text"; }; then
    class=timeout; msg="no complete result within ${timeout}s; any result is partial"
  elif grep -qiE 'not recognized as a known model|invalid model' <<<"$err_text"; then
    class=model_unknown; msg="unknown model id: $model (list: gemini-worker.sh probe)"
  elif grep -qiE 'quota|resource.?exhausted|capacity|rate.?limit|429' <<<"$err_text" && [ "$status" != SUCCESS ]; then
    class=quota; msg="provider quota or capacity exhausted"
  elif [ "$(jqr 'type' "$res")" != object ] || [ "$rc" -ne 0 ] || [ "$status" != SUCCESS ]; then
    class=agy_failed; msg="exit $rc, status ${status:-none}"
  elif [ "$(jqr '.denied_actions | length' <<<"$base")" -gt 0 ]; then
    class=tool_denied; msg="the worker needed a tool or path outside its grant; the result may be incomplete"
  elif [ -n "$schema_file" ] && [ "$(jqr '.result | type' <<<"$base")" != object ]; then
    class=schema_missing; msg="no structured_output despite --schema-file"
  elif [ -z "$schema_file" ] && [ -z "$(jqr '.result // ""' <<<"$base")" ]; then
    class=empty_result; msg="the worker returned an empty answer"
  fi

  if [ -z "$class" ]; then
    emit "$("$JQ_BIN" -c '{ok: true} + .' <<<"$base")"
  else
    emit "$("$JQ_BIN" -c --arg c "$class" --arg m "$msg" --arg d "$err_text" \
      '{ok: false, error_class: $c, error: $m} + . + (if $d == "" then {} else {detail: $d} end)' <<<"$base")"
  fi
}

cmd_verify() {
  require_jq
  local self tmp token out ok
  self="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/$(basename -- "${BASH_SOURCE[0]}")"
  tmp="$(mktemp -d)"
  mkdir -p "$tmp/ws"
  token="canary-$RANDOM$RANDOM"
  printf '%s\n' "$token" > "$tmp/ws/canary.txt"
  cat > "$tmp/prompt.md" <<'EOF'
Two steps, then answer.
1. Read the file canary.txt in your workspace and report its exact content, without the trailing newline.
2. Try to create a file named write-probe.txt containing "x" in your workspace, using your file-writing tool. Report whether that succeeded.
EOF
  printf '%s\n' '{"type":"object","properties":{"canary":{"type":"string"},"write_succeeded":{"type":"boolean"}},"required":["canary","write_succeeded"]}' > "$tmp/schema.json"
  out="$(bash "$self" run --model "$VERIFY_MODEL" --workspace "$tmp/ws" --prompt-file "$tmp/prompt.md" \
    --schema-file "$tmp/schema.json" --timeout 300 --run-dir "$tmp/run")"
  # "write denied" needs both halves: the worker reports a failed attempt, and
  # the file does not exist.
  ok="$(jqr --arg t "$token" '
    .ok == true and .result.canary == $t and .result.write_succeeded == false
    and .workspace_changed == false' <<<"$out" 2>/dev/null || echo false)"
  if [ "$ok" = true ] && [ ! -e "$tmp/ws/write-probe.txt" ]; then
    emit "$("$JQ_BIN" -c --arg m "$VERIFY_MODEL" '{ok: true, verified: ["read canary", "write denied", "workspace unchanged"], model: $m, spend: .spend}' <<<"$out")"
    rm -rf "$tmp"
  else
    # Evidence stays on disk for diagnosis.
    emit "$("$JQ_BIN" -c --arg exists "$([ -e "$tmp/ws/write-probe.txt" ] && echo true || echo false)" --arg dir "$tmp" \
      '{ok: false, error_class: "verify_failed", error: "canary, read-only or envelope check failed", write_probe_exists: ($exists == "true"), verify_dir: $dir, run: .}' <<<"$out" 2>/dev/null \
      || printf '{"ok":false,"error_class":"verify_failed","error":"run output was not JSON","verify_dir":"%s"}' "$tmp")"
  fi
}

case "${1:-}" in
  run) shift; cmd_run "$@" ;;
  probe) cmd_probe ;;
  verify) cmd_verify ;;
  *) require_jq; fail_json usage "usage: gemini-worker.sh run|probe|verify (see the header)" ;;
esac
