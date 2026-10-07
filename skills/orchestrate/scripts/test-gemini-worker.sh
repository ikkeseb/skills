#!/usr/bin/env bash
# Hermetic black-box tests for gemini-worker.sh. A fake `agy` on a throwaway
# PATH stands in for the CLI, so no provider, login, network, or quota is used.
# Usage: bash skills/orchestrate/scripts/test-gemini-worker.sh

set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
helper="$script_dir/gemini-worker.sh"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
fails=0
pass() { printf 'ok    %s\n' "$1"; }
fail() { printf 'FAIL  %s\n' "$1"; fails=$((fails + 1)); }
check() { # check <name> <jq predicate> <json>
  if jq -e "$2" >/dev/null 2>&1 <<<"$3"; then pass "$1"; else fail "$1"; printf '      got: %.600s\n' "$3"; fi
}

mkdir -p "$tmp/bin" "$tmp/ws"
printf 'alpha\n' > "$tmp/ws/a.txt"
# The fake reads its behavior from FAKE_AGY_MODE (HOME is the helper's
# throwaway home, so no file under the real HOME can steer it).
cat > "$tmp/bin/agy" <<'FAKE'
#!/usr/bin/env bash
set -u
to_unix() { if command -v cygpath >/dev/null 2>&1; then cygpath -u "$1"; else printf '%s' "$1"; fi; }
# Blocks until the test releases the gate; far longer than the test waits, so
# a test that never sees its line fails instead of outwaiting the fake.
gate_wait() { local i=0; while [ ! -e "$FAKE_AGY_GATE" ] && [ "$i" -lt 600 ]; do sleep 0.2; i=$((i + 1)); done; }
case "${1:-}" in
  --version) echo "1.2.10"; exit 0 ;;
  models)
    [ "${FAKE_AGY_MODE:-}" = models-fail ] && { echo "error: authentication required" >&2; exit 1; }
    printf 'Fetching available models...\n'
    printf 'gemini-3.8-flash-high\tGemini 3.8 Flash (High)\ngemini-3.1-pro-high\tGemini 3.1 Pro (High)\n'
    exit 0 ;;
esac
schema="" model="" adddir=""
while [ $# -gt 0 ]; do
  case "$1" in
    --json-schema) schema="$2"; shift 2 ;;
    --model) model="$2"; shift 2 ;;
    --add-dir) adddir="$2"; shift 2 ;;
    *) shift ;;
  esac
done
input="$(cat)"
settings="$(to_unix "$HOME")/.gemini/antigravity-cli/settings.json"
isolation=ok
jq -e '.permissions.deny | index("write_file(*)") and index("command(*)") and index("mcp(*)")' "$settings" >/dev/null 2>&1 || isolation=no-deny-rules
[ -z "${GEMINI_API_KEY:-}" ] || isolation=api-key-leaked
[ "$(to_unix "$adddir")" = "$(pwd)" ] || isolation="add-dir-mismatch:$adddir"
content_len="$(jq -r '.message.content | length' <<<"$input" | tr -d '\r')"
global="$(head -1 "$(to_unix "$HOME")/.gemini/GEMINI.md" 2>/dev/null | tr -d '\r')"
token="$(to_unix "$HOME")/.gemini/antigravity-cli/antigravity-oauth-token"
login="$(head -1 "$token" 2>/dev/null | tr -d '\r')"
[ -z "$login" ] || printf 'REFRESHED\n' > "$token" # agy refreshes its token in place
echo '{"event":"init","conversation_id":"c1","init":{}}'
usage='{"input_tokens":100,"output_tokens":5,"thinking_tokens":2,"cache_read_tokens":50,"total_tokens":105}'
case "${FAKE_AGY_MODE:-success}" in
  success)
    jq -cn --argjson u "$usage" --arg t "isolation=$isolation global=${global:-none} login=${login:-none} len=$content_len"       '{event: "result", result: {conversation_id: "c1", status: "SUCCESS", response: ($t + "
