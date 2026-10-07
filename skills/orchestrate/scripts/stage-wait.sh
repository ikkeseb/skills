#!/usr/bin/env bash
# stage-wait.sh — start one long-running worker job detached, once, and wait
# for it in bounded calls. For a transport agent inside a harness workflow,
# where a background process dies with the agent's final answer and one tool
# call is capped near ten minutes: repeat the same call until the status is
# no longer `running`.
#
# Usage:
#   stage-wait.sh --run-dir <dir> [--wait <seconds>] -- <command> [args...]
#       --run-dir <dir>     the run dir <command> writes its result.json into;
#                           empty or nonexistent on the first call. This
#                           script never writes, deletes or creates in it.
#       [--wait <seconds>]  longest this call waits, a whole number 0..540
#                           (default: 480), counted in whole clock seconds
#       -- <command> [args...]  started on the first call only, arguments
#                           passed through unchanged; required on every call,
#                           ignored on all but the first
#
# The first call claims the stage with an exclusive create and starts
# <command> detached: its own session through `setsid` where that exists,
# otherwise its own process group through bash job control; SIGHUP ignored
# either way. stdin is /dev/null. Later calls with the same --run-dir only
# wait. Nothing starts the command a second time: a claimed stage stays
# claimed, whatever became of the job.
#
# State, in the sibling directory <dir>.stage/ (remove it to forget a stage):
#   claim       the once-only claim (epoch seconds of the first call)
#   pid, exit   the detached runner's pid, and <command>'s exit status
#   stdout      <command>'s stdout
#   stderr.log  <command>'s stderr
#
# Output: exactly one JSON line on stdout, diagnostics on stderr:
#   {"status":"running|done|failed","ok":true|false|null,
#    "error_class":<string|null>,"run_dir":"<dir>","waited_s":<int>}
#   done     <dir>/result.json holds `ok: true`
#   failed   <dir>/result.json holds `ok: false` (its error_class is carried);
#            or the job ended without one: then the error_class of a JSON
#            object with `ok` on its stdout, else `no_envelope`
#            (`bad_envelope`: a result.json that is not such an object;
#            `start_failed`: a claim with no runner after 30 seconds)
#   running  neither yet: call again
# Exit status: 0 with every status line; 2 for a usage error, which prints
# `"status":"failed","error_class":"usage"` (a used run dir with no stage is
# one, as it is for the helpers).
#
# Known limit: the recorded pid is the runner's. A runner killed alone while
# <command> lives on reads as `no_envelope`; check for the worker's own
# process before starting the stage again elsewhere.
#
# Environment: STAGE_WAIT_NO_SETSID=1 takes the no-`setsid` path where
# `setsid` exists (for the test suite).
# Dependencies: Bash (3.2 or later) and jq.
set -uo pipefail

DEFAULT_WAIT=480
MAX_WAIT=540
POLL_SECS=0.2
START_GRACE_SECS=30

RUN_DIR="" STAGE="" WAIT="$DEFAULT_WAIT"
JQ_BIN="$(type -P jq || true)"

emit() { # emit <status> <ok: true|false|null> <error_class, "" for null>
  local line
  line="$("$JQ_BIN" -cn --arg s "$1" --argjson ok "$2" --arg ec "$3" --arg rd "$RUN_DIR" --argjson w "$SECONDS" \
    '{status: $s, ok: $ok, error_class: (if $ec == "" then null else $ec end), run_dir: $rd, waited_s: $w}' \
    | tr -d '\r')"
  printf '%s\n' "$line"
}
usage_fail() { # usage_fail <message>
  printf 'stage-wait: %s\n' "$1" >&2
  emit failed false usage
  exit 2
}

if [ -z "$JQ_BIN" ]; then
  printf 'stage-wait: jq is required\n' >&2
  printf '{"status":"failed","ok":false,"error_class":"usage","run_dir":"","waited_s":0}\n'
  exit 2
fi

# envelope <file>: prints "<true|false><TAB><error_class or empty>" when the
# file holds a JSON object with a boolean `ok`, as one document or as one of
# its lines (the last such line wins); prints nothing otherwise.
envelope() {
  "$JQ_BIN" -Rrs '
    (try fromjson catch null) as $whole
    | (if ($whole | type) == "object" then [$whole]
       else [split("\n")[] | (try fromjson catch null)] end)
    | map(select(type == "object" and (.ok | type) == "boolean")) | last
    | if . == null then empty
      else "\(.ok)\t\(.error_class | if type == "string" then . else "" end)" end
  ' "$1" 2>/dev/null | tr -d '\r'
}

