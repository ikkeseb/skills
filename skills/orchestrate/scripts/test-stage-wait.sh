#!/usr/bin/env bash
# Hermetic black-box tests for stage-wait.sh. A fake command in a throwaway
# dir stands in for a worker helper, so no provider, login, network, or quota
# is used. Jobs are held and released through gate files, never by timing.
# Usage: bash skills/orchestrate/scripts/test-stage-wait.sh

set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
helper="$script_dir/stage-wait.sh"
tmp="$(mktemp -d)"
fails=0
pass() { printf 'ok    %s\n' "$1"; }
fail() { printf 'FAIL  %s\n' "$1"; fails=$((fails + 1)); }
check() { # check <name> <jq predicate> <json>
  if jq -e "$2" >/dev/null 2>&1 <<<"$3"; then pass "$1"; else fail "$1"; printf '      got: %.600s\n' "$3"; fi
}
is() { # is <name> <expected> <actual>
  if [ "$2" = "$3" ]; then pass "$1"; else fail "$1"; printf '      want: %.300s\n      got:  %.300s\n' "$2" "$3"; fi
}

# fake <mode> <run dir> [args...]: logs one line per start and its arguments,
# waits for the gate file when FAKE_GATE names one, then acts out the mode.
cat > "$tmp/fake" <<'FAKE'
#!/usr/bin/env bash
set -u
mode="$1" run="$2"
printf 'start\n' >> "$FAKE_LOG.starts"
printf '[%s]\n' "$@" > "$FAKE_LOG.args"
line=""; IFS= read -r -t 2 line || true
printf '%s\n' "$line" > "$FAKE_LOG.stdin"
if [ -n "${FAKE_GATE:-}" ]; then
  n=0
  until [ -e "$FAKE_GATE" ]; do
    n=$((n + 1)); [ "$n" -lt 300 ] || exit 9
    sleep 0.1
  done
fi
write_result() { mkdir -p "$run" && printf '%s\n' "$1" > "$run/result.json.tmp" && mv -f "$run/result.json.tmp" "$run/result.json"; }
case "$mode" in
  ok)          mkdir -p "$run"; printf 'e\n' > "$run/events.jsonl"; write_result '{"ok":true,"result":"fine"}' ;;
  fail)        write_result '{"ok":false,"error_class":"timeout","error":"deadline"}' ;;
  stdout-only) printf 'a banner line\n{"ok":false,"error_class":"auth","error":"not logged in"}\n'; exit 0 ;;
  stdout-tall) printf '{\n  "ok": false,\n  "error_class": "usage"\n}\n' ;;
  silent)      echo "dying" >&2; exit 3 ;;
  garbage)     mkdir -p "$run"; printf 'not json\n' > "$run/result.json" ;;
esac
FAKE
chmod +x "$tmp/fake"