"), usage: $u}}' ;;
  schema)
    jq -cn --argjson u "$usage" --arg iso "$isolation" \
      '{event: "result", result: {status: "SUCCESS", response: "{}", structured_output: {answer: $iso}, usage: $u}}' ;;
  no-structured)
    jq -cn '{event: "result", result: {status: "SUCCESS", response: "plain text"}}' ;;
  empty)
    jq -cn '{event: "result", result: {status: "SUCCESS", response: ""}}' ;;
  print-timeout)
    echo "[agy] print timeout after 5s with turn in progress; returning partial output" >&2
    jq -cn '{event: "result", result: {status: "SUCCESS", response: "", usage: {total_tokens: 0}}}' ;;
  unknown-model)
    jq -cn --arg m "$model" '{event: "result", result: {conversation_id: "", status: "ERROR", response: "", error: ("invalid model selection: model " + $m + " is not recognized as a known model")}}'
    exit 1 ;;
  auth) # a login that lapsed mid-session: the run's own flow fails, "timed out" included
    printf 'Waiting for authentication (timeout 60s)...\nerror: authentication failed or timed out\n' >&2
    jq -cn '{event: "result", result: {status: "ERROR", response: "", error: "authentication failed or timed out"}}'
    exit 1 ;;
  models-fail) # the precheck must stop the run before the prompt arrives
    [ -z "$input" ] || echo "PROMPT-SENT" >&2
    exit 1 ;;
  quota)
    jq -cn '{event: "result", result: {status: "ERROR", response: "", error: "RESOURCE_EXHAUSTED: quota exceeded"}}'
    exit 1 ;;
  denied)
    echo 'jetski: a tool required the "command" permission that headless mode cannot prompt for, so it was auto-denied.' >&2
    jq -cn '{event: "result", result: {status: "SUCCESS", response: "partial", denied_actions: [{action: "command", display_name: "RunCommand"}]}}' ;;
  write)
    printf 'x\n' > "$(pwd)/written.txt"
    jq -cn '{event: "result", result: {status: "SUCCESS", response: "wrote"}}' ;;
  image) # agy keeps generated images under HOME, beside the user's uploads
    brain="$(to_unix "$HOME")/.gemini/antigravity-cli/brain/c1"
    mkdir -p "$brain/.user_uploaded"
    printf 'img\n' > "$brain/icon_1.jpg"; printf 'up\n' > "$brain/.user_uploaded/upload.png"
    jq -cn '{event: "result", result: {status: "SUCCESS", response: "made icon_1.jpg"}}' ;;
  hang)
    sleep 30 ;;
  steps) # the shapes agy's stream-json sends, plus lines the view must skip
    cat <<'EVENTS'
{"event":"step_update","step_update":{"step_index":0,"state":"DONE","step_type":"user_input"}}
{"event":"step_update","step_update":{"step_index":1,"state":"DONE","step_type":"agent_response","duration_seconds":1.5}}
{"event":"step_update","step_update":{"step_index":2,"state":"ACTIVE","step_type":"tool","tool_name":"view_file","tool_info":{"name":"view_file","parameters":{"AbsolutePath":"/x/a.txt"}}}}
{"event":"step_update","step_update":{"step_index":2,"state":"DONE","step_type":"tool","tool_name":"view_file","tool_info":{"name":"view_file","parameters":{"AbsolutePath":"/x/a.txt"},"output":"1 lines"}}}
{"event":"step_update","step_update":{"step_index":3,"state":"ACTIVE","step_type":"tool","tool_name":"grep_search","tool_info":{"name":"grep_search","parameters":{"Query":"alpha","SearchPath":"/x","MatchPerLine":true}}}}
{"event":"step_update","step_update":{"step_index":3,"state":"DONE","step_type":"tool","tool_name":"grep_search","tool_info":{"name":"grep_search","parameters":{"Query":"alpha","SearchPath":"/x","MatchPerLine":true}}}}
{"event":"mystery","text":"SKIPPED-EVENT"}
{"event":"step_update","step_update":{"step_index":3,"state":"DONE","step_type":"planner","text_delta":"SKIPPED-TYPE"}}
{"event":"step_update","step_update":{"step_index":"4","state":"DONE","step_type":"agent_response","text_delta":"SKIPPED-SHAPE"}}
{"event":"step_update","step_update":{"step_index":4,"state":"ACTIVE","step_type":"agent_response","text_delta":"Hello \u001b[31m"}}
{"event":"step_update","step_update":{"step_index":4,"state":"ACTIVE","step_type":"agent_response","text_delta":"wor\u009bld\n"}}
{"event":"step_update","step_update":{"step_index":4,"state":"DONE","step_type":"agent_response","text_delta":"a\tb\u007fc done.\n","duration_seconds":2}}
EVENTS
    jq -cn --arg p "/$(head -c 300 /dev/zero | tr '\0' 'l')" \
      '{event: "step_update", step_update: {step_index: 5, state: "ACTIVE", step_type: "tool", tool_name: "view_file", tool_info: {parameters: {AbsolutePath: $p}}}}'
    jq -cn '{event: "result", result: {status: "SUCCESS", response: "stepped"}}'
    echo 'not json SKIPPED-TEXT' ;; # after the result: the helper's own parser stops at such a line
  half) # a line agy is still writing: complete JSON, but its newline arrives only once the gate file exists
    echo '{"event":"step_update","step_update":{"step_index":1,"state":"ACTIVE","step_type":"tool","tool_name":"view_file","tool_info":{"parameters":{"AbsolutePath":"/x/first.txt"}}}}'
    printf '%s' '{"event":"step_update","step_update":{"step_index":2,"state":"ACTIVE","step_type":"tool","tool_name":"view_file","tool_info":{"parameters":{"AbsolutePath":"/x/HALFLINE.txt"}}}}'
    gate_wait
    printf '\n'
    jq -cn '{event: "result", result: {status: "SUCCESS", response: "halved"}}' ;;
  message) # one message, cut by other events and by the gate (so by a tick), then closed three times
    cat <<'EVENTS'
{"event":"step_update","step_update":{"step_index":1,"state":"ACTIVE","step_type":"tool","tool_name":"view_file","tool_info":{"parameters":{"AbsolutePath":"/x/before.txt"}}}}
{"event":"step_update","step_update":{"step_index":2,"state":"ACTIVE","step_type":"agent_response","text_delta":"Carried "}}
{"event":"mystery","text":"SKIPPED-EVENT"}
EVENTS
    gate_wait
    cat <<'EVENTS'
{"event":"step_update","step_update":{"step_index":2,"state":"DONE","step_type":"planner","text_delta":"SKIPPED-TYPE"}}
{"event":"step_update","step_update":{"step_index":2,"state":"ACTIVE","step_type":"agent_response","text_delta":"over"}}
{"event":"step_update","step_update":{"step_index":3,"state":"ACTIVE","step_type":"tool","tool_name":"view_file","tool_info":{"parameters":{"AbsolutePath":"/x/between.txt"}}}}
{"event":"mystery","text":"SKIPPED-EVENT"}
{"event":"step_update","step_update":{"step_index":2,"state":"DONE","step_type":"agent_response","duration_seconds":2}}
{"event":"step_update","step_update":{"step_index":2,"state":"DONE","step_type":"agent_response","duration_seconds":2}}
{"event":"step_update","step_update":{"step_index":2,"state":"DONE","step_type":"agent_response","text_delta":"REPEATED"}}
EVENTS
    jq -cn '{event: "result", result: {status: "SUCCESS", response: "carried"}}' ;;
  malformed) # step_update events with a wrong nested shape, then a valid one
    cat <<'EVENTS'
{"event":"step_update","step_update":{"step_index":1,"state":"ACTIVE","step_type":"tool","tool_name":"BADSHAPE-info","tool_info":"a string"}}
{"event":"step_update","step_update":{"step_index":2,"state":"ACTIVE","step_type":"tool","tool_name":"list_dir","tool_info":{"parameters":["BADSHAPE-array"]}}}
{"event":"step_update","step_update":{"step_index":"3","state":"ACTIVE","step_type":"tool","tool_name":"BADSHAPE-index","tool_info":{"parameters":{"AbsolutePath":"/x/no.txt"}}}}
{"event":"step_update","step_update":{"step_index":3.5,"state":"ACTIVE","step_type":"tool","tool_name":"BADSHAPE-fraction"}}
{"event":"step_update","step_update":{"step_index":1e30,"state":"ACTIVE","step_type":"tool","tool_name":"BADSHAPE-large"}}
{"event":"step_update","step_update":["BADSHAPE-update"]}
"BADSHAPE-scalar"
{"event":"step_update","step_update":{"step_index":4,"state":"DONE","step_type":"agent_response","text_delta":{"BADSHAPE":"delta"}}}
{"event":"step_update","step_update":{"step_index":5,"state":"ACTIVE","step_type":"tool","tool_name":"view_file","tool_info":{"parameters":{"AbsolutePath":"/x/after-malformed.txt"}}}}
EVENTS
    jq -cn '{event: "result", result: {status: "SUCCESS", response: "survived"}}' ;;
  huge) # one event larger than a tick reads, between two ordinary ones
    echo '{"event":"step_update","step_update":{"step_index":1,"state":"ACTIVE","step_type":"tool","tool_name":"view_file","tool_info":{"parameters":{"AbsolutePath":"/x/before-huge.txt"}}}}'
    head -c 600000 /dev/zero | tr '\0' 'h' | jq -Rc \
      '{event: "step_update", step_update: {step_index: 2, state: "ACTIVE", step_type: "tool", tool_name: "HUGE-EVENT", tool_info: {parameters: {AbsolutePath: .}}}}'
    echo '{"event":"step_update","step_update":{"step_index":3,"state":"ACTIVE","step_type":"tool","tool_name":"view_file","tool_info":{"parameters":{"AbsolutePath":"/x/after-huge.txt"}}}}'
    jq -cn '{event: "result", result: {status: "SUCCESS", response: "skipped"}}' ;;
  edge) # one unfinished event of exactly FAKE_AGY_EDGE bytes; its newline arrives once the gate file exists
    echo '{"event":"step_update","step_update":{"step_index":1,"state":"ACTIVE","step_type":"tool","tool_name":"view_file","tool_info":{"parameters":{"AbsolutePath":"/x/before-edge.txt"}}}}'
    pre='{"event":"step_update","step_update":{"step_index":2,"state":"ACTIVE","step_type":"tool","tool_name":"EDGE-EVENT","tool_info":{"parameters":{"AbsolutePath":"/x/edge.txt"}},"pad":"'
    printf '%s' "$pre"; head -c "$((FAKE_AGY_EDGE - ${#pre} - 3))" /dev/zero | tr '\0' 'p'; printf '%s' '"}}'
    gate_wait
    printf '\n'
    echo '{"event":"step_update","step_update":{"step_index":3,"state":"ACTIVE","step_type":"tool","tool_name":"view_file","tool_info":{"parameters":{"AbsolutePath":"/x/after-edge.txt"}}}}'
    jq -cn '{event: "result", result: {status: "SUCCESS", response: "edged"}}' ;;
  noise) # more short lines than one tick may hand its parser, far fewer bytes than one tick reads
    jq -cn 'range(5000) | {event: "noise"}'
    echo '{"event":"step_update","step_update":{"step_index":1,"state":"ACTIVE","step_type":"tool","tool_name":"view_file","tool_info":{"parameters":{"AbsolutePath":"/x/after-noise.txt"}}}}'
    jq -cn '{event: "result", result: {status: "SUCCESS", response: "noisy"}}' ;;
  padded) # a message whose text is 250 KB of spaces between two letters
    { printf x; head -c 250000 /dev/zero | tr '\0' ' '; printf y; } | jq -Rsc \
      '{event: "step_update", step_update: {step_index: 1, state: "DONE", step_type: "agent_response", text_delta: .}}'
    echo '{"event":"step_update","step_update":{"step_index":2,"state":"ACTIVE","step_type":"tool","tool_name":"view_file","tool_info":{"parameters":{"AbsolutePath":"/x/after-padded.txt"}}}}'
    jq -cn '{event: "result", result: {status: "SUCCESS", response: "padded"}}' ;;
  flood) # more progress text than a pipe buffer holds
    jq -cn --arg p "/$(head -c 150 /dev/zero | tr '\0' 'f')" 'range(1; 3001)
      | {event: "step_update", step_update: {step_index: ., state: "ACTIVE", step_type: "tool", tool_name: "view_file", tool_info: {parameters: {AbsolutePath: $p}}}}'
    jq -cn '{event: "result", result: {status: "SUCCESS", response: "flooded"}}' ;;
  no-result)
    echo "crash" >&2; exit 3 ;;
