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
    sandbox)
      # Models `codex sandbox`: line 2 of fake-mode selects the sandbox
      # behavior — `deny` refuses the write, anything else executes the
      # probe's child command for real (which writes the marker in cwd).
      if [ "$(sed -n '2p' "$HOME/fake-mode" 2>/dev/null)" = deny ]; then
        printf '%s\n' DENIED
        return 1
      fi
      shift
      while [ $# -gt 0 ] && [ "$1" != -- ]; do shift; done
      [ "${1:-}" = -- ] || return 64
      shift
      "$@"
      return $? ;;
    exec)
      if [ "${2:-}" = --help ]; then
        printf '%s\n' '--ignore-user-config' '--ephemeral' '--disable' '--config' \
          '--sandbox' '--cd' '--json' '--output-last-message' '--model' \
          '--output-schema' '--skip-git-repo-check'
        return 0
      fi ;;
  esac

  printf 'EXEC %s\n' "$*" >> "$HOME/fake-calls"
  local output="" cd_dir="" mode
  while [ $# -gt 0 ]; do
    case "$1" in
      --output-last-message)
        [ $# -ge 2 ] || return 64
        output="$2"; shift 2 ;;
      --cd)
        [ $# -ge 2 ] || return 64
        cd_dir="$2"; shift 2 ;;
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
    success-write)
      # Like success, but also mutates the workspace (--cd) so the suite can
      # assert workspace_changed=true attribution.
      [ -n "$cd_dir" ] && printf '%s\n' delta > "$cd_dir/worker-output.txt"
      printf '%s\n' '{"answer":"ok"}' > "$output"
      printf '%s\n' '{"type":"turn.completed"}'
      return 0 ;;
    rate-limit)
      printf '%s\n' '{"type":"error","message":"429 rate limit"}'
      printf '%s\n' 'request failed' >&2
      return 1 ;;
    sandbox-degraded)
      # Exit 0 + completed turn + payload, but every write was rejected — the
      # observed native-Windows degradation the envelope must not call ok.
      printf '%s\n' '{"answer":"ok"}' > "$output"
      printf '%s\n' '{"type":"turn.completed"}'
      printf '%s\n' 'ERROR: patch rejected: writing is blocked by read-only sandbox; rejected by user approval settings' >&2
      return 0 ;;
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
assert_json "$probe_out" '.ok == true and .codex_version == "9.9.9" and .contract_ok == true and .dependencies.jq == true and .dependencies.git == true and .dependencies.workspace_hash == true and .sandbox_write == true and .write_ready == true' \
  'probe reports CLI, contract, write dependencies, and a measured sandbox write'
if [ ! -e "$fake_home/wrapper-calls" ]; then
  ok 'PATH executable bypasses the imported codex shell function'
else
  fail 'PATH executable bypasses the imported codex shell function'
fi

# A sandbox that rejects workspace writes must gate write_ready even though
# every dependency passes — the exact false-green that shipped a doomed write
# worker on native Windows.
printf '%s\n%s\n' success deny > "$fake_home/fake-mode"
run_worker "$tmp/probe-deny.json" "$tmp/probe-deny.err" probe
assert_json "$tmp/probe-deny.json" '.sandbox_write == false and .write_ready == false and .dependencies.git == true and .dependencies.workspace_hash == true' \
  'denied sandbox write gates write_ready despite healthy dependencies'
printf '%s\n' success > "$fake_home/fake-mode"

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
# The Windows sandbox pin is platform- AND mode-conditional (2026-08-11):
# write runs pin it on native Windows; read-only runs never carry it — the
# elevated sandbox's setup/UAC loop must not tax the read lane. This is a
# read-only run, so the pin must be absent on every platform.
case "$actual_call" in *'windows.sandbox'*) has_pin=yes ;; *) has_pin=no ;; esac
if [ "$has_pin" = no ]; then
  ok 'windows.sandbox pin absent on read-only runs'
else
  fail 'windows.sandbox pin absent on read-only runs'
fi

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

# workspace_changed attribution on clean-tree write runs: an untouched tree
# reports false (the empty-handed-worker signal), a mutated one reports true.
# Read-only runs stay null — asserted on the earlier schema-success envelope.
assert_json "$tmp/success.json" '.workspace_changed == null' \
  'read-only run reports workspace_changed null'
HOME="$fake_home" git -C "$repo" checkout -q -- tracked.txt
printf '%s\n' success > "$fake_home/fake-mode"
run_dir="$tmp/run-write-clean"
run_worker "$tmp/write-clean.json" "$tmp/write-clean.err" run \
  --model default --effort low --sandbox workspace-write --workspace "$repo" \
  --expected-base-sha "$sha" --prompt-file "$prompt" --run-dir "$run_dir" --timeout 30
assert_json "$tmp/write-clean.json" '.ok == true and .dirty_before == false and .workspace_changed == false' \
  'write run with an untouched tree reports workspace_changed false'
printf '%s\n' success-write > "$fake_home/fake-mode"
run_dir="$tmp/run-write-mutated"
run_worker "$tmp/write-mutated.json" "$tmp/write-mutated.err" run \
  --model default --effort low --sandbox workspace-write --workspace "$repo" \
  --expected-base-sha "$sha" --prompt-file "$prompt" --run-dir "$run_dir" --timeout 30
assert_json "$tmp/write-mutated.json" '.ok == true and .workspace_changed == true' \
  'write run that mutates the workspace reports workspace_changed true'
# Write runs keep the platform-conditional pin: present on native Windows,
# absent elsewhere.
actual_call="$(grep '^EXEC ' "$fake_home/fake-calls" | tail -n 1)"
case "$(uname -s)" in MINGW*|MSYS*|CYGWIN*) want_pin=yes ;; *) want_pin=no ;; esac
case "$actual_call" in *'windows.sandbox'*) has_pin=yes ;; *) has_pin=no ;; esac
if [ "$want_pin" = "$has_pin" ]; then
  ok "windows.sandbox pin on write runs matches the platform (expected: $want_pin)"
else
  fail "windows.sandbox pin on write runs matches the platform (expected: $want_pin)"
fi

# A degraded OS sandbox rejects every write while the CLI still exits 0 with a
# completed turn; the envelope must fail closed instead of reporting ok.
rm -f "$repo/worker-output.txt"
printf '%s\n' sandbox-degraded > "$fake_home/fake-mode"
run_dir="$tmp/run-sandbox-degraded"
run_worker "$tmp/sandbox-degraded.json" "$tmp/sandbox-degraded.err" run \
  --model default --effort low --sandbox workspace-write --workspace "$repo" \
  --expected-base-sha "$sha" --prompt-file "$prompt" --run-dir "$run_dir" --timeout 30
assert_json "$tmp/sandbox-degraded.json" '.ok == false and .error_class == "sandbox_denied" and .turn_completed == true' \
  'write run under a degraded sandbox fails closed as sandbox_denied'

printf '\n%s checks, %s failures\n' "$((checks + fails))" "$fails"
exit "$fails"
