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
case "${1:-}" in
  --version) echo "1.2.10"; exit 0 ;;
  models)
    [ "${FAKE_AGY_MODE:-}" = models-fail ] && { echo "error: authentication required" >&2; exit 1; }
    printf 'Fetching available models...\n'
    printf 'gemini-3.8-flash-low\tGemini 3.8 Flash (Low)\ngemini-3.8-flash-medium\tGemini 3.8 Flash (Medium)\n'
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
  FAKE_AGY_MODE="$mode" bash "$helper" run --model gemini-3.8-flash-low \
    --workspace "$tmp/ws" --prompt-file "$tmp/prompt.md" --run-dir "$(mktemp -d "$tmp/run-$mode.XXXXXX")" "$@"
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
out="$(FAKE_AGY_MODE=success bash "$helper" run --model gemini-3.8-flash-low --workspace "$tmp/ws" \
  --prompt-file "$tmp/long.md" --run-dir "$tmp/run-long")"
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

check "probe: models listed" '.ok == true and .authenticated == true and .models == ["gemini-3.8-flash-low","gemini-3.8-flash-medium"]' \
  "$(bash "$helper" probe)"
check "probe: failing models call reads as not logged in" '.ok == false and .authenticated == false and .error_class == "auth"' \
  "$(FAKE_AGY_MODE=models-fail bash "$helper" probe)"

if [ "$fails" -gt 0 ]; then printf 'FAIL: %s gemini-worker case(s)\n' "$fails"; exit 1; fi
printf 'PASS: gemini-worker suite\n'