esac
FAKE
chmod +x "$tmp/bin/agy"
export PATH="$tmp/bin:$PATH"
export GEMINI_API_KEY="must-not-reach-the-worker"
# The user's global instruction file must reach the worker's throwaway HOME.
export HOME="$tmp/userhome"
mkdir -p "$HOME/.gemini"
printf 'GLOBAL-RULE\n' > "$HOME/.gemini/GEMINI.md"
# So must a file-based login (agy without an OS keyring).
mkdir -p "$HOME/.gemini/antigravity-cli"
printf 'FAKE-LOGIN\n' > "$HOME/.gemini/antigravity-cli/antigravity-oauth-token"

printf 'Summarize a.txt.\n' > "$tmp/prompt.md"
printf '%s\n' '{"type":"object","properties":{"answer":{"type":"string"}},"required":["answer"]}' > "$tmp/schema.json"
run() { # run <mode> [extra helper args...]; called in $(...), so no counters
  local mode="$1"; shift
  FAKE_AGY_MODE="$mode" bash "$helper" run --model gemini-3.8-flash-high \
    --workspace "$tmp/ws" --prompt-file "$tmp/prompt.md" --run-dir "$(mktemp -d "$tmp/run-$mode.XXXXXX")" "$@" 2>/dev/null
}

