#!/usr/bin/env bash
# gemini-worker.sh — deterministic runner for one read-only Antigravity CLI
# (`agy`) worker. Single source of truth for the Gemini-lane invocation: flags,
# isolation, permission rules and result validation live here, not in prompts.
#
# Usage:
#   gemini-worker.sh run --model <agy model id> --prompt-file <file>
#       --model <id>             required; an exact id from `agy models`
#                                (the id carries the effort, e.g.
#                                gemini-3.8-flash-high); ids outside
#                                the floors are refused (model_floor)
#       [--workspace <dir>]      the directory the worker may read (default: $PWD)
#       [--schema-file <file>]   JSON Schema for the final answer
#       [--timeout <seconds>]    total deadline (default: 900)
#       [--run-dir <dir>]        caller-minted run dir, empty or nonexistent
#                                (default: mktemp)
#       [--no-progress]          no live progress lines on stderr (the start
#                                banner stays)
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
# Images agy generates are kept in RUN_DIR/images/ and listed in `images`.
# stderr, for `run`: a start banner, then live progress lines while the worker
# runs and one closing line (see the progress section). Never a result channel.
# Dependencies: Bash, jq, agy; git for the workspace check in git workspaces;
# perl and tail for the progress lines (without perl only the banner
# prints).
set -euo pipefail

DENY_RULES='["write_file(*)","command(*)","unsandboxed(*)","read_url(*)","execute_url(*)","mcp(*)"]'
DEFAULT_TIMEOUT=900
VERIFY_MODEL="${GEMINI_WORKER_VERIFY_MODEL:-gemini-3.8-flash-high}"
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

# The lane's floors: a Gemini id at version 3.8 or later with effort -high;
# or, as the reserve Claude readers, opus at -medium or -high and sonnet at
# -high, version 5.5 or later. Everything else (older versions, older Pro
# models included, lower efforts, other models) is refused.
meets_floor() {
  if [[ "$1" =~ ^gemini-([0-9]+)\.([0-9]+)-[a-z]+-high$ ]]; then
    [ "${BASH_REMATCH[1]}" -gt 3 ] || { [ "${BASH_REMATCH[1]}" -eq 3 ] && [ "${BASH_REMATCH[2]}" -ge 8 ]; }
    return
  fi
  [[ "$1" =~ ^claude-(opus|sonnet)-([0-9]+)-([0-9]+)-(medium|high)$ ]] || return 1
  [ "${BASH_REMATCH[1]}" = opus ] || [ "${BASH_REMATCH[4]}" = high ] || return 1
  [ "${BASH_REMATCH[2]}" -gt 5 ] || { [ "${BASH_REMATCH[2]}" -eq 5 ] && [ "${BASH_REMATCH[3]}" -ge 5 ]; }
}

