#!/usr/bin/env bash
# Hermetic black-box tests for codex-worker.sh. The script copies itself to a
# throwaway PATH as `codex`, so no provider, login, network, or billing is used.
# Usage: bash skills/orchestrate/scripts/test-codex-worker.sh

set -euo pipefail

fake_codex() {
  case "${1:-}" in
    --version) printf '%s\n' 'codex-cli 9.9.9'; return 0 ;;
    --help) printf '%s\n' '--ask-for-approval'; return 0 ;;
    login)
      [ "${2:-}" = status ] && return 0
      return 64 ;;
    exec)
      if [ "${2:-}" = --help ]; then
        printf '%s\n' '--ignore-user-config' '--ephemeral' '--disable' '--config' \
          '--sandbox' '--cd' '--json' '--output-last-message' '--model' \
          '--output-schema' '--skip-git-repo-check'
        return 0
      fi ;;
  esac

  printf 'EXEC %s\n' "$*" >> "$HOME/fake-calls"
  local output="" mode
  while [ $# -gt 0 ]; do
    case "$1" in
      --output-last-message)
        [ $# -ge 2 ] || return 64
        output="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  [ -n "$output" ] || return 64
  mode="$(sed -n '1p' "$HOME/fake-mode")"
  case "$mode" in
    success)
      printf '%s\n' '{"answer":"ok"}' > "$output"
      printf '%s\n' '{"type":"turn.completed"}'
      return 0 ;;
    rate-limit)
      printf '%s\n' '{"type":"error","message":"429 rate limit"}'
      printf '%s\n' 'request failed' >&2
      return 1 ;;
    missing-result)
      printf '%s\n' '{"type":"turn.completed"}'
      return 0 ;;
    *) printf 'unknown fake mode: %s\n' "$mode" >&2; return 64 ;;
  esac
}

# A copy of this file named `codex` is the fake executable.
if [ "${0##*/}" = codex ]; then
  fake_codex "$@"
  exit $?
fi

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
helper="$script_dir/codex-worker.sh"
[ -x "$helper" ] || { echo "FAIL: helper missing or not executable: $helper" >&2; exit 1; }
for dep in jq git; do
  command -v "$dep" >/dev/null 2>&1 || {
    echo "FAIL: $dep is required to run this test suite" >&2
    exit 1
  }
done

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT INT TERM
fake_home="$tmp/home"
fake_bin="$tmp/bin"
mkdir -p "$fake_home" "$fake_bin"
cp "$0" "$fake_bin/codex"
chmod +x "$fake_bin/codex"
original_path="$PATH"
test_path="$fake_bin:$original_path"
printf '%s\n' success > "$fake_home/fake-mode"

# The imported function models the user's Claude/Bash shell wrapper. The
# worker must bypass it and execute the PATH binary copied above.
codex() {
  printf '%s\n' WRAPPER >> "$HOME/wrapper-calls"
  return 99
}
export -f codex

fails=0
checks=0
ok() { checks=$((checks + 1)); printf 'ok    %s\n' "$1"; }
fail() { fails=$((fails + 1)); printf 'FAIL  %s\n' "$1" >&2; }
assert_json() { # file jq-filter label
  if jq -e "$2" "$1" >/dev/null 2>&1; then ok "$3"; else fail "$3"; fi
}
assert_single_json() { # file label
  if jq -se 'length == 1' "$1" >/dev/null 2>&1; then ok "$2"; else fail "$2"; fi
}
assert_same() { # file file label
  if cmp -s "$1" "$2"; then ok "$3"; else fail "$3"; fi
}
exec_count() { grep -c '^EXEC ' "$fake_home/fake-calls" 2>/dev/null || true; }
run_worker() { # stdout-file stderr-file args...
  local stdout_file="$1" stderr_file="$2"; shift 2
  HOME="$fake_home" PATH="$test_path" TMPDIR="$tmp" \
    CODEX_WORKER_MAX_SLOTS=1 CODEX_WORKER_SLOT_WAIT=1 \
    bash "$helper" "$@" > "$stdout_file" 2> "$stderr_file"
}

probe_out="$tmp/probe.json"
run_worker "$probe_out" "$tmp/probe.err" probe
assert_json "$probe_out" '.ok == true and .codex_version == "9.9.9" and .contract_ok == true and .dependencies.jq == true and .dependencies.git == true and .dependencies.workspace_hash == true and .write_ready == true' \
  'probe reports CLI, contract, and write dependencies'
if [ ! -e "$fake_home/wrapper-calls" ]; then
  ok 'PATH executable bypasses the imported codex shell function'
else
  fail 'PATH executable bypasses the imported codex shell function'
fi

prompt="$tmp/prompt.md"
schema="$tmp/schema.json"
printf '%s\n' 'Return the result.' > "$prompt"
printf '%s\n' '{"type":"object","additionalProperties":false,"required":["answer"],"properties":{"answer":{"type":"string"}}}' > "$schema"

before="$(exec_count)"
run_worker "$tmp/missing-model.json" "$tmp/missing-model.err" run \
  --prompt-file "$prompt" --workspace "$tmp"
assert_json "$tmp/missing-model.json" '.ok == false and .error_class == "usage" and (.error | contains("--model is required"))' \
  'missing model fails before dispatch'
if [ "$(exec_count)" = "$before" ]; then ok 'usage failure never invokes Codex'; else fail 'usage failure never invokes Codex'; fi

run_dir="$tmp/run-success"
run_worker "$tmp/success.json" "$tmp/success.err" run \
  --model default --effort low --sandbox read-only --workspace "$tmp" \
  --prompt-file "$prompt" --schema-file "$schema" --run-dir "$run_dir" --timeout 30