out="$(run success)"
check "success: ok, text result, spend" \
  '.ok == true and .lane == "agy" and (.result | startswith("isolation=")) and .spend.total_tokens == 105 and .workspace_changed == false' "$out"
check "isolation: deny rules present, API key stripped, workspace is the add-dir" \
  '.result | test("^isolation=ok ")' "$out"
check "the global GEMINI.md reaches the throwaway HOME" '.result | test(" global=GLOBAL-RULE ")' "$out"
check "a file-based login reaches the throwaway HOME" '.result | test(" login=FAKE-LOGIN ")' "$out"
if [ "$(cat "$HOME/.gemini/antigravity-cli/antigravity-oauth-token")" = FAKE-LOGIN ]; then pass "the real token file is untouched"; else fail "the real token file is untouched"; fi
if [ "$(jq -c . "$(jq -r .run_dir <<<"$out" | tr -d '\r')/result.json")" = "$(jq -c . <<<"$out")" ]; then pass "result.json mirrors stdout"; else fail "result.json mirrors stdout"; fi

head -c 60000 /dev/zero | tr '\0' 'x' > "$tmp/long.md"
out="$(FAKE_AGY_MODE=success bash "$helper" run --model gemini-3.8-flash-high --workspace "$tmp/ws" \
  --prompt-file "$tmp/long.md" --run-dir "$tmp/run-long" 2>/dev/null)"
check "a 60 KB prompt arrives whole on stdin" '.ok == true and (.result | test("len=60000$"))' "$out"

check "schema: structured_output becomes the result" '.ok == true and .result.answer == "ok"' "$(run schema --schema-file "$tmp/schema.json")"
check "schema without structured_output fails" '.ok == false and .error_class == "schema_missing"' "$(run no-structured --schema-file "$tmp/schema.json")"
check "empty answer fails" '.ok == false and .error_class == "empty_result"' "$(run empty)"
check "agy print timeout (reported as SUCCESS) is a timeout" '.ok == false and .error_class == "timeout"' "$(run print-timeout)"
check "unknown model" '.ok == false and .error_class == "model_unknown"' "$(run unknown-model)"
check "a failed login flow is auth, not timeout" '.ok == false and .error_class == "auth"' "$(run auth)"
check "logged out: run fails auth before the prompt is sent" \
  '.ok == false and .error_class == "auth" and (.status // null) == null' "$(run models-fail)"
check "quota exhausted" '.ok == false and .error_class == "quota"' "$(run quota)"
check "soft-denied tool fails and keeps the partial result" \
  '.ok == false and .error_class == "tool_denied" and .result == "partial" and (.denied_actions | length) == 1' "$(run denied)"
out="$(run write)"
check "a workspace write fails the run and names the file" \
  '.ok == false and .error_class == "workspace_changed" and (.changed_files | any(test("written.txt$")))' "$out"
rm -f "$tmp/ws/written.txt"
out="$(run image)"
check "a generated image outlives the throwaway HOME; uploads stay out" \
  '.ok == true and (.images | length) == 1 and (.images[0] | test("/images/icon_1.jpg$"))' "$out"