STATUS="" OK=null EC="" RESULT_SEEN=0
read_result() { # 0 once result.json holds an envelope; sets STATUS, OK, EC
  local env
  [ -f "$RUN_DIR/result.json" ] || return 1
  RESULT_SEEN=1
  env="$(envelope "$RUN_DIR/result.json")"
  [ -n "$env" ] || return 1
  OK="${env%%$'\t'*}" EC="${env#*$'\t'}"
  if [ "$OK" = true ]; then STATUS="done" EC=""; else STATUS=failed; fi
  return 0
}
job_ended() { # 0 once the runner has recorded an exit or its pid is gone
  local pid
  [ ! -f "$STAGE/exit" ] || return 0
  [ -s "$STAGE/pid" ] || return 1
  pid="$(tr -cd '0-9' < "$STAGE/pid" 2>/dev/null)"
  [ -n "$pid" ] || return 1
  ! kill -0 "$pid" 2>/dev/null
}
claim_stale() { # 0 when the claim is older than the grace and no runner showed
  local t now
  [ ! -e "$STAGE/pid" ] || return 1
  t="$(tr -cd '0-9' < "$STAGE/claim" 2>/dev/null)"
  now="$(date +%s 2>/dev/null | tr -cd '0-9')"
  [ -n "$t" ] && [ -n "$now" ] || return 1
  [ $((now - t)) -gt "$START_GRACE_SECS" ]
}

# The runner records its own pid, so the pid is right whether or not `setsid`
# forks, and records the command's exit status, so a finished job is known
# without trusting a pid that the system may hand out again.
RUNNER='stage=$1; shift
printf "%s\n" "$$" > "$stage/pid.tmp" && mv -f "$stage/pid.tmp" "$stage/pid"
"$@"
rc=$?
printf "%s\n" "$rc" > "$stage/exit.tmp" && mv -f "$stage/exit.tmp" "$stage/exit"'

start_detached() { # start_detached <command> [args...]
  if [ -z "${STAGE_WAIT_NO_SETSID:-}" ] && command -v setsid >/dev/null 2>&1; then
    ( trap '' HUP
      setsid "$BASH" -c "$RUNNER" stage-wait-runner "$STAGE" "$@" \
        < /dev/null > "$STAGE/stdout" 2> "$STAGE/stderr.log" & )
  else
    # No setsid (stock macOS, Git Bash): job control gives the background job
    # a process group of its own, and the subshell's exit leaves it orphaned.
    ( trap '' HUP
      set -m
      "$BASH" -c "$RUNNER" stage-wait-runner "$STAGE" "$@" \
        < /dev/null > "$STAGE/stdout" 2> "$STAGE/stderr.log" & )
  fi
}

have_dir=0 have_cmd=0
while [ $# -gt 0 ]; do
  case "$1" in
    --run-dir) [ $# -ge 2 ] || usage_fail "--run-dir needs a value"; RUN_DIR="$2"; have_dir=1; shift 2 ;;
    --wait)    [ $# -ge 2 ] || usage_fail "--wait needs a value"; WAIT="$2"; shift 2 ;;
    --)        shift; have_cmd=1; break ;;
    *)         usage_fail "unknown argument: $1" ;;
  esac
done
while [ "${RUN_DIR%/}" != "$RUN_DIR" ] && [ "$RUN_DIR" != / ]; do RUN_DIR="${RUN_DIR%/}"; done
[ "$have_dir" -eq 1 ] && [ -n "$RUN_DIR" ] && [ "$RUN_DIR" != / ] || usage_fail "--run-dir <dir> is required"
case "$WAIT" in
  ''|*[!0-9]*|????*) usage_fail "--wait takes whole seconds, 0..$MAX_WAIT" ;;
esac
WAIT=$((10#$WAIT))
[ "$WAIT" -le "$MAX_WAIT" ] || usage_fail "--wait takes whole seconds, 0..$MAX_WAIT"
[ "$have_cmd" -eq 1 ] && [ $# -ge 1 ] && [ -n "$1" ] || usage_fail "a command is required after --"
STAGE="$RUN_DIR.stage"

# A used run dir with no stage beside it is a stale envelope waiting to be
# read as this job's. The run dir is looked at before the claim, so a racing
# first call whose job has already written there is seen with its claim.
used=0
[ ! -e "$RUN_DIR" ] || [ -z "$(ls -A "$RUN_DIR" 2>/dev/null)" ] || used=1
if [ "$used" -eq 1 ] && [ ! -e "$STAGE/claim" ]; then
  usage_fail "run dir is not empty and has no stage: $RUN_DIR"
fi

mkdir -p "$STAGE" 2>/dev/null || usage_fail "cannot create the stage dir: $STAGE"
# The once-only claim: noclobber opens with O_EXCL, so one caller creates the
# file whatever `mkdir` told the racers.
if ( set -o noclobber; printf '%s\n' "$(date +%s)" > "$STAGE/claim" ) 2>/dev/null; then
  start_detached "$@"
fi

while :; do
  read_result && break
  if job_ended; then
    read_result && break # written just before the job ended
    STATUS=failed OK=false
    if [ "$RESULT_SEEN" -eq 1 ]; then
      EC=bad_envelope
    else
      env="$(envelope "$STAGE/stdout")"
      EC="${env#*$'\t'}"
      [ -n "$env" ] && [ -n "$EC" ] || EC=no_envelope
    fi
    break
  fi
  if claim_stale; then STATUS=failed OK=false EC=start_failed; break; fi
  if [ "$SECONDS" -ge "$WAIT" ]; then STATUS=running OK=null EC=""; break; fi
  sleep "$POLL_SECS" 2>/dev/null || sleep 1 2>/dev/null || true
done

emit "$STATUS" "$OK" "$EC"
exit 0