assert_json "$tmp/success.json" '.ok == true and .model == "default" and .result.answer == "ok" and .turn_completed == true and .exit_code == 0' \
  'schema-shaped success produces a valid envelope'
assert_same "$tmp/success.json" "$run_dir/result.json" \
  'stdout and result.json are the same authoritative envelope'
assert_single_json "$run_dir/result.json" \
  'result.json is exactly one parseable object for Claude harvests'
actual_call="$(grep '^EXEC ' "$fake_home/fake-calls" | tail -n 1)"
case "$actual_call" in
  *'--ask-for-approval never exec'*'--ignore-user-config'*'--disable multi_agent'*'--sandbox read-only'*'--output-schema'*)
    ok 'Claude-facing invocation keeps required safety and schema flags' ;;
  *) fail 'Claude-facing invocation keeps required safety and schema flags' ;;
esac
case "$actual_call" in
  *'--model '*) fail 'default sentinel omits the CLI --model flag' ;;
  *) ok 'default sentinel omits the CLI --model flag' ;;
esac

printf '%s\n' rate-limit > "$fake_home/fake-mode"
run_dir="$tmp/run-rate-limit"
run_worker "$tmp/rate-limit.json" "$tmp/rate-limit.err" run \
  --model gpt-test --effort low --sandbox read-only --workspace "$tmp" \
  --prompt-file "$prompt" --schema-file "$schema" --run-dir "$run_dir" --timeout 30
assert_json "$tmp/rate-limit.json" '.ok == false and .model == "gpt-test" and .error_class == "rate_limit" and (.api_error | contains("429"))' \
  'provider failure is classified and preserves diagnostics'
assert_same "$tmp/rate-limit.json" "$run_dir/result.json" \
  'failure envelope is mirrored authoritatively'
actual_call="$(grep '^EXEC ' "$fake_home/fake-calls" | tail -n 1)"
case "$actual_call" in *'--model gpt-test'*) ok 'explicit model reaches the CLI' ;; *) fail 'explicit model reaches the CLI' ;; esac

printf '%s\n' missing-result > "$fake_home/fake-mode"
run_dir="$tmp/run-missing-result"
run_worker "$tmp/missing-result.json" "$tmp/missing-result.err" run \
  --model default --effort low --sandbox read-only --workspace "$tmp" \
  --prompt-file "$prompt" --schema-file "$schema" --run-dir "$run_dir" --timeout 30
assert_json "$tmp/missing-result.json" '.ok == false and .error_class == "schema" and .turn_completed == true and .result == null' \
  'missing final payload fails closed as schema error'

repo="$tmp/write-repo"
mkdir -p "$repo"
HOME="$fake_home" git -C "$repo" init -q
HOME="$fake_home" git -C "$repo" config core.autocrlf false
printf '%s\n' clean > "$repo/tracked.txt"
HOME="$fake_home" git -C "$repo" add tracked.txt
HOME="$fake_home" git -C "$repo" -c user.name=Test -c user.email=test@example.invalid commit -qm init
sha="$(HOME="$fake_home" git -C "$repo" rev-parse HEAD)"
printf '%s\n' dirty >> "$repo/tracked.txt"
before="$(exec_count)"
run_dir="$tmp/run-dirty"
run_worker "$tmp/dirty.json" "$tmp/dirty.err" run \
  --model default --effort low --sandbox workspace-write --workspace "$repo" \
  --expected-base-sha "$sha" --prompt-file "$prompt" --run-dir "$run_dir" --timeout 30
assert_json "$tmp/dirty.json" '.ok == false and .error_class == "dirty_worktree" and .dirty_before == null' \
  'dirty write workspace is refused before dispatch'
assert_same "$tmp/dirty.json" "$run_dir/result.json" \
  'write-gate refusal is recoverable from result.json'
if [ "$(exec_count)" = "$before" ]; then ok 'write gate never invokes Codex'; else fail 'write gate never invokes Codex'; fi

# Same threat as the codex wrapper above, aimed at the gates themselves: an
# exported `git` that reports success with no output makes any tree look clean,
# and an exported `jq` would shape the envelope. Both must be bypassed by the
# PATH binaries. The functions are exported inside a subshell so this suite's
# own jq/git assertions keep using the real ones.
hostile_run() { # stdout-file stderr-file args...
  local stdout_file="$1" stderr_file="$2"; shift 2
  (
    git() { printf '%s\n' HOSTILE-GIT >> "$HOME/hostile-calls"; return 0; }
    jq()  { printf '%s\n' HOSTILE-JQ >> "$HOME/hostile-calls"; return 0; }
    export -f git jq
    HOME="$fake_home" PATH="$test_path" TMPDIR="$tmp" \
      CODEX_WORKER_MAX_SLOTS=1 CODEX_WORKER_SLOT_WAIT=1 \
      bash "$helper" "$@"
  ) > "$stdout_file" 2> "$stderr_file"
}

before="$(exec_count)"
run_dir="$tmp/run-hostile"
hostile_run "$tmp/hostile.json" "$tmp/hostile.err" run \
  --model default --effort low --sandbox workspace-write --workspace "$repo" \
  --expected-base-sha "$sha" --prompt-file "$prompt" --run-dir "$run_dir" --timeout 30
assert_json "$tmp/hostile.json" '.ok == false and .error_class == "dirty_worktree"' \
  'imported git shell function cannot talk the write gate past a dirty tree'
if [ ! -e "$fake_home/hostile-calls" ] && [ "$(exec_count)" = "$before" ]; then
  ok 'imported git and jq shell functions are never invoked'
else
  fail 'imported git and jq shell functions are never invoked'
fi

printf '\n%s checks, %s failures\n' "$((checks + fails))" "$fails"
exit "$fails"