if [ -f "$(jq -r '.images[0]' <<<"$out" | tr -d '\r')" ]; then pass "the kept image is on disk"; else fail "the kept image is on disk"; fi
check "no image, empty list" '.images == []' "$(run success)"
check "a crash without a result event" '.ok == false and .error_class == "agy_failed"' "$(run no-result)"
check "the watchdog kills a process that outlives the deadline" \
  '.ok == false and .error_class == "timeout" and .spend.wall_seconds < 20' \
  "$(GEMINI_WORKER_GRACE=2 run hang --timeout 1)"

for m in gemini-3.1-pro-high gemini-3.7-flash-high gemini-3.8-flash-medium claude-opus-4-6-thinking gemini-4.0-flash-lite-high \
    claude-opus-5-5-low claude-sonnet-5-5-medium claude-opus-4-8-high gpt-oss-120b-medium claude-opus-5-5-high-x; do
  check "floor: $m refused before agy runs" '.ok == false and .error_class == "model_floor" and (.status // null) == null' \
    "$(FAKE_AGY_MODE=success bash "$helper" run --model "$m" --workspace "$tmp/ws" --prompt-file "$tmp/prompt.md" --run-dir "$(mktemp -d "$tmp/run-floor.XXXXXX")")"
done
check "floor: a newer Gemini at -high passes" '.ok == true' \
  "$(FAKE_AGY_MODE=success bash "$helper" run --model gemini-4.0-pro-high --workspace "$tmp/ws" --prompt-file "$tmp/prompt.md" --run-dir "$(mktemp -d "$tmp/run-floor.XXXXXX")" 2>/dev/null)"
for m in claude-opus-5-5-high claude-opus-5-5-medium claude-sonnet-5-5-high claude-opus-6-0-medium; do
  check "floor: reserve Claude reader $m passes" '.ok == true' \
    "$(FAKE_AGY_MODE=success bash "$helper" run --model "$m" --workspace "$tmp/ws" --prompt-file "$tmp/prompt.md" --run-dir "$(mktemp -d "$tmp/run-floor.XXXXXX")" 2>/dev/null)"
done

# --- progress view on stderr ---------------------------------------------------
view_run() { # view_run <name> <mode> [extra helper args...]: $tmp/<name>.json|.err, run dir $tmp/run-<name>
  local name="$1" mode="$2"; shift 2
  FAKE_AGY_MODE="$mode" bash "$helper" run --model gemini-3.8-flash-high --workspace "$tmp/ws" \
    --prompt-file "$tmp/prompt.md" --run-dir "$tmp/run-$name" "$@" > "$tmp/$name.json" 2> "$tmp/$name.err" || true
}
has_line() { # has_line <name> <file> <exact line>: the line is there exactly once
  if [ "$(grep -Fxc -- "$3" "$2" || true)" = 1 ]; then pass "$1"; else fail "$1"; printf '      want once: %.300s\n      got:\n' "$3"; sed 's/^/        /' "$2" | cut -c1-300; fi
}
one_json() { # one_json <name> <stdout file> <run dir>: one JSON object, byte-for-byte result.json
  if [ "$(jq -s 'length == 1 and (.[0] | type) == "object"' "$2" 2>/dev/null)" = true ] && [ "$(wc -l < "$2")" -eq 1 ] \
      && cmp -s "$2" "$3/result.json"; then pass "$1"; else fail "$1"; fi
}
secs() { jq -r '.spend.wall_seconds' "$1" | tr -d '\r'; }

view_run steps steps
banner="[gemini-worker] start model=gemini-3.8-flash-high run-dir=$tmp/run-steps"
if [ "$(head -1 "$tmp/steps.err")" = "$banner" ]; then pass "progress: the start banner is the first stderr line"; else fail "progress: the start banner is the first stderr line"; fi
has_line "progress: a tool step prints once (ACTIVE, then DONE) with its file path" "$tmp/steps.err" '[gemini-worker] $ view_file /x/a.txt'
has_line "progress: a search step prints its pattern" "$tmp/steps.err" '[gemini-worker] $ grep_search alpha'
has_line "progress: a completed message prints its joined text, control characters (ESC, C1, newline, TAB, DEL) as spaces" \
  "$tmp/steps.err" '[gemini-worker] > Hello  [31mwor ld a b c done.'
if LC_ALL=C grep -q "$(printf '[\001-\011\013-\037\177]')" "$tmp/steps.err" || LC_ALL=C grep -q "$(printf '\302[\200-\237]')" "$tmp/steps.err"; then
  fail "progress: no control byte from worker text reaches stderr"; else pass "progress: no control byte from worker text reaches stderr"; fi
has_line "progress: a long line is cut at 200 characters" "$tmp/steps.err" \
  "[gemini-worker] \$ view_file /$(head -c 170 /dev/zero | tr '\0' 'l')…"
has_line "progress: the closing line comes from the envelope" "$tmp/steps.err" \
  "[gemini-worker] end ok=true steps=6 $(secs "$tmp/steps.json")s"