# --- progress -----------------------------------------------------------------
# The user's live view of a run: this helper's stderr is what a background job
# shows. Each wait-loop tick, and a final flush after the worker exits, prints
# the events.jsonl lines not printed yet:
#   $ <tool> <target>   a tool step, the first time its step_index is seen
#                       (agy sends ACTIVE, then DONE, for the same step). The
#                       target is the AbsolutePath parameter, else the first
#                       string parameter in key order, else nothing.
#   > <text>            an agent message completes (agent_response DONE): its
#                       text_delta pieces joined. A DONE without any text,
#                       which is how a turn that only calls tools ends, prints
#                       nothing.
# Every other event, a line that is not JSON and any unexpected shape print
# nothing. cmd_run closes the view with `end ok=... steps=... <seconds>s`: ok
# and the seconds are read back from the envelope, steps is the highest
# step_index the view saw plus one (the envelope carries no step count).
#
# It is a view, so it must not be able to cost the run anything. The contract
# is codex-worker.sh's:
#   * Reading is guarded and bounded in time and in memory. tail and jq run
#     under a two-second alarm, and one tick reads at most PROGRESS_MAX_BYTES
#     bytes and hands jq only the whole lines in them, at most
#     PROGRESS_MAX_LINES, so neither a backlog nor one huge event grows what
#     jq holds. A read that fails or runs out prints nothing and the next tick
#     reads the same lines again.
#   * A line fits when it and its newline are within one tick's bytes. An
#     unfinished line that may still fit waits. One that cannot fit (the read
#     is full and holds no newline) is skipped unparsed, not retried: jq gets
#     `null` in its place, the position moves past it, and tail shows what
#     follows once the line has its newline.
#   * Each event is parsed on its own: one with an unexpected shape is dropped
#     and the events around it still print.
#   * Writing is bounded and best effort. A foreground perl child does each
#     write under a one-second alarm. What it did not write by then is dropped
#     and never retried, so a stderr reader that stops reading costs lines and
#     that second per write. Nothing runs in the background, so no exit path
#     has a writer to clean up.
#   * A tick that took time skips the loop's one-second sleep, and the
#     deadline is checked before a tick prints. The final flush repeats while
#     a pass still consumes lines, for at most PROGRESS_FLUSH_SECONDS; a
#     backlog it does not reach stays unprinted and uncounted.
#   * The text is worker-controlled, so every piece is cut to 200 characters
#     before anything else touches it, every line is cut at 200 characters,
#     and every control character (C0, DEL, C1) becomes a space.
#   * The position is a count of newline-terminated lines, so a line still
#     being written waits for the next tick.
#   * What a message needs between ticks lives in this shell, not in one jq
#     call: the open message (PROGRESS_MSG, one at a time: a message that
#     starts while another is open replaces it), its first 200 characters as
#     code points (PROGRESS_TEXT) and the last message closed (PROGRESS_DONE).
#     Events for a message at or below PROGRESS_DONE print nothing, so a
#     repeated DONE cannot print twice; a step_index is a whole number below
#     1e9, anything else is an unexpected shape.
# The jq program and the state it hands back are ASCII-only (the ellipsis is
# built from its code point); a native Windows jq ends its lines with CRLF,
# which is stripped below.
PROGRESS=true PROGRESS_SEEN=0 PROGRESS_TOOL=-1 PROGRESS_STEPS=0 PERL_BIN=""
PROGRESS_MSG=-1 PROGRESS_DONE=-1 PROGRESS_TEXT=""
PROGRESS_MAX_LINES=2000 PROGRESS_MAX_BYTES=262144 PROGRESS_FLUSH_SECONDS=5
# Direct executable only, like resolve_agy. No perl, no view: the banner stays.
resolve_perl() { PERL_BIN="$(type -P perl || true)"; [ -n "$PERL_BIN" ]; }
# One bounded write to stderr. The alarm's default action ends perl in the
# kernel, even inside a blocked write. The helper's stderr travels as fd 3 and
# the group's own stderr is /dev/null, so bash has nowhere to report the
# ended child but away from the pipe the write was stuck on. perl's stdout is
# /dev/null, never the envelope channel.
progress_write() { # $1 = text; always returns 0
  {
    printf '%s\n' "$1" 3>&- \
      | "$PERL_BIN" -e 'alarm 1; local $/; print STDERR scalar <STDIN>' >/dev/null 2>&3 3>&-
  } 3>&2 2>/dev/null || true
  return 0
}
print_progress() { # $1 = events.jsonl; always returns 0
  [ "$PROGRESS" = true ] || return 0
  local out hdr
  # pipefail off in the subshell: the reader closing early ends tail with SIGPIPE,
  # and only jq's own status says whether the read worked.
  out="$(exec 2>/dev/null
    set +o pipefail
    "$PERL_BIN" -e 'alarm 2; exec @ARGV' tail -n "+$((PROGRESS_SEEN + 1))" "$1" \
    | "$PERL_BIN" -e 'my ($lines, $bytes) = @ARGV; binmode STDIN; binmode STDOUT;
        my $buf = ""; read(STDIN, $buf, $bytes);
        my ($n, $end) = (0, 0);
        while ($n < $lines && (my $i = index($buf, "\n", $end)) >= 0) { $end = $i + 1; $n++ }
        print $end ? substr($buf, 0, $end) : length($buf) >= $bytes ? "null\n" : ""' \
        "$PROGRESS_MAX_LINES" "$PROGRESS_MAX_BYTES" \
    | "$PERL_BIN" -e 'alarm 2; exec @ARGV' "$JQ_BIN" -Rrs \
      --argjson tool "$PROGRESS_TOOL" --argjson idx "$PROGRESS_MSG" --argjson done "$PROGRESS_DONE" \
      --argjson text "[$PROGRESS_TEXT]" '
      def safe:
        explode | map(if . < 32 or (. >= 127 and . < 160) then 32 else . end)
        | implode;
      def clip($max): if length > $max then .[0:$max - 1] + ([8230] | implode) else . end;
      def short: if type == "string" then .[0:200] else "" end;
      def target:
        .tool_info.parameters
        | if type != "object" then ""
          elif (.AbsolutePath | type) == "string" then .AbsolutePath
          else ([.[] | select(type == "string")][0] // "") end;
      def valid:
        type == "object" and .event == "step_update" and (.step_update | type) == "object"
        and (.step_update.step_index
             | (type == "number" and . == floor and . >= 0 and . < 1000000000));
      def apply($s):
        $s.step_index as $i
        | .steps = ([.steps, $i + 1] | max)
        | if $s.step_type == "tool" and ($s.state == "ACTIVE" or $s.state == "DONE") then
            if $i > .tool then
              .tool = $i
              | .out += ["$ " + ([($s.tool_name | short), ($s | target | short)]
                                 | map(select(. != "")) | join(" "))]
            else . end
          elif $s.step_type == "agent_response" and ($s.state == "ACTIVE" or $s.state == "DONE")
               and $i > .done then
            ((if .idx == $i then .text else "" end) + ($s.text_delta | short) | short) as $t
            | if $s.state == "ACTIVE" then .idx = $i | .text = $t
              else .done = $i | .idx = -1 | .text = ""
                   | if ($t | test("\\S")) then .out += ["> " + ($t | sub("\\s+$"; ""))] else . end
              end
          else . end;
      split("\n") as $p
      | {tool: $tool, idx: $idx, done: $done, text: ($text | implode), steps: 0, out: [], n: 0}
      | reduce $p[:-1][] as $l (.;
          . as $keep
          | try (($l | fromjson) as $e
                 | if ($e | valid) then apply($e.step_update) else . end)
            catch $keep
          | .n += 1)
      | "\(.n) \(.steps) \(.tool) \(.idx) \(.done) \(.text | explode | map(tostring) | join(","))",
        (.out[] | "[gemini-worker] " + . | clip(200) | safe)')" || return 0
  # Unpinned: no test fails if `safe` runs before `clip` above.
  out="${out//$'\r'/}"
  # First output line: lines consumed, steps, then the state the next tick
  # starts from (last tool step printed, open message, last message closed,
  # the open message's text as code points).
  hdr="${out%%$'\n'*}"
  [[ "$hdr" =~ ^([0-9]+)\ ([0-9]+)\ (-?[0-9]+)\ (-?[0-9]+)\ (-?[0-9]+)\ ([0-9,]*)$ ]] || return 0
  PROGRESS_SEEN=$((PROGRESS_SEEN + 10#${BASH_REMATCH[1]}))
  [ "$((10#${BASH_REMATCH[2]}))" -le "$PROGRESS_STEPS" ] || PROGRESS_STEPS="$((10#${BASH_REMATCH[2]}))"
  PROGRESS_TOOL="${BASH_REMATCH[3]}" PROGRESS_MSG="${BASH_REMATCH[4]}"
  PROGRESS_DONE="${BASH_REMATCH[5]}" PROGRESS_TEXT="${BASH_REMATCH[6]}"
  [ "$out" = "$hdr" ] || progress_write "${out#*$'\n'}"
  return 0
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
      --no-progress) PROGRESS=false; shift ;;
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
  meets_floor "$model" || fail_json model_floor "model outside the lane's floors (gemini-3.8-flash-high or newer at -high; claude-opus 5.5+ at -medium/-high; claude-sonnet 5.5+ at -high): $model"
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
  # Start banner on stderr; stdout stays the envelope channel.
  local banner="[gemini-worker] start model=$model run-dir=$RUN_DIR" tick
  if resolve_perl; then progress_write "$banner"; else PROGRESS=false; printf '%s\n' "$banner" >&2 || true; fi
  local start=$SECONDS deadline=$((SECONDS + timeout + ${GEMINI_WORKER_GRACE:-30})) rc=0 timed_out=false
  (cd "$workspace" && agy_env "$AGY_BIN" "${args[@]}") \
    < "$RUN_DIR/input.jsonl" > "$RUN_DIR/events.jsonl" 2> "$RUN_DIR/stderr.log" &
  AGY_PID=$!
  while kill -0 "$AGY_PID" 2>/dev/null; do
    if [ "$SECONDS" -ge "$deadline" ]; then
      timed_out=true; kill "$AGY_PID" 2>/dev/null || true; sleep 2; kill -9 "$AGY_PID" 2>/dev/null || true
      break
    fi
    tick=$SECONDS
    print_progress "$RUN_DIR/events.jsonl"
    [ "$SECONDS" -ne "$tick" ] || sleep 1
  done
  wait "$AGY_PID" || rc=$?
  AGY_PID=""
  local wall=$((SECONDS - start))
  # Final flush: the events of the worker's last second, one bounded read at
  # a time while a read still consumes lines.
  local flush_until=$((SECONDS + PROGRESS_FLUSH_SECONDS)) seen_before
  while :; do
    seen_before=$PROGRESS_SEEN
    print_progress "$RUN_DIR/events.jsonl"
    [ "$PROGRESS_SEEN" -gt "$seen_before" ] && [ "$SECONDS" -lt "$flush_until" ] || break
  done
  cp "$WORK_HOME/.gemini/antigravity-cli/cli.log" "$RUN_DIR/cli.log" 2>/dev/null || true
  # Generated images land in the throwaway HOME's conversation dir, which
  # cleanup deletes: keep them in the run dir.
  local images="[]"
  if [ -d "$WORK_HOME/.gemini/antigravity-cli/brain" ]; then
    mkdir -p "$RUN_DIR/images"
    find "$WORK_HOME/.gemini/antigravity-cli/brain" -path '*/.user_uploaded' -prune -o -type f \
      \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' \) \
      -exec cp {} "$RUN_DIR/images/" \; 2>/dev/null || true
    # Paths as jq arguments, so they take the same form as run_dir.
    local files=() f
    while IFS= read -r f; do files+=("$f"); done < <(find "$RUN_DIR/images" -type f | LC_ALL=C sort)
    images="$("$JQ_BIN" -cn '$ARGS.positional' --args ${files[@]+"${files[@]}"})"
    [ "$images" != "[]" ] || rmdir "$RUN_DIR/images" 2>/dev/null || true
  fi

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
    --arg changed "$changed" --argjson images "$images" '. as $r |
    {model: $model, lane: "agy", workspace: $ws, run_dir: $rd,
     status: ($r.status // null),
     result: (if $r == null then null
              elif $schema then ($r.structured_output // null)
              else ($r.response // "" | sub("\\s+$"; "")) end),
     denied_actions: ($r.denied_actions // []),
     workspace_changed: ($changed != ""),
     changed_files: ($changed | split("\n") | map(select(. != ""))),
     images: $images,
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

  local envelope
  if [ -z "$class" ]; then
    envelope="$("$JQ_BIN" -c '{ok: true} + .' <<<"$base")"
  else
    envelope="$("$JQ_BIN" -c --arg c "$class" --arg m "$msg" --arg d "$err_text" \
      '{ok: false, error_class: $c, error: $m} + . + (if $d == "" then {} else {detail: $d} end)' <<<"$base")"
  fi
  # Closing progress line, read back from the envelope so the two cannot
  # disagree. Best effort and bounded like every progress write (one second to
  # read, one to write); the delivery below waits no longer than that.
  if [ "$PROGRESS" = true ]; then
    local end_line
    end_line="$(exec 2>/dev/null
      "$PERL_BIN" -e 'alarm 1; exec @ARGV' "$JQ_BIN" -r --argjson s "$PROGRESS_STEPS" \
      '"[gemini-worker] end ok=\(.ok) steps=\($s) \(.spend.wall_seconds)s"' <<<"$envelope")" || end_line=""
    end_line="${end_line//$'\r'/}"
    [ -z "$end_line" ] || progress_write "$end_line"
  fi
  emit "$envelope"
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