# Every fake still running is released or killed before the temp dir goes.
cleanup() {
  local p
  for p in "$tmp"/*.stage/pid; do
    [ -f "$p" ] || continue
    kill "$(cat "$p")" 2>/dev/null || true
  done
  rm -rf "$tmp"
}
trap cleanup EXIT

n=0
new_case() { # new_case: fresh run dir, start log and gate for one case
  n=$((n + 1))
  run="$tmp/run$n" gate="$tmp/gate$n"
  export run
  export FAKE_LOG="$tmp/log$n" FAKE_GATE=""
}
starts() { if [ -f "$FAKE_LOG.starts" ]; then wc -l < "$FAKE_LOG.starts" | tr -d ' '; else echo 0; fi; }
sw() { bash "$helper" "$@"; }
await_file() { # await_file <file>: up to ten seconds
  local i=0
  until [ -e "$1" ]; do i=$((i + 1)); [ "$i" -lt 100 ] || return 1; sleep 0.1; done
}

# --- a job that finishes within the first wait -----------------------------
new_case
out="$(sw --run-dir "$run" --wait 60 -- "$tmp/fake" ok "$run")"; rc=$?
check "first wait: done, with exactly the status line's five keys" \
  '. == {status: "done", ok: true, error_class: null, run_dir: $ENV.run, waited_s: .waited_s} and (.waited_s | type) == "number" and .waited_s < 30' "$out"
is "first wait: exactly one line on stdout" 1 "$(printf '%s\n' "$out" | wc -l | tr -d ' ')"
is "first wait: exit status 0" 0 "$rc"
is "run dir holds only what the command wrote" "events.jsonl result.json" "$(ls -A "$run" | sort | tr '\n' ' ' | sed 's/ $//')"
is "state lives in the sibling stage dir" "claim exit pid stderr.log stdout" "$(ls -A "$run.stage" | sort | tr '\n' ' ' | sed 's/ $//')"

# --- a second call after done: done again, no restart -----------------------
before="$(cat "$run/result.json")"
out="$(sw --run-dir "$run" --wait 5 -- "$tmp/fake" ok "$run")"
check "after done: done again" '.status == "done" and .ok == true' "$out"
is "after done: the command started once" 1 "$(starts)"
is "after done: result.json untouched" "$before" "$(cat "$run/result.json")"

# --- a job that needs three calls --------------------------------------------
new_case; export FAKE_GATE="$gate"
out="$(sw --run-dir "$run" --wait 1 -- "$tmp/fake" ok "$run")"
check "three calls: first is running after its wait" \
  '.status == "running" and .ok == null and .error_class == null and .waited_s >= 1 and .waited_s < 10' "$out"
out="$(sw --run-dir "$run" --wait 1 -- "$tmp/fake" ok "$run")"
check "three calls: second is running" '.status == "running" and .ok == null' "$out"
if [ -e "$run" ]; then fail "three calls: a running job's run dir is left alone"; else pass "three calls: a running job's run dir is left alone"; fi
: > "$gate"
out="$(sw --run-dir "$run" --wait 60 -- "$tmp/fake" ok "$run")"
check "three calls: third is done" '.status == "done" and .ok == true and .waited_s < 30' "$out"
is "three calls: the command started once" 1 "$(starts)"

# --- failures ----------------------------------------------------------------
new_case
out="$(sw --run-dir "$run" --wait 60 -- "$tmp/fake" fail "$run")"; rc=$?
check "failure envelope: failed with its error_class" '.status == "failed" and .ok == false and .error_class == "timeout"' "$out"
is "failure envelope: exit status 0" 0 "$rc"

new_case
out="$(sw --run-dir "$run" --wait 60 -- "$tmp/fake" stdout-only "$run")"
check "stdout-only envelope: failed with its error_class" '.status == "failed" and .ok == false and .error_class == "auth" and .waited_s < 30' "$out"
if [ -e "$run" ]; then fail "stdout-only envelope: no run dir made"; else pass "stdout-only envelope: no run dir made"; fi

new_case
out="$(sw --run-dir "$run" --wait 60 -- "$tmp/fake" stdout-tall "$run")"
check "stdout-only envelope: a pretty-printed object is read" '.status == "failed" and .ok == false and .error_class == "usage"' "$out"

new_case
out="$(sw --run-dir "$run" --wait 60 -- "$tmp/fake" silent "$run")"; rc=$?
check "silent death: no_envelope" '.status == "failed" and .ok == false and .error_class == "no_envelope" and .waited_s < 30' "$out"
is "silent death: exit status 0" 0 "$rc"
is "silent death: stderr kept beside the run dir" "dying" "$(cat "$run.stage/stderr.log")"
out="$(sw --run-dir "$run" --wait 5 -- "$tmp/fake" ok "$run")"
check "silent death: a later call fails the same way" '.status == "failed" and .error_class == "no_envelope"' "$out"
is "silent death: the command is not started again" 1 "$(starts)"

new_case; export FAKE_GATE="$gate"
out="$(sw --run-dir "$run" --wait 0 -- "$tmp/fake" ok "$run")"
if await_file "$run.stage/pid" && await_file "$FAKE_LOG.starts"; then
  kill -KILL -- "-$(cat "$run.stage/pid")" 2>/dev/null || true
  out="$(sw --run-dir "$run" --wait 60 -- "$tmp/fake" ok "$run")"
  check "killed job: no_envelope, known from its pid" '.status == "failed" and .error_class == "no_envelope" and .waited_s < 30' "$out"
else
  fail "killed job: the detached job started"
fi

new_case
out="$(sw --run-dir "$run" --wait 60 -- "$tmp/no-such-command" "$run")"
check "missing command: no_envelope" '.status == "failed" and .error_class == "no_envelope"' "$out"

new_case
out="$(sw --run-dir "$run" --wait 60 -- "$tmp/fake" garbage "$run")"
check "unreadable result.json after the job ended: bad_envelope" '.status == "failed" and .ok == false and .error_class == "bad_envelope"' "$out"
is "unreadable result.json is left as written" "not json" "$(cat "$run/result.json")"

new_case
mkdir -p "$run.stage"; echo 1000 > "$run.stage/claim"
out="$(sw --run-dir "$run" --wait 60 -- "$tmp/fake" ok "$run")"
check "a claim with no runner past the grace: start_failed" '.status == "failed" and .error_class == "start_failed" and .waited_s < 30' "$out"
is "a claim with no runner: nothing started" 0 "$(starts)"

# --- two first calls racing --------------------------------------------------
race_bad=0 race_detail=""
for round in $(seq 1 20); do
  new_case
  sw --run-dir "$run" --wait 60 -- "$tmp/fake" ok "$run" > "$tmp/race-a" 2>/dev/null &
  pa=$!
  sw --run-dir "$run" --wait 60 -- "$tmp/fake" ok "$run" > "$tmp/race-b" 2>/dev/null &
  pb=$!
  wait "$pa" || true; wait "$pb" || true
  s="$(starts)"
  a="$(jq -r '.status' "$tmp/race-a" 2>/dev/null || true)" b="$(jq -r '.status' "$tmp/race-b" 2>/dev/null || true)"
  if [ "$s" != 1 ] || [ "$a" != done ] || [ "$b" != done ]; then
    race_bad=$((race_bad + 1)); race_detail="$race_detail round $round: starts=$s a=$a b=$b;"
  fi
done
is "race: twenty rounds of two first calls each start the command once and both read done" "0 " "$race_bad $race_detail"

# --- arguments pass through unchanged ----------------------------------------
new_case
set -- 'two words' "it's" 'say "hi"' '' '*' '$HOME `id`' 'back\slash' '--wait' '--' $'line one\nline two'
printf '[%s]\n' ok "$run" "$@" > "$tmp/args-want"
out="$(sw --run-dir "$run" --wait 60 -- "$tmp/fake" ok "$run" "$@" <<<"from the caller")"
check "arguments: the job ran" '.status == "done"' "$out"
is "arguments: spaces, quotes and empties reach the command unchanged" "$(cat "$tmp/args-want")" "$(cat "$FAKE_LOG.args")"
is "the command's stdin is not the caller's" "" "$(cat "$FAKE_LOG.stdin")"
new_case
out="$(STAGE_WAIT_NO_SETSID=1 sw --run-dir "$run" --wait 60 -- "$tmp/fake" ok "$run" <<<"from the caller")"
is "the command's stdin is not the caller's (no-setsid)" "done " "$(jq -r '.status' <<<"$out") $(cat "$FAKE_LOG.stdin")"

# --- the job outlives the shell that started it -------------------------------
# The first call runs in a process group of its own that exits; the group then
# gets SIGTERM and the job's own group SIGHUP, which is what ends a job that
# was only put in the background. Once with the platform's detach, once with the
# no-setsid path forced.
for variant in default no-setsid; do
  new_case; export FAKE_GATE="$gate"
  (
    [ "$variant" = default ] || export STAGE_WAIT_NO_SETSID=1
    set -m
    bash "$helper" --run-dir "$run" --wait 0 -- "$tmp/fake" ok "$run" > "$tmp/survive-first" 2>/dev/null &
    echo $! > "$tmp/survive-pgid"
    wait
  )
  check "survival ($variant): the first call returns running at once" '.status == "running" and .waited_s < 10' "$(cat "$tmp/survive-first")"
  if await_file "$run.stage/pid" && await_file "$FAKE_LOG.starts"; then
    kill -TERM -- "-$(cat "$tmp/survive-pgid")" 2>/dev/null || true
    kill -HUP -- "-$(cat "$run.stage/pid")" 2>/dev/null || true
    sleep 0.3
    : > "$gate"
    out="$(bash -c 'bash "$0" --run-dir "$1" --wait 60 -- "$2" ok "$1"' "$helper" "$run" "$tmp/fake")"
    check "survival ($variant): the job outlives its caller's process group and a hangup" '.status == "done" and .ok == true' "$out"
    is "survival ($variant): the command started once" 1 "$(starts)"
  else
    fail "survival ($variant): the detached job started"
  fi
done

# --- usage errors --------------------------------------------------------------
new_case
usage() { # usage <name> <stage-wait args...>
  local name="$1" out rc=0; shift
  out="$(sw "$@" 2>/dev/null)" || rc=$?
  check "usage: $name" '.status == "failed" and .ok == false and .error_class == "usage" and (.waited_s | type) == "number" and has("run_dir")' "$out"
  is "usage: $name exits 2" 2 "$rc"
}
usage "no arguments"
usage "--run-dir missing" --wait 5 -- "$tmp/fake" ok "$run"
usage "command missing" --run-dir "$run"
usage "command missing after --" --run-dir "$run" --
usage "--wait not a number" --run-dir "$run" --wait soon -- "$tmp/fake" ok "$run"
usage "--wait negative" --run-dir "$run" --wait -1 -- "$tmp/fake" ok "$run"
usage "--wait above 540" --run-dir "$run" --wait 541 -- "$tmp/fake" ok "$run"
usage "unknown flag" --run-dir "$run" --timeout 5 -- "$tmp/fake" ok "$run"
mkdir -p "$tmp/used"; printf '{"ok":true}\n' > "$tmp/used/result.json"
usage "used run dir with no stage" --run-dir "$tmp/used" --wait 5 -- "$tmp/fake" ok "$tmp/used"
is "usage: nothing started, no stage left" "0 no" "$(starts) $(if ls -d "$tmp"/run"$n".stage "$tmp/used.stage" >/dev/null 2>&1; then echo yes; else echo no; fi)"
check "--wait 540 and a trailing slash are accepted" '.status == "done" and .run_dir == $ENV.run' \
  "$(sw --run-dir "$run/" --wait 540 -- "$tmp/fake" ok "$run")"

if [ "$fails" -gt 0 ]; then printf 'FAIL: %s stage-wait case(s)\n' "$fails"; exit 1; fi
printf 'PASS: stage-wait suite\n'