if [ "$(wc -l < "$tmp/steps.err")" -eq 6 ] && ! grep -q SKIPPED "$tmp/steps.err" \
    && [ "$(tail -1 "$tmp/steps.err" | cut -c1-23)" = '[gemini-worker] end ok=' ]; then
  pass "progress: unknown events, non-JSON and wrong-typed lines print nothing; the closing line is last"
else fail "progress: unknown events, non-JSON and wrong-typed lines print nothing; the closing line is last"; sed 's/^/        /' "$tmp/steps.err" | cut -c1-300; fi
one_json "progress: stdout is one JSON object, byte-for-byte result.json" "$tmp/steps.json" "$tmp/run-steps"
check "progress: the steps run succeeded with the fake's answer" '.ok == true and .result == "stepped"' "$(cat "$tmp/steps.json")"

view_run quiet steps --no-progress
if [ "$(cat "$tmp/quiet.err")" = "[gemini-worker] start model=gemini-3.8-flash-high run-dir=$tmp/run-quiet" ]; then
  pass "--no-progress keeps the banner and prints nothing else"; else fail "--no-progress keeps the banner and prints nothing else"; sed 's/^/        /' "$tmp/quiet.err" | cut -c1-300; fi
if [ "$(jq -cS 'del(.run_dir, .spend.wall_seconds)' "$tmp/quiet.json")" = "$(jq -cS 'del(.run_dir, .spend.wall_seconds)' "$tmp/steps.json")" ]; then
  pass "--no-progress leaves the envelope unchanged"; else fail "--no-progress leaves the envelope unchanged"; fi

view_run failing no-result
has_line "progress: a failed run closes with ok=false" "$tmp/failing.err" "[gemini-worker] end ok=false steps=0 $(secs "$tmp/failing.json")s"
# The closing line against the envelope on disk, field by field.
closing() { jq -r --arg n "$2" '"[gemini-worker] end ok=\(.ok) steps=\($n) \(.spend.wall_seconds)s"' "$1" | tr -d '\r'; }
if [ "$(tail -1 "$tmp/steps.err")" = "$(closing "$tmp/run-steps/result.json" 6)" ] \
    && [ "$(tail -1 "$tmp/failing.err")" = "$(closing "$tmp/run-failing/result.json" 0)" ] \
    && [ "$(jq -r .ok "$tmp/run-steps/result.json" | tr -d '\r')" != "$(jq -r .ok "$tmp/run-failing/result.json" | tr -d '\r')" ]; then
  pass "progress: the closing line carries the envelope's own ok and seconds, on success and on failure"
else fail "progress: the closing line carries the envelope's own ok and seconds, on success and on failure"
  { tail -1 "$tmp/steps.err"; tail -1 "$tmp/failing.err"; } | sed 's/^/        /' | cut -c1-300; fi

view_run malformed malformed
has_line "progress: an event after malformed ones still prints" "$tmp/malformed.err" '[gemini-worker] $ view_file /x/after-malformed.txt'
if [ "$(cat "$tmp/malformed.err")" = "[gemini-worker] start model=gemini-3.8-flash-high run-dir=$tmp/run-malformed
[gemini-worker] \$ list_dir
[gemini-worker] \$ view_file /x/after-malformed.txt
[gemini-worker] end ok=true steps=6 $(secs "$tmp/malformed.json")s" ]; then
  pass "progress: a malformed event prints nothing and leaves the step count alone"
else fail "progress: a malformed event prints nothing and leaves the step count alone"; sed 's/^/        /' "$tmp/malformed.err" | cut -c1-300; fi
one_json "progress: stdout is still one JSON object after malformed events" "$tmp/malformed.json" "$tmp/run-malformed"

view_run huge huge
has_line "progress: an event after one too large to read still prints" "$tmp/huge.err" '[gemini-worker] $ view_file /x/after-huge.txt'
if [ "$(wc -l < "$tmp/huge.err")" -eq 4 ] && ! grep -q HUGE-EVENT "$tmp/huge.err" \
    && [ "$(grep -Fxc '[gemini-worker] $ view_file /x/before-huge.txt' "$tmp/huge.err" || true)" = 1 ]; then
  pass "progress: an event larger than one read is skipped unparsed"
else fail "progress: an event larger than one read is skipped unparsed"; sed 's/^/        /' "$tmp/huge.err" | cut -c1-300; fi
check "progress: the envelope still carries the result behind the huge event" '.ok == true and .result == "skipped"' "$(cat "$tmp/huge.json")"

view_run backlog flood
if [ "$(grep -c '^\[gemini-worker\] \$ view_file /f' "$tmp/backlog.err" || true)" = 3000 ] \
    && [ "$(tail -1 "$tmp/backlog.err")" = "$(closing "$tmp/run-backlog/result.json" 3001)" ]; then
  pass "progress: a backlog larger than one read is printed in full"
else fail "progress: a backlog larger than one read is printed in full"
  printf '      lines: %s, last: %.200s\n' "$(wc -l < "$tmp/backlog.err")" "$(tail -1 "$tmp/backlog.err")"; fi

# Gated runs, side by side. Each fake stops at its gate; the test waits
# for the first step to show on stderr, then for two more ticks, and looks at
# what is there while the gated workers are provably still running.
#   half:    the second event is complete JSON without its newline. It must not
#            have printed (nor been counted as read); once the newline lands
#            it prints, once.
#   message: a message is open, with an unknown event after its first piece.
#            The pieces after the gate arrive ticks later and must join it.
#   edge:    an unfinished event one byte under, at, and one byte over the
#            largest line one tick reads (262144 bytes with its newline). The
#            first two must wait for the newline and then print once; the
#            third cannot fit and is skipped, and what follows it prints.
# Two ungated runs ride along, each bounding work the output cannot show:
#   noise:   a `jq` on PATH counts what each tick hands the parser. No tick may
#            hand it more than 2000 lines or 262144 bytes.
#   padded:  the message text must be cut to 200 characters before its
#            trailing whitespace is stripped: on the whole text that strip
#            takes minutes, the read's two-second alarm ends it every tick,
#            and nothing prints.
mkdir -p "$tmp/spy"
real_jq="$(type -P jq)"
cat > "$tmp/spy/jq" <<'SPY'
#!/usr/bin/env bash
# Records the line and byte count of every slurped raw read, then runs jq on it.
case " $* " in
  *" -Rrs "*) cat > "$SPY_DIR/in"; printf '%s %s\n' "$(wc -l < "$SPY_DIR/in")" "$(wc -c < "$SPY_DIR/in")" >> "$SPY_DIR/log"
    exec "$REAL_JQ" "$@" < "$SPY_DIR/in" ;;
esac
exec "$REAL_JQ" "$@"
SPY
chmod +x "$tmp/spy/jq"
SPY_DIR="$tmp/spy" REAL_JQ="$real_jq" PATH="$tmp/spy:$PATH" view_run noise noise &
noise_pid=$!
view_run padded padded &
padded_pid=$!
edge_max=262143 edge_pids=""
for n in $((edge_max - 1)) "$edge_max" $((edge_max + 1)); do
  FAKE_AGY_GATE="$tmp/gate" FAKE_AGY_EDGE="$n" view_run "edge-$n" edge &
  edge_pids="$edge_pids $!"
done
FAKE_AGY_GATE="$tmp/gate" view_run half half &
half_pid=$!
FAKE_AGY_GATE="$tmp/gate" view_run message message &
message_pid=$!
edges_started() { local n; for n in $((edge_max - 1)) "$edge_max" $((edge_max + 1)); do grep -q before-edge.txt "$tmp/edge-$n.err" || return 1; done; }
i=0; while ! { grep -q first.txt "$tmp/half.err" && grep -q before.txt "$tmp/message.err" && edges_started; } 2>/dev/null && [ "$i" -lt 100 ]; do sleep 0.2; i=$((i + 1)); done
sleep 3
edge_early="$(cat "$tmp"/edge-*.err | grep -c EDGE-EVENT || true)"
for pid in $edge_pids; do kill -0 "$pid" 2>/dev/null || edge_early=ended; done
early="$(grep -c HALF "$tmp/half.err" || true)"
first="$(grep -c first.txt "$tmp/half.err" || true)"
before="$(grep -c before.txt "$tmp/message.err" || true)"
# Still running: the helper is alive, no envelope is out, no result event yet.
running=true
kill -0 "$half_pid" 2>/dev/null && kill -0 "$message_pid" 2>/dev/null || running=false
[ ! -s "$tmp/half.json" ] && [ ! -e "$tmp/run-half/result.json" ] && [ ! -e "$tmp/gate" ] || running=false
! grep -q '"event":"result"' "$tmp/run-half/events.jsonl" 2>/dev/null || running=false
: > "$tmp/gate"
wait "$half_pid" || true
wait "$message_pid" || true
for pid in $edge_pids "$noise_pid" "$padded_pid"; do wait "$pid" || true; done
if [ "$running" = true ] && [ "$first" = 1 ] && [ "$before" = 1 ]; then pass "progress: a step line is on stderr while the worker is still running, before any envelope"
else fail "progress: a step line is on stderr while the worker is still running, before any envelope"; printf '      running=%s first=%s before=%s\n' "$running" "$first" "$before"; fi
if [ "$running" = true ] && [ "$early" = 0 ] && [ "$(grep -Fxc '[gemini-worker] $ view_file /x/HALFLINE.txt' "$tmp/half.err" || true)" = 1 ]; then
  pass "progress: a complete JSON line without its newline waits for it, then prints once"
else fail "progress: a complete JSON line without its newline waits for it, then prints once"; printf '      running=%s early=%s\n' "$running" "$early"; sed 's/^/        /' "$tmp/half.err" | cut -c1-300; fi
one_json "progress: stdout is still one JSON object after a held line" "$tmp/half.json" "$tmp/run-half"
has_line "progress: a message cut by other events and by ticks prints whole" "$tmp/message.err" '[gemini-worker] > Carried over'
if [ "$(grep -c '^\[gemini-worker\] > ' "$tmp/message.err" || true)" = 1 ] && ! grep -qE 'REPEATED|SKIPPED' "$tmp/message.err" \
    && [ "$(wc -l < "$tmp/message.err")" -eq 5 ]; then
  pass "progress: a repeated DONE for a printed message prints nothing more"
else fail "progress: a repeated DONE for a printed message prints nothing more"; sed 's/^/        /' "$tmp/message.err" | cut -c1-300; fi

# The event is line 3 of events.jsonl (init, before-edge, the event), so its
# size on disk is checked too: each case is the boundary it claims to be.
edge_case() { # edge_case <name> <event bytes> <times the event must print>
  local size
  size="$(sed -n 3p "$tmp/run-edge-$2/events.jsonl" | wc -c)"
  if [ "$edge_early" = 0 ] && [ "$size" -eq "$(($2 + 1))" ] \
      && [ "$(grep -Fxc '[gemini-worker] $ EDGE-EVENT /x/edge.txt' "$tmp/edge-$2.err" || true)" = "$3" ] \
      && [ "$(grep -Fxc '[gemini-worker] $ view_file /x/after-edge.txt' "$tmp/edge-$2.err" || true)" = 1 ] \
      && [ "$(wc -l < "$tmp/edge-$2.err")" -eq "$((4 + $3))" ]; then pass "$1"
  else fail "$1"; printf '      early=%s bytes-with-newline=%s\n' "$edge_early" "$size"; sed 's/^/        /' "$tmp/edge-$2.err" | cut -c1-300; fi
}
edge_case "progress: an unfinished event one byte under the largest line that fits waits, then prints once" "$((edge_max - 1))" 1
edge_case "progress: an unfinished event exactly the largest line that fits waits, then prints once" "$edge_max" 1
edge_case "progress: an event one byte over the largest line that fits is skipped; the next one prints" "$((edge_max + 1))" 0

if awk '$1 > 2000 || $2 > 262144 { over = 1 } { lines += $1 } END { exit !(NR > 0 && !over && lines >= 5000) }' "$tmp/spy/log" 2>/dev/null \
    && [ "$(grep -Fxc '[gemini-worker] $ view_file /x/after-noise.txt' "$tmp/noise.err" || true)" = 1 ]; then
  pass "progress: no tick hands the parser more than 2000 lines or 262144 bytes"
else fail "progress: no tick hands the parser more than 2000 lines or 262144 bytes"
  printf '      largest read: %s lines, %s bytes\n' "$(sort -n "$tmp/spy/log" 2>/dev/null | tail -1 | awk '{print $1}')" "$(sort -k2 -n "$tmp/spy/log" 2>/dev/null | tail -1 | awk '{print $2}')"; fi
if [ "$(cat "$tmp/padded.err")" = "[gemini-worker] start model=gemini-3.8-flash-high run-dir=$tmp/run-padded
[gemini-worker] > x
[gemini-worker] \$ view_file /x/after-padded.txt
[gemini-worker] end ok=true steps=3 $(secs "$tmp/padded.json")s" ]; then
  pass "progress: message text is cut before its trailing whitespace is stripped"
else fail "progress: message text is cut before its trailing whitespace is stripped"; sed 's/^/        /' "$tmp/padded.err" | cut -c1-300; fi

# A stderr reader that never reads: the pipe fills, the view drops lines, and
# the run still delivers its envelope within the write bounds.
mkfifo "$tmp/stalled"
sleep 25 < "$tmp/stalled" &
reader_pid=$!
t0=$SECONDS
FAKE_AGY_MODE=flood bash "$helper" run --model gemini-3.8-flash-high --workspace "$tmp/ws" \
  --prompt-file "$tmp/prompt.md" --run-dir "$tmp/run-flood" > "$tmp/flood.json" 2> "$tmp/stalled" || true
took=$((SECONDS - t0))
kill "$reader_pid" 2>/dev/null || true
if [ "$took" -lt 15 ] && [ "$(jq -r '.ok' "$tmp/flood.json" 2>/dev/null | tr -d '\r')" = true ]; then
  pass "progress: a stderr reader that stops reading cannot hang the run"
else fail "progress: a stderr reader that stops reading cannot hang the run"; printf '      took %ss\n' "$took"; fi
one_json "progress: stdout is still one JSON object when stderr is stalled" "$tmp/flood.json" "$tmp/run-flood"

check "usage: --model required" '.error_class == "usage"' \
  "$(bash "$helper" run --prompt-file "$tmp/prompt.md")"
mkdir -p "$tmp/full"; : > "$tmp/full/x"
check "usage: non-empty run dir refused" '.error_class == "usage"' \
  "$(bash "$helper" run --model m --prompt-file "$tmp/prompt.md" --workspace "$tmp/ws" --run-dir "$tmp/full")"
check "usage: run dir inside the workspace refused" '.error_class == "usage"' \
  "$(bash "$helper" run --model m --prompt-file "$tmp/prompt.md" --workspace "$tmp/ws" --run-dir "$tmp/ws/run")"
if [ -e "$tmp/ws/run" ]; then fail "refused run dir left nothing behind"; else pass "refused run dir left nothing behind"; fi
check "usage: bad timeout" '.error_class == "usage"' \
  "$(bash "$helper" run --model m --prompt-file "$tmp/prompt.md" --timeout 0)"

check "probe: models listed" '.ok == true and .authenticated == true and .models == ["gemini-3.8-flash-high","gemini-3.1-pro-high"]' \
  "$(bash "$helper" probe)"
check "probe: failing models call reads as not logged in" '.ok == false and .authenticated == false and .error_class == "auth"' \
  "$(FAKE_AGY_MODE=models-fail bash "$helper" probe)"

if [ "$fails" -gt 0 ]; then printf 'FAIL: %s gemini-worker case(s)\n' "$fails"; exit 1; fi
printf 'PASS: gemini-worker suite\n'
