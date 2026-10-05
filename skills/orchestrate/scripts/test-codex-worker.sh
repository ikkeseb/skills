#!/usr/bin/env bash
# Hermetic black-box tests for codex-worker.sh. The script copies itself to a
# throwaway PATH as `codex`, so no provider, login, network, or billing is used.
# Usage: bash skills/orchestrate/scripts/test-codex-worker.sh

set -euo pipefail

# The suite runs under the explicit native-Windows write opt-in so the write
# path stays exercised on MSYS (probe pin, write gates, degraded-sandbox
# classification). The fail-closed DEFAULT lane is asserted separately at the
# end with the variable cleared.
export CODEX_WORKER_NATIVE_WINDOWS_WRITE=elevated
# A shell that has opted into the WSL lane would route every fake run through
# the real wsl.exe; the suite sets the lane itself where it tests the bridge.
unset CODEX_WORKER_LANE

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
  cat > "$HOME/fake-stdin"
  mode="$(sed -n '1p' "$HOME/fake-mode")"
  case "$mode" in
    success)
      # One command item plus usage on the turn, the shape a real run emits,
      # so the suite can assert the spend field.
      printf '%s\n' '{"answer":"ok"}' > "$output"
      printf '%s\n' '{"type":"item.completed","item":{"id":"c1","type":"command_execution","command":"ls","exit_code":0,"status":"completed","aggregated_output":""}}'
      printf '%s\n' '{"type":"turn.completed","usage":{"input_tokens":1200,"cached_input_tokens":1000,"cache_write_input_tokens":0,"output_tokens":30,"reasoning_output_tokens":10}}'
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
    read-policy-denied)
      printf '%s\n' '{"answer":"incomplete"}' > "$output"
      printf '%s\n' '{"type":"turn.completed"}'
      printf '%s\n' 'ERROR: exec_command failed: CreateProcess rejected: blocked by policy' >&2
      return 0 ;;
    missing-result)
      printf '%s\n' '{"type":"turn.completed"}'
      return 0 ;;
    hang)
      # A worker still running when the runner is signalled.
      sleep 30
      return 0 ;;
    canary)
      # A worker that can see the workspace: reports canary.txt verbatim,
      # the shape `verify` asks for.
      printf '{"canary":"%s","confident":true}\n' "$(cat "$cd_dir/canary.txt")" > "$output"
      printf '%s\n' '{"type":"turn.completed"}'
      return 0 ;;
    canary-blind)
      # Schema-valid but guessed: the dead-read-lane shape verify must not
      # call ok (2026-08-24).
      printf '%s\n' '{"canary":"Oslo","confident":true}' > "$output"
      printf '%s\n' '{"type":"turn.completed"}'
      return 0 ;;
    scripted|scripted-fail)
      # The case scripts the event stream: fake-events is written verbatim.
      # With fake-events-late present the worker then marks that it is waiting
      # (fake-waiting) and stays alive until the suite creates fake-go
      # (bounded), so a case can act while the helper is mid-run, and writes
      # those late events last. With fake-hold present it then stays alive
      # until the suite creates fake-end (bounded), so a case can act on the
      # helper while the late events are being printed. fake-pid names the
      # worker. scripted-fail ends like a crashed worker: no final message, a
      # non-zero exit.
      printf '%s\n' "$$" > "$HOME/fake-pid"
      cat "$HOME/fake-events"
      if [ -f "$HOME/fake-events-late" ]; then
        : > "$HOME/fake-waiting"
        for _ in $(seq 1 900); do [ -e "$HOME/fake-go" ] && break; sleep 0.2; done
        : > "$HOME/fake-released"
        cat "$HOME/fake-events-late"
        if [ -e "$HOME/fake-hold" ]; then
          for _ in $(seq 1 900); do [ -e "$HOME/fake-end" ] && break; sleep 0.2; done
        fi
      fi
      if [ "$mode" = scripted-fail ]; then
        printf '%s\n' 'worker crashed' >&2
        return 1
      fi
      printf '%s\n' '{"answer":"ok"}' > "$output"
      return 0 ;;
    *) printf 'unknown fake mode: %s\n' "$mode" >&2; return 64 ;;
  esac
}

fake_wsl() {
  # Models wsl.exe as seen from the Windows side: records the invocation,
  # then runs the helper natively with every /mnt/<drive>/ path mapped back
  # to a Windows path and WITHOUT CODEX_WORKER_LANE — the real wsl.exe
  # forwards no Windows environment, so the VM side must never re-enter the
  # bridge. `broken` mode answers like a missing distribution.
  printf 'WSL %s\n' "$*" >> "$HOME/wsl-calls"
  printf 'MSYS_NO_PATHCONV=%s\n' "${MSYS_NO_PATHCONV:-unset}" >> "$HOME/wsl-env"
  if [ "$(cat "$HOME/wsl-mode" 2>/dev/null)" = broken ]; then
    printf '%s\n' 'There is no distribution with the supplied name.' >&2
    return 1
  fi
  while [ $# -gt 0 ] && [ "$1" != -lc ]; do shift; done
  [ "${1:-}" = -lc ] || return 64
  shift 2
  local -a mapped=()
  local a
  for a in "$@"; do
    case "$a" in
      /mnt/[a-z]/*) a="$(printf '%s' "$a" | sed -E 's#^/mnt/([a-z])/#\U\1:/#')" ;;
    esac
    mapped+=("$a")
  done
  unset CODEX_WORKER_LANE
  exec bash "${mapped[@]}"
}

# A copy of this file named `codex` (or `wsl.exe`) is the fake executable.
if [ "${0##*/}" = codex ]; then
  fake_codex "$@"
  exit $?
fi
if [ "${0##*/}" = wsl.exe ]; then
  fake_wsl "$@"
  exit $?
fi

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
helper="$script_dir/codex-worker.sh"
[ -x "$helper" ] || { echo "FAIL: helper missing or not executable: $helper" >&2; exit 1; }
for dep in jq git perl; do
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
cp "$0" "$fake_bin/wsl.exe"
chmod +x "$fake_bin/codex" "$fake_bin/wsl.exe"
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
assert_lines() { # file label line...; exactly these lines, in this order, nothing else
  local file="$1" label="$2"; shift 2
  if printf '%s\n' "$@" | cmp -s - "$file"; then ok "$label"; else fail "$label"; fi
}
assert_no_control_bytes() { # file label; judged on the real bytes
  # No C0 control but the newline that ends each line, and no DEL: nothing is
  # left once newline, printable ASCII and bytes above 0x7F are deleted. No C1
  # control either: in UTF-8 that is 0xC2 followed by 0x80-0x9F, read off a hex
  # dump so other multi-byte text (0xC2 0xA0 and up) is free to pass.
  local c0 c1=no
  c0="$(LC_ALL=C tr -d '\012\040-\176\200-\377' < "$1" | wc -c | tr -d ' ')"
  if od -An -v -tx1 "$1" | tr -s ' \n' ' ' | grep -Eq ' c2 [89][0-9a-f]'; then c1=yes; fi
  if [ "$c0" = 0 ] && [ "$c1" = no ]; then ok "$2"; else fail "$2"; fi
}
assert_line_count() { # file count label
  if [ "$(wc -l < "$1" | tr -d ' ')" = "$2" ]; then ok "$3"; else fail "$3"; fi
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
case "$(uname -s)" in MINGW*|MSYS*|CYGWIN*) expected_read_mode=allowlisted-single-command ;; *) expected_read_mode=full-shell ;; esac
assert_json "$probe_out" ".ok == true and .codex_version == \"9.9.9\" and .contract_ok == true and .dependencies.jq == true and .dependencies.git == true and .dependencies.workspace_hash == true and .read_mode == \"$expected_read_mode\" and .sandbox_write == true and .write_ready == true" \
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

before="$(exec_count)"
run_dir="$tmp/run-success"
run_worker "$tmp/success.json" "$tmp/success.err" run \
  --model default --effort low --sandbox read-only --workspace "$tmp" \
  --prompt-file "$prompt" --schema-file "$schema" --run-dir "$run_dir" --timeout 30
assert_json "$tmp/success.json" ".ok == true and .model == \"default\" and .read_mode == \"$expected_read_mode\" and .lane == \"native\" and .result.answer == \"ok\" and .turn_completed == true and .exit_code == 0" \
  'schema-shaped success produces a valid envelope'
if [ "$(exec_count)" -eq "$((before + 1))" ]; then
  ok 'native read guard adds no worker call'
else
  fail 'native read guard adds no worker call'
fi
assert_json "$tmp/success.json" '.spend.commands == 1 and .spend.input_tokens == 1200 and .spend.cached_input_tokens == 1000 and .spend.output_tokens == 30 and .spend.reasoning_output_tokens == 10 and (.spend.seconds | type) == "number"' \
  'envelope reports spend: command items, token usage, wall seconds'
assert_same "$tmp/success.json" "$run_dir/result.json" \
  'stdout and result.json are the same authoritative envelope'
assert_single_json "$run_dir/result.json" \
  'result.json is exactly one parseable object for Claude harvests'
if [ "$expected_read_mode" = allowlisted-single-command ]; then
  if grep -Fq 'Return the result.' "$fake_home/fake-stdin" \
     && grep -Fq 'Native Windows read contract:' "$fake_home/fake-stdin"; then
    ok 'native Windows read prompt keeps the task and appends the lane contract'
  else
    fail 'native Windows read prompt keeps the task and appends the lane contract'
  fi
elif cmp -s "$prompt" "$fake_home/fake-stdin"; then
  ok 'full-shell read prompt is unchanged'
else
  fail 'full-shell read prompt is unchanged'
fi
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
# The Windows sandbox pin is platform- AND mode-conditional (and since
# 2026-08-17 gated on the suite's write opt-in): opted-in write runs pin it
# on native Windows; read-only runs never carry it — the elevated sandbox's
# setup/UAC loop must not tax the read lane. This is a read-only run, so the
# pin must be absent on every platform.
case "$actual_call" in *'windows.sandbox'*) has_pin=yes ;; *) has_pin=no ;; esac
if [ "$has_pin" = no ]; then
  ok 'windows.sandbox pin absent on read-only runs'
else
  fail 'windows.sandbox pin absent on read-only runs'
fi

printf '%s\n' read-policy-denied > "$fake_home/fake-mode"
run_dir="$tmp/run-read-policy-denied"
run_worker "$tmp/read-policy-denied.json" "$tmp/read-policy-denied.err" run \
  --model default --effort low --sandbox read-only --workspace "$tmp" \
  --prompt-file "$prompt" --schema-file "$schema" --run-dir "$run_dir" --timeout 30
if [ "$expected_read_mode" = allowlisted-single-command ]; then
  assert_json "$tmp/read-policy-denied.json" '.ok == false and .error_class == "read_policy_denied" and .read_mode == "allowlisted-single-command"' \
    'native Windows policy rejection fails closed with a routing verdict'
else
  assert_json "$tmp/read-policy-denied.json" '.ok == true and .read_mode == "full-shell"' \
    'non-Windows runs ignore the native exec-policy signature'
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
assert_json "$tmp/missing-result.json" '.spend.commands == 0 and .spend.input_tokens == null' \
  'spend degrades to zero commands and null tokens when the turn carries no usage'
assert_json "$tmp/missing-result.json" '.ok == false and .error_class == "schema" and .turn_completed == true and .result == null' \
  'missing final payload fails closed as schema error'

# A signalled runner kills the worker and still leaves a terminal verdict in
# the run dir, so a background dispatch whose stdout is lost can be harvested.
printf '%s\n' hang > "$fake_home/fake-mode"
run_dir="$tmp/run-interrupted"
HOME="$fake_home" PATH="$test_path" TMPDIR="$tmp" \
  CODEX_WORKER_MAX_SLOTS=1 CODEX_WORKER_SLOT_WAIT=1 \
  bash "$helper" run --model gpt-test --effort low --sandbox read-only \
  --workspace "$tmp" --prompt-file "$prompt" --run-dir "$run_dir" --timeout 60 \
  > "$tmp/interrupted.json" 2> "$tmp/interrupted.err" &
runner_pid=$!
for _ in $(seq 1 50); do [ -f "$run_dir/events.jsonl" ] && break; sleep 0.2; done
sleep 1
kill -TERM "$runner_pid" 2>/dev/null || true
wait "$runner_pid" 2>/dev/null || true
assert_json "$tmp/interrupted.json" '.ok == false and .error_class == "interrupted" and (.run_dir | endswith("run-interrupted"))' \
  'a signalled runner reports interrupted with its run dir'
assert_same "$tmp/interrupted.json" "$run_dir/result.json" \
  'the interrupted verdict is mirrored into the run dir'

# verify is a read canary: only a worker that reports the token written to
# the workspace passes; a schema-valid guess or the wrong shape does not.
printf '%s\n' canary > "$fake_home/fake-mode"
run_worker "$tmp/verify-canary.json" "$tmp/verify-canary.err" verify
assert_json "$tmp/verify-canary.json" '.ok == true and .envelope_ok == true and .schema_honoured == true and .workspace_read == true' \
  'verify passes when the worker reports the workspace canary'
printf '%s\n' canary-blind > "$fake_home/fake-mode"
run_worker "$tmp/verify-blind.json" "$tmp/verify-blind.err" verify
assert_json "$tmp/verify-blind.json" '.ok == false and .envelope_ok == true and .schema_honoured == true and .workspace_read == false' \
  'verify fails a schema-valid guess that never read the workspace'
printf '%s\n' success > "$fake_home/fake-mode"
run_worker "$tmp/verify-shape.json" "$tmp/verify-shape.err" verify
assert_json "$tmp/verify-shape.json" '.ok == false and .schema_honoured == false and .workspace_read == false' \
  'verify fails a result in the wrong shape'

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
# Opted-in write runs keep the platform-conditional pin: present on native
# Windows (under the suite's CODEX_WORKER_NATIVE_WINDOWS_WRITE=elevated),
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

# DEFAULT native Windows behavior (opt-in cleared): workspace-write is an
# unsupported lane that fails closed before invoking Codex, and probe gates
# write_ready without engaging any sandbox implementation (2026-08-17: the
# elevated sandbox loops UAC across CODEX_HOMEs; unelevated breaks MSYS
# children). Only meaningful on native Windows — other platforms keep their
# write lanes and are covered above.
case "$(uname -s)" in
  MINGW*|MSYS*|CYGWIN*)
    printf '%s\n' success > "$fake_home/fake-mode"
    before="$(exec_count)"
    run_dir="$tmp/run-win-write-default"
    CODEX_WORKER_NATIVE_WINDOWS_WRITE= run_worker \
      "$tmp/win-default.json" "$tmp/win-default.err" run \
      --model default --effort low --sandbox workspace-write --workspace "$repo" \
      --expected-base-sha "$sha" --prompt-file "$prompt" --run-dir "$run_dir" --timeout 30
    assert_json "$tmp/win-default.json" '.ok == false and .error_class == "unsupported_lane"' \
      'default native Windows write run fails closed as unsupported_lane'
    if [ "$(exec_count)" = "$before" ]; then
      ok 'unsupported write lane never invokes Codex'
    else
      fail 'unsupported write lane never invokes Codex'
    fi
    CODEX_WORKER_NATIVE_WINDOWS_WRITE= run_worker \
      "$tmp/win-default-probe.json" "$tmp/win-default-probe.err" probe
    assert_json "$tmp/win-default-probe.json" '.sandbox_write == false and .write_ready == false' \
      'default native Windows probe gates write_ready without engaging any sandbox'
    ;;
esac

# WSL lane. CODEX_WORKER_LANE=wsl is a native-Windows switch: there the helper
# re-executes itself inside the VM through wsl.exe (the fake above stands in
# for it); everywhere else the variable is ignored and the platform's own
# lane runs.
printf '%s\n' success > "$fake_home/fake-mode"
rm -f "$fake_home/wsl-calls" "$fake_home/wsl-env" "$fake_home/wsl-mode"
case "$(uname -s)" in
  MINGW*|MSYS*|CYGWIN*)
    run_dir="$tmp/run-wsl-bridge"
    CODEX_WORKER_LANE=wsl run_worker "$tmp/wsl-bridge.json" "$tmp/wsl-bridge.err" run \
      --model default --effort low --sandbox read-only --workspace "$tmp" \
      --prompt-file "$prompt" --schema-file "$schema" --run-dir "$run_dir" --timeout 30
    run_dir_mixed="$(cygpath -m -a "$run_dir")"
    assert_json "$tmp/wsl-bridge.json" ".ok == true and .lane == \"wsl-bridge\" and .result.answer == \"ok\" and .run_dir == \"$run_dir_mixed\" and (.run_dir_wsl | startswith(\"/mnt/\"))" \
      'WSL lane relays the VM envelope with the lane and a Windows-side run dir'
    assert_same "$tmp/wsl-bridge.json" "$run_dir/result.json" \
      'WSL lane mirrors the rewritten envelope into result.json'
    wsl_call="$(tail -n 1 "$fake_home/wsl-calls" 2>/dev/null || true)"
    case "$wsl_call" in
      *'-e bash -lc '*'/mnt/'*'/codex-worker.sh run '*'--workspace /mnt/'*'--prompt-file /mnt/'*'--run-dir /mnt/'*)
        ok 'WSL lane runs the helper in a login shell with drvfs paths' ;;
      *) fail "WSL lane runs the helper in a login shell with drvfs paths ($wsl_call)" ;;
    esac
    case "$wsl_call" in
      *[A-Za-z]:/*) fail 'WSL lane passes no Windows-form path into the VM' ;;
      *) ok 'WSL lane passes no Windows-form path into the VM' ;;
    esac
    case "$wsl_call" in
      *' --no-progress'*) ok 'WSL lane turns the VM-side progress lines off' ;;
      *) fail 'WSL lane turns the VM-side progress lines off' ;;
    esac
    if grep -qx 'MSYS_NO_PATHCONV=1' "$fake_home/wsl-env" 2>/dev/null; then
      ok 'WSL lane suppresses MSYS path conversion for the wsl.exe call'
    else
      fail 'WSL lane suppresses MSYS path conversion for the wsl.exe call'
    fi

    CODEX_WORKER_LANE=wsl run_worker "$tmp/wsl-minted.json" "$tmp/wsl-minted.err" run \
      --model default --effort low --sandbox read-only --workspace "$tmp" \
      --prompt-file "$prompt" --schema-file "$schema" --timeout 30
    minted="$(jq -r '.run_dir // ""' "$tmp/wsl-minted.json")"
    if [ -n "$minted" ] && jq -e '.lane == "wsl-bridge"' "$minted/result.json" >/dev/null 2>&1; then
      ok 'WSL lane mints a Windows-side run dir when the caller gave none'
    else
      fail 'WSL lane mints a Windows-side run dir when the caller gave none'
    fi

    CODEX_WORKER_LANE=wsl run_worker "$tmp/wsl-probe.json" "$tmp/wsl-probe.err" probe
    assert_json "$tmp/wsl-probe.json" '.ok == true and .lane == "wsl-bridge"' \
      'WSL lane probe reports the bridged lane'

    printf '%s\n' broken > "$fake_home/wsl-mode"
    before="$(exec_count)"
    run_dir="$tmp/run-wsl-broken"
    CODEX_WORKER_LANE=wsl run_worker "$tmp/wsl-broken.json" "$tmp/wsl-broken.err" run \
      --model default --effort low --sandbox read-only --workspace "$tmp" \
      --prompt-file "$prompt" --schema-file "$schema" --run-dir "$run_dir" --timeout 30
    assert_json "$tmp/wsl-broken.json" '.ok == false and .error_class == "wsl_bridge_failed" and (.error | contains("distribution"))' \
      'WSL lane fails closed with the VM diagnostic when wsl.exe does not answer'
    assert_same "$tmp/wsl-broken.json" "$run_dir/result.json" \
      'WSL bridge failure is recoverable from result.json'
    if [ "$(exec_count)" = "$before" ]; then
      ok 'WSL bridge failure never invokes Codex'
    else
      fail 'WSL bridge failure never invokes Codex'
    fi
    ;;
  *)
    run_dir="$tmp/run-wsl-ignored"
    CODEX_WORKER_LANE=wsl run_worker "$tmp/wsl-ignored.json" "$tmp/wsl-ignored.err" run \
      --model default --effort low --sandbox read-only --workspace "$tmp" \
      --prompt-file "$prompt" --schema-file "$schema" --run-dir "$run_dir" --timeout 30
    assert_json "$tmp/wsl-ignored.json" '.ok == true and .lane == "native"' \
      'CODEX_WORKER_LANE=wsl is ignored off native Windows'
    if [ ! -e "$fake_home/wsl-calls" ]; then
      ok 'non-Windows platforms never call wsl.exe'
    else
      fail 'non-Windows platforms never call wsl.exe'
    fi
    ;;
esac

# Progress lines. The helper's stderr is the user's live view of a running
# worker, and it may never cost the run anything. Each case scripts the event
# stream (fake mode `scripted`) and compares the WHOLE stderr, so a missing,
# extra, reordered, duplicated or unsafe line fails, and checks that the
# envelope is what it would be without the view.
events="$fake_home/fake-events"
banner() { # run-dir
  printf '[codex-worker] start model=default effort=low sandbox=read-only run-dir=%s' "$1"
}
secs() { jq -r '.spend.seconds' "$1" 2>/dev/null | tr -d '\r'; } # envelope file
progress_run() { # name [extra helper args]; sets run_dir, output in $tmp/<name>.json|.err
  local name="$1"; shift
  run_dir="$tmp/run-$name"
  run_worker "$tmp/$name.json" "$tmp/$name.err" run \
    --model default --effort low --sandbox read-only --workspace "$tmp" \
    --prompt-file "$prompt" --schema-file "$schema" --run-dir "$run_dir" \
    --timeout 30 "$@"
}

printf '%s\n' scripted > "$fake_home/fake-mode"
cat > "$events" <<'EOF'
{"type":"thread.started","thread_id":"t-1"}
{"type":"turn.started"}
{"type":"item.started","item":{"id":"item_1","type":"command_execution","command":"git status --short","aggregated_output":"","exit_code":null,"status":"in_progress"}}
{"type":"item.completed","item":{"id":"item_1","type":"command_execution","command":"git status --short","aggregated_output":"fatal: not a git repository\n","exit_code":4,"status":"failed"}}
{"type":"item.started","item":{"id":"item_2","type":"command_execution","command":"rg -n TODO src","aggregated_output":"","exit_code":null,"status":"in_progress"}}
{"type":"item.completed","item":{"id":"item_2","type":"command_execution","command":"rg -n TODO src","aggregated_output":"src/a.txt:1:TODO\n","exit_code":0,"status":"completed"}}
{"type":"item.completed","item":{"id":"item_0","type":"agent_message","text":"Two commands ran."}}
{"type":"turn.completed","usage":{"input_tokens":10,"cached_input_tokens":0,"output_tokens":5,"reasoning_output_tokens":0}}
EOF
progress_run progress
assert_lines "$tmp/progress.err" \
  'progress: command starts, the failed exit, the agent message and the closing line follow the banner, in order, with no line for exit 0' \
  "$(banner "$run_dir")" \
  '[codex-worker] $ git status --short' \
  '[codex-worker]   exit 4' \
  '[codex-worker] $ rg -n TODO src' \
  '[codex-worker] > Two commands ran.' \
  "[codex-worker] end ok=true cmds=2 $(secs "$tmp/progress.json")s"
assert_single_json "$tmp/progress.json" \
  'progress: stdout stays exactly one JSON document'
assert_same "$tmp/progress.json" "$run_dir/result.json" \
  'progress: stdout still equals result.json'
assert_json "$tmp/progress.json" '.ok == true and .result.answer == "ok" and .spend.commands == 2' \
  'progress: the envelope reports the run the closing line names'

# --no-progress turns the view off and nothing else: the banner stays, and
# apart from the run dir and the wall seconds the envelope is the one above.
progress_run no-progress --no-progress
assert_lines "$tmp/no-progress.err" \
  '--no-progress leaves the start banner and prints no progress line' \
  "$(banner "$run_dir")"
jq -S 'del(.run_dir, .spend.seconds)' "$tmp/progress.json" > "$tmp/progress.norm" 2>/dev/null || true
jq -S 'del(.run_dir, .spend.seconds)' "$tmp/no-progress.json" > "$tmp/no-progress.norm" 2>/dev/null || true
if [ -s "$tmp/progress.norm" ] && cmp -s "$tmp/progress.norm" "$tmp/no-progress.norm"; then
  ok '--no-progress leaves the envelope unchanged: ok, result, spend and every other field'
else
  fail '--no-progress leaves the envelope unchanged: ok, result, spend and every other field'
fi

# Worker-controlled text must not reach a terminal raw: every control
# character (ESC, newline, tab, DEL, the 8-bit CSI, NUL) prints as a space on
# one line, a command is cut at 160 characters and a message at 200, and text
# exactly at the bound prints whole.
a160="$(printf '%0160d' 0 | tr 0 a)"
m200="$(printf '%0200d' 0 | tr 0 m)"
# Valid multi-byte text must survive, U+00A0 included: it sits one above the
# C1 block and shares its lead byte. An exit code is a number literal of any
# length, so it is cut too (at 20, rendered here by the suite's own jq).
nbsp=$'\xc2\xa0'
big_exit="$(printf '%03000d' 0 | tr 0 7)"
exit20="$(jq -rn "$big_exit | tostring | .[0:20]" | tr -d '\r')"
{
  printf '{"type":"item.started","item":{"id":"item_1","type":"command_execution","command":"%s%s"}}\n' \
    "$a160" "$(printf '%04840d' 0 | tr 0 b)"
  printf '{"type":"item.started","item":{"id":"item_2","type":"command_execution","command":"%s"}}\n' "$a160"
  printf '{"type":"item.completed","item":{"id":"item_2","type":"command_execution","command":"x","exit_code":%s,"status":"failed"}}\n' "$big_exit"
  printf '%s\n' '{"type":"item.completed","item":{"id":"item_3","type":"agent_message","text":"red \u001b[31malert\u001b[0m\nsecond line\tend\u007f\u009b2J\u0000."}}'
  printf '{"type":"item.completed","item":{"id":"item_4","type":"agent_message","text":"café%sau lait ✓"}}\n' "$nbsp"
  printf '{"type":"item.completed","item":{"id":"item_5","type":"agent_message","text":"%s%s"}}\n' \
    "$m200" "$(printf '%0100d' 0 | tr 0 n)"
  printf '%s\n' '{"type":"turn.completed"}'
} > "$events"
progress_run progress-safety
assert_lines "$tmp/progress-safety.err" \
  'progress: control characters print as spaces on one line, other text survives, and a long command, exit code and message are cut at their bounds' \
  "$(banner "$run_dir")" \
  "[codex-worker] \$ ${a160}…" \
  "[codex-worker] \$ ${a160}" \
  "[codex-worker]   exit ${exit20}…" \
  '[codex-worker] > red  [31malert [0m second line end  2J .' \
  "[codex-worker] > café${nbsp}au lait ✓" \
  "[codex-worker] > ${m200}…" \
  "[codex-worker] end ok=true cmds=1 $(secs "$tmp/progress-safety.json")s"
assert_line_count "$tmp/progress-safety.err" 8 \
  'progress: one line per printing event between the banner and the closing line'
assert_no_control_bytes "$tmp/progress-safety.err" \
  'progress: no C0, DEL or C1 control byte from worker text reaches stderr'

# A line that is not JSON (here carrying a raw ESC), an unknown item type and
# fields of the wrong type print nothing and stop nothing: the lines around
# them still print and the envelope is unaffected.
{
  printf '%s\n' '{"type":"item.started","item":{"id":"item_1","type":"command_execution","command":"echo before"}}'
  printf 'this line is not JSON \033[2J at all\n'
  printf '%s\n' '{"type":"item.completed","item":{"id":"item_7","type":"mystery_item","payload":{"deep":[1,2,3]}}}'
  printf '%s\n' '{"type":"item.started","item":"not an object"}'
  printf '%s\n' '{"type":"item.started","item":{"id":"item_8","type":"command_execution","command":["not","a","string"]}}'
  printf '%s\n' '{"type":"item.completed","item":{"id":"item_8","type":"command_execution","exit_code":"7"}}'
  printf '%s\n' '{"type":"item.completed","item":{"id":"item_9","type":"agent_message","text":{"not":"a string"}}}'
  printf '%s\n' '{"type":"brand.new.event","anything":true}'
  printf '%s\n' '{truncated' ''
  printf '%s\n' '{"type":"item.completed","item":{"id":"item_1","type":"command_execution","command":"echo before","aggregated_output":"before\n","exit_code":0,"status":"completed"}}'
  printf '%s\n' '{"type":"item.started","item":{"id":"item_2","type":"command_execution","command":"echo after"}}'
  printf '%s\n' '{"type":"item.completed","item":{"id":"item_2","type":"command_execution","command":"echo after","aggregated_output":"","exit_code":3,"status":"failed"}}'
  printf '%s\n' '{"type":"item.completed","item":{"id":"item_0","type":"agent_message","text":"survived"}}'
  printf '%s\n' '{"type":"turn.completed"}'
} > "$events"
progress_run progress-robust
assert_lines "$tmp/progress-robust.err" \
  'progress: a non-JSON line, an unknown item type and wrong-typed fields print nothing and the lines around them still print' \
  "$(banner "$run_dir")" \
  '[codex-worker] $ echo before' \
  '[codex-worker] $ echo after' \
  '[codex-worker]   exit 3' \
  '[codex-worker] > survived' \
  "[codex-worker] end ok=true cmds=3 $(secs "$tmp/progress-robust.json")s"
assert_no_control_bytes "$tmp/progress-robust.err" \
  'progress: a raw control byte in a non-JSON line never reaches stderr'
assert_json "$tmp/progress-robust.json" '.ok == true and .turn_completed == true and .result.answer == "ok" and .spend.commands == 3' \
  'progress: the envelope is unaffected by lines the printer skips'
assert_same "$tmp/progress-robust.json" "$run_dir/result.json" \
  'progress: stdout still equals result.json after skipped lines'

# The shell wrapper is stripped only when the unwrapping is unambiguous:
# `/bin/bash -lc '<inner>'` or `bash -lc '<inner>'` with no quote inside.
# Every other shape prints exactly as the worker sent it.
cat > "$events" <<'EOF'
{"type":"item.started","item":{"id":"item_1","type":"command_execution","command":"/bin/bash -lc 'git status --short'"}}
{"type":"item.started","item":{"id":"item_2","type":"command_execution","command":"bash -lc 'ls -la'"}}
{"type":"item.started","item":{"id":"item_3","type":"command_execution","command":"/bin/bash -lc \"echo 'hi'\""}}
{"type":"item.started","item":{"id":"item_4","type":"command_execution","command":"/bin/bash -lc 'echo '\\''hi'\\'''"}}
{"type":"item.started","item":{"id":"item_5","type":"command_execution","command":"/bin/zsh -lc 'pwd'"}}
{"type":"item.started","item":{"id":"item_6","type":"command_execution","command":"/bin/bash -lc ls"}}
{"type":"item.started","item":{"id":"item_7","type":"command_execution","command":"git log -1 --format='%H'"}}
{"type":"turn.completed"}
EOF
progress_run progress-wrapper
assert_lines "$tmp/progress-wrapper.err" \
  'progress: a bash -lc wrapper prints as its inner command; any other shape prints unchanged' \
  "$(banner "$run_dir")" \
  '[codex-worker] $ git status --short' \
  '[codex-worker] $ ls -la' \
  "[codex-worker] \$ /bin/bash -lc \"echo 'hi'\"" \
  "[codex-worker] \$ /bin/bash -lc 'echo '\\''hi'\\'''" \
  "[codex-worker] \$ /bin/zsh -lc 'pwd'" \
  '[codex-worker] $ /bin/bash -lc ls' \
  "[codex-worker] \$ git log -1 --format='%H'" \
  "[codex-worker] end ok=true cmds=0 $(secs "$tmp/progress-wrapper.json")s"

# A failing run still shows what the worker did and closes with ok=false; its
# failure envelope is the one such a run always produced.
printf '%s\n' scripted-fail > "$fake_home/fake-mode"
cat > "$events" <<'EOF'
{"type":"turn.started"}
{"type":"item.started","item":{"id":"item_1","type":"command_execution","command":"make test"}}
{"type":"item.completed","item":{"id":"item_1","type":"command_execution","command":"make test","aggregated_output":"1 failed\n","exit_code":2,"status":"failed"}}
{"type":"item.completed","item":{"id":"item_0","type":"agent_message","text":"Stopping here."}}
EOF
progress_run progress-fail
assert_lines "$tmp/progress-fail.err" \
  'progress: a failing run prints the events it had and closes with ok=false' \
  "$(banner "$run_dir")" \
  '[codex-worker] $ make test' \
  '[codex-worker]   exit 2' \
  '[codex-worker] > Stopping here.' \
  "[codex-worker] end ok=false cmds=1 $(secs "$tmp/progress-fail.json")s"
assert_json "$tmp/progress-fail.json" '.ok == false and .error_class == "codex_failed" and .error == "exit=1 turn_completed=false result_valid=false" and .exit_code == 1 and .turn_completed == false and .result == null and .spend.commands == 1 and (.stderr_tail | contains("worker crashed"))' \
  'progress: the failure envelope keeps its class, error, exit code and diagnostics'
assert_same "$tmp/progress-fail.json" "$run_dir/result.json" \
  'progress: the failure envelope on stdout still equals result.json'

# The view is live. The fake writes one complete line and the first half of a
# second, then blocks until released: the complete line must be on stderr
# while the worker provably still runs, the half-written one must wait, and
# once the worker finishes every line must have printed exactly once.
printf '%s\n' scripted > "$fake_home/fake-mode"
{
  printf '%s\n' '{"type":"item.started","item":{"id":"item_1","type":"command_execution","command":"echo early"}}'
  printf '%s' '{"type":"item.started","item":{"id":"item_2","type":"command_exe'
} > "$events"
printf '%s\n' 'cution","command":"echo late"}}' '{"type":"turn.completed"}' \
  > "$fake_home/fake-events-late"
rm -f "$fake_home/fake-go" "$fake_home/fake-released" "$fake_home/fake-waiting"
run_dir="$tmp/run-progress-live"
run_worker "$tmp/progress-live.json" "$tmp/progress-live.err" run \
  --model default --effort low --sandbox read-only --workspace "$tmp" \
  --prompt-file "$prompt" --schema-file "$schema" --run-dir "$run_dir" \
  --timeout 300 &
runner_pid=$!
# Synchronised on the worker, not on the clock: wait until it stands at its
# gate, then give the first line 40 s (a tick is at most 5 s) before releasing it.
for _ in $(seq 1 300); do [ -e "$fake_home/fake-waiting" ] && break; sleep 0.2; done
seen_live=no
for _ in $(seq 1 200); do
  if grep -Fxq '[codex-worker] $ echo early' "$tmp/progress-live.err" 2>/dev/null; then
    if [ ! -e "$fake_home/fake-released" ] && [ ! -e "$run_dir/result.json" ] \
       && [ ! -s "$tmp/progress-live.json" ]; then
      seen_live=yes
    fi
    break
  fi
  sleep 0.2
done
: > "$fake_home/fake-go"
wait "$runner_pid" 2>/dev/null || true
rm -f "$fake_home/fake-events-late" "$fake_home/fake-go" "$fake_home/fake-released" "$fake_home/fake-waiting"
if [ "$seen_live" = yes ]; then
  ok 'progress: a line is on stderr while the worker is still running'
else
  fail 'progress: a line is on stderr while the worker is still running'
fi
assert_lines "$tmp/progress-live.err" \
  'progress: a half-written line waits for its newline, and every line prints exactly once across ticks and the final flush' \
  "$(banner "$run_dir")" \
  '[codex-worker] $ echo early' \
  '[codex-worker] $ echo late' \
  "[codex-worker] end ok=true cmds=0 $(secs "$tmp/progress-live.json")s"
assert_same "$tmp/progress-live.json" "$run_dir/result.json" \
  'progress: the live run still delivers one envelope equal to result.json'

# The view may never cost the run, whatever the stderr reader does. piped_run
# starts the helper in the background with its stderr piped into a reader
# command: stdout lands in $tmp/<name>.json, the reader's output in
# $tmp/<name>.err, the helper's exit code in $tmp/<name>.rc once it is done,
# and reader_pid is the reader.
piped_run() { # name reader-command...; sets run_dir and reader_pid
  local name="$1"; shift
  run_dir="$tmp/run-$name"
  rm -f "$tmp/$name.rc"
  {
    piped_rc=0
    HOME="$fake_home" PATH="$test_path" TMPDIR="$tmp" \
      CODEX_WORKER_MAX_SLOTS=1 CODEX_WORKER_SLOT_WAIT=1 \
      bash "$helper" run \
      --model default --effort low --sandbox read-only --workspace "$tmp" \
      --prompt-file "$prompt" --schema-file "$schema" --run-dir "$run_dir" \
      --timeout 300 2>&1 > "$tmp/$name.json" || piped_rc=$?
    printf '%s\n' "$piped_rc" > "$tmp/$name.rc"
  } | "$@" > "$tmp/$name.err" &
  reader_pid=$!
}

# A reader that goes away. It takes the banner and exits, and the worker holds
# its events until the suite has seen the reader gone, so every progress write
# meets a closed pipe. The runner must survive that, exit 0 and deliver its
# normal envelope.
: > "$events"
printf '%s\n' \
  '{"type":"item.started","item":{"id":"item_1","type":"command_execution","command":"echo unheard"}}' \
  '{"type":"turn.completed"}' > "$fake_home/fake-events-late"
rm -f "$fake_home/fake-go" "$fake_home/fake-released" "$fake_home/fake-waiting"
piped_run progress-deaf head -n 1
reader_gone=no
for _ in $(seq 1 300); do
  if ! kill -0 "$reader_pid" 2>/dev/null; then reader_gone=yes; break; fi
  sleep 0.2
done
[ ! -e "$fake_home/fake-released" ] || reader_gone=late
: > "$fake_home/fake-go"
for _ in $(seq 1 300); do [ -e "$tmp/progress-deaf.rc" ] && break; sleep 0.2; done
wait 2>/dev/null || true
rm -f "$fake_home/fake-events-late" "$fake_home/fake-go" "$fake_home/fake-released" "$fake_home/fake-waiting"
if [ "$reader_gone" = yes ]; then
  ok 'progress: the reader was gone before the worker emitted its events'
else
  fail 'progress: the reader was gone before the worker emitted its events'
fi
assert_lines "$tmp/progress-deaf.err" \
  'progress: the reader that goes away took the banner first' \
  "$(banner "$run_dir")"
if [ "$(cat "$tmp/progress-deaf.rc" 2>/dev/null)" = 0 ]; then
  ok 'progress: a stderr reader that goes away does not change the exit code'
else
  fail 'progress: a stderr reader that goes away does not change the exit code'
fi
assert_json "$tmp/progress-deaf.json" '.ok == true and .result.answer == "ok" and .turn_completed == true and .spend.commands == 0' \
  'progress: a stderr reader that goes away does not cost the envelope'
assert_same "$tmp/progress-deaf.json" "$run_dir/result.json" \
  'progress: the envelope still equals result.json after the reader went away'

# A reader that keeps the pipe open and stops reading. The helper's stderr is
# a named FIFO, and each case shows the backpressure before it measures
# anything: the reader takes the banner and stops, a filler writes into the
# same FIFO until a write does not return, and only then does the worker
# release its events. Every progress write after that meets a full pipe.
stall_setup() { # name; sets run_dir, stall_fifo, runner_pid, stall_reader_pid, stall_ready
  stall_name="$1"
  run_dir="$tmp/run-$stall_name"
  stall_fifo="$tmp/$stall_name.fifo"
  stall_filler_pid=""
  rm -f "$fake_home/fake-go" "$fake_home/fake-released" "$fake_home/fake-waiting" \
    "$fake_home/fake-end" "$fake_home/fake-pid"
  mkfifo "$stall_fifo"
  # The reader: the banner line, then nothing until the suite asks it to
  # drain (bounded), then everything up to EOF, which it marks.
  {
    IFS= read -r stall_first || true
    printf '%s\n' "$stall_first" > "$tmp/$stall_name.err"
    : > "$tmp/$stall_name.banner-read"
    for _ in $(seq 1 900); do [ -e "$tmp/$stall_name.drain" ] && break; sleep 0.2; done
    cat > "$tmp/$stall_name.rest"
    : > "$tmp/$stall_name.eof"
  } < "$stall_fifo" &
  stall_reader_pid=$!
  HOME="$fake_home" PATH="$test_path" TMPDIR="$tmp" \
    CODEX_WORKER_MAX_SLOTS=1 CODEX_WORKER_SLOT_WAIT=1 \
    bash "$helper" run \
    --model default --effort low --sandbox read-only --workspace "$tmp" \
    --prompt-file "$prompt" --schema-file "$schema" --run-dir "$run_dir" \
    --timeout 300 > "$tmp/$stall_name.json" 2> "$stall_fifo" &
  runner_pid=$!
  # Startup allowance, apart from every later bound: the banner is read and
  # the worker stands at its gate.
  stall_ready=no
  for _ in $(seq 1 300); do
    if [ -e "$tmp/$stall_name.banner-read" ] && [ -e "$fake_home/fake-waiting" ]; then
      stall_ready=yes; break
    fi
    sleep 0.2
  done
}
stall_fill() { # sets stall_filler_pid and stall_blocked
  # 4 KiB at a time, counting each write that returned. The pipe refused a
  # write once the filler is alive, has written, and its count stands still
  # for two seconds.
  (
    chunk="$(printf '%04096d' 0)"; n=0
    while :; do
      printf '%s' "$chunk"
      n=$((n + 1)); printf '%s\n' "$n" > "$tmp/$stall_name.filled"
    done > "$stall_fifo"
  ) 2>/dev/null &
  stall_filler_pid=$!
  stall_blocked=no
  local prev="" cur="" still=0
  for _ in $(seq 1 150); do
    sleep 0.2
    cur="$(cat "$tmp/$stall_name.filled" 2>/dev/null || true)"
    if [ -n "$cur" ] && [ "$cur" = "$prev" ]; then still=$((still + 1)); else still=0; fi
    prev="$cur"
    if [ "$still" -ge 10 ] && kill -0 "$stall_filler_pid" 2>/dev/null \
       && [ ! -e "$fake_home/fake-released" ]; then
      stall_blocked=yes; break
    fi
  done
}
stall_wait_runner() { # seconds; sets stall_done, and stall_rc when the helper exited
  stall_done=no stall_rc=""
  for _ in $(seq 1 "$(($1 * 5))"); do
    if ! kill -0 "$runner_pid" 2>/dev/null; then stall_done=yes; break; fi
    sleep 0.2
  done
  if [ "$stall_done" = yes ]; then
    stall_rc=0; wait "$runner_pid" 2>/dev/null || stall_rc=$?
  fi
}
stall_cleanup() { # in every outcome: sets stall_eof; nothing of the case stays behind
  [ -z "$stall_filler_pid" ] || kill "$stall_filler_pid" 2>/dev/null || true
  [ -z "$stall_filler_pid" ] || wait "$stall_filler_pid" 2>/dev/null || true
  # With the suite's own writer gone the reader drains to EOF, unless some
  # other process still holds the write end.
  : > "$tmp/$stall_name.drain"
  stall_eof=no
  for _ in $(seq 1 50); do
    if [ -e "$tmp/$stall_name.eof" ]; then stall_eof=yes; break; fi
    sleep 0.2
  done
  : > "$fake_home/fake-go"; : > "$fake_home/fake-end"
  if [ "$stall_done" != yes ]; then
    # A helper that is still running failed its bound. Draining unblocked it;
    # give it a moment, then end it.
    for _ in $(seq 1 50); do kill -0 "$runner_pid" 2>/dev/null || break; sleep 0.2; done
    kill -KILL "$runner_pid" 2>/dev/null || true
    wait "$runner_pid" 2>/dev/null || true
  fi
  # The worker, whatever the helper did: the release markers stay until it is
  # gone, and one that outlives them is ended.
  local stall_worker
  stall_worker="$(cat "$fake_home/fake-pid" 2>/dev/null || true)"
  for _ in $(seq 1 25); do
    [ -n "$stall_worker" ] && kill -0 "$stall_worker" 2>/dev/null || break
    sleep 0.2
  done
  [ -z "$stall_worker" ] || kill -KILL "$stall_worker" 2>/dev/null || true
  # The reader and, when EOF never came, the cat it is still running.
  pkill -P "$stall_reader_pid" 2>/dev/null || true
  kill "$stall_reader_pid" 2>/dev/null || true
  wait "$stall_reader_pid" 2>/dev/null || true
  rm -f "$stall_fifo" "$fake_home/fake-events-late" "$fake_home/fake-go" \
    "$fake_home/fake-released" "$fake_home/fake-waiting" "$fake_home/fake-hold" \
    "$fake_home/fake-end"
}
check() { # condition-result label
  if [ "$1" = yes ]; then ok "$2"; else fail "$2"; fi
}

# The run must end with its normal envelope and exit code. From the release
# the helper needs a tick (at most 5 s) to see the worker gone, then at most one write
# bound each for the final flush and the closing line: 20 s is the completion
# bound, against a helper timeout of 300 s.
: > "$events"
{
  for i in $(seq 1 200); do
    printf '{"type":"item.started","item":{"id":"item_%s","type":"command_execution","command":"%s"}}\n' "$i" "$a160"
  done
  printf '%s\n' '{"type":"turn.completed"}'
} > "$fake_home/fake-events-late"
stall_setup progress-stalled
check "$stall_ready" 'stalled reader: the banner was read and the worker stood at its gate'
stall_fill
check "$stall_blocked" 'stalled reader: the FIFO refused a write before the worker released its events'
: > "$fake_home/fake-go"
stall_wait_runner 20
stall_cleanup
check "$stall_done" 'progress: a stderr reader that stops reading cannot hold the run'
if [ "$stall_rc" = 0 ]; then
  ok 'progress: a stderr reader that stops reading does not change the exit code'
else
  fail 'progress: a stderr reader that stops reading does not change the exit code'
fi
assert_lines "$tmp/progress-stalled.err" \
  'stalled reader: the reader took the banner and nothing else before the stall' \
  "$(banner "$run_dir")"
assert_json "$tmp/progress-stalled.json" '.ok == true and .result.answer == "ok" and .turn_completed == true and .spend.commands == 0' \
  'progress: a stderr reader that stops reading does not cost the envelope'
assert_same "$tmp/progress-stalled.json" "$run_dir/result.json" \
  'progress: the envelope still equals result.json after dropped writes'

# A termination signal while a write is stalled. Same FIFO, same shown
# backpressure, but the worker stays alive after its events (fake-hold), so
# the write stalls inside the wait loop with the signal handler armed. The
# suite waits until it sees the writer child under the helper, then sends
# TERM. The helper must tear the worker down (5 s) and exit with the
# interrupted verdict, and no process may be left holding the FIFO: the
# writer has to be gone while the reader is still stalled, before the cleanup
# drains the pipe and would release a writer that had escaped.
stall_writer() { # sets writer_pid: the perl child under the helper, or empty
  writer_pid=""
  for _ in $(seq 1 400); do
    # awk reads ps to its end: leaving at the first match can end ps with
    # SIGPIPE, which pipefail and errexit turn into a dead suite.
    writer_pid="$(ps -ax -o pid=,ppid=,comm= 2>/dev/null \
      | awk -v p="$runner_pid" '$2 == p && $3 ~ /perl/ && pid == "" { pid = $1 } END { print pid }' \
      || true)"
    [ -z "$writer_pid" ] || break
    sleep 0.05
  done
}
: > "$events"
printf '%s\n' \
  '{"type":"item.started","item":{"id":"item_1","type":"command_execution","command":"echo unheard"}}' \
  > "$fake_home/fake-events-late"
: > "$fake_home/fake-hold"
stall_setup progress-stalled-term
check "$stall_ready" 'signal in a stalled write: the banner was read and the worker stood at its gate'
stall_fill
check "$stall_blocked" 'signal in a stalled write: the FIFO refused a write before the worker released its events'
fake_worker="$(cat "$fake_home/fake-pid" 2>/dev/null || true)"
: > "$fake_home/fake-go"
stall_writer
kill -TERM "$runner_pid" 2>/dev/null || true
# Both read off right after the signal left: the write was still stalled, and
# the worker still ran.
writer_at_term=no
[ -z "$writer_pid" ] || ! kill -0 "$writer_pid" 2>/dev/null || writer_at_term=yes
worker_was_alive=no
[ -z "$fake_worker" ] || ! kill -0 "$fake_worker" 2>/dev/null || worker_was_alive=yes
stall_wait_runner 20
worker_gone=no
[ -z "$fake_worker" ] || kill -0 "$fake_worker" 2>/dev/null || worker_gone=yes
writer_gone=no
[ -z "$writer_pid" ] || kill -0 "$writer_pid" 2>/dev/null || writer_gone=yes
stall_cleanup
check "$writer_at_term" 'signal in a stalled write: the writer child was seen under the helper and was still stalled when TERM was sent'
check "$stall_done" 'signal in a stalled write: the helper exits within its teardown bound'
check "$writer_gone" 'signal in a stalled write: the writer is gone once the helper has exited, with the reader still stalled'
assert_json "$run_dir/result.json" '.ok == false and .error_class == "interrupted"' \
  'signal in a stalled write: result.json holds the interrupted verdict'
assert_same "$tmp/progress-stalled-term.json" "$run_dir/result.json" \
  'signal in a stalled write: stdout carries the same verdict'
if [ "$worker_was_alive" = yes ] && [ "$worker_gone" = yes ]; then
  ok 'signal in a stalled write: the worker ran when the signal was sent and is gone afterwards'
else
  fail 'signal in a stalled write: the worker ran when the signal was sent and is gone afterwards'
fi
check "$stall_eof" 'signal in a stalled write: nothing holds the FIFO open once the filler is killed'

# The deadline is wall-clock. A `date` on the helper's PATH adds the seconds
# in fake-date-offset to the real clock. With --timeout 3600 and the worker
# held at its gate, a jump of 4000 s must end the run as a timeout at the next
# tick: a deadline counted in ticks would wait the full hour.
real_date="$(type -P date)"
cat > "$fake_bin/date" <<EOF
#!/usr/bin/env bash
off="\$(cat "$fake_home/fake-date-offset" 2>/dev/null || true)"
if [ -n "\$off" ] && [ "\${1:-}" = +%s ]; then
  printf '%s\n' "\$(( \$("$real_date" +%s) + off ))"
else
  exec "$real_date" "\$@"
fi
EOF
chmod +x "$fake_bin/date"
: > "$events"
printf '%s\n' '{"type":"turn.completed"}' > "$fake_home/fake-events-late"
rm -f "$fake_home/fake-go" "$fake_home/fake-released" "$fake_home/fake-waiting" \
  "$fake_home/fake-date-offset" "$fake_home/fake-pid"
run_dir="$tmp/run-wallclock"
# Started directly, not through run_worker: runner_pid must be the helper
# itself, so a failed case can end it and its worker.
HOME="$fake_home" PATH="$test_path" TMPDIR="$tmp" \
  CODEX_WORKER_MAX_SLOTS=1 CODEX_WORKER_SLOT_WAIT=1 \
  bash "$helper" run \
  --model default --effort low --sandbox read-only --workspace "$tmp" \
  --prompt-file "$prompt" --schema-file "$schema" --run-dir "$run_dir" \
  --timeout 3600 > "$tmp/wallclock.json" 2> "$tmp/wallclock.err" &
runner_pid=$!
for _ in $(seq 1 300); do [ -e "$fake_home/fake-waiting" ] && break; sleep 0.2; done
printf '%s\n' 4000 > "$fake_home/fake-date-offset"
# One tick (at most 5 s) to notice, 5 s of worker teardown, and slack.
stall_wait_runner 30
held=no
[ -e "$fake_home/fake-released" ] || held=yes
fake_worker="$(cat "$fake_home/fake-pid" 2>/dev/null || true)"
: > "$fake_home/fake-go"
if [ "$stall_done" != yes ]; then
  # The helper's own teardown takes the worker with it; the release marker
  # stays until the worker is gone, and a worker that outlives both is ended.
  kill -TERM "$runner_pid" 2>/dev/null || true
  wait "$runner_pid" 2>/dev/null || true
  for _ in $(seq 1 50); do
    [ -n "$fake_worker" ] && kill -0 "$fake_worker" 2>/dev/null || break
    sleep 0.2
  done
  [ -z "$fake_worker" ] || kill -KILL "$fake_worker" 2>/dev/null || true
fi
rm -f "$fake_home/fake-date-offset" "$fake_home/fake-events-late" \
  "$fake_home/fake-go" "$fake_home/fake-released" "$fake_home/fake-waiting"
if [ "$stall_done" = yes ] && [ "$held" = yes ]; then
  ok 'deadline: a clock past the deadline ends the run at the next tick, with the worker still at its gate'
else
  fail 'deadline: a clock past the deadline ends the run at the next tick, with the worker still at its gate'
fi
assert_json "$tmp/wallclock.json" '.ok == false and .error_class == "timeout"' \
  'deadline: the verdict is timeout, read off the clock and not counted in ticks'
assert_same "$tmp/wallclock.json" "$run_dir/result.json" \
  'deadline: the timeout envelope equals result.json'

# The view cannot turn a finished worker into a timeout. The reader is
# stalled and the worker stays alive after its events (fake-hold); while the
# tick's write is stuck, the worker is released to finish and the clock jumps
# past the deadline. The deadline was checked before that write and the next
# check finds the worker gone, so the verdict is the worker's own: ok. A
# deadline check placed after the write would read the jumped clock and
# declare a timeout.
: > "$events"
printf '%s\n' \
  '{"type":"item.started","item":{"id":"item_1","type":"command_execution","command":"echo unheard"}}' \
  '{"type":"turn.completed"}' > "$fake_home/fake-events-late"
: > "$fake_home/fake-hold"
rm -f "$fake_home/fake-date-offset"
stall_setup progress-stalled-deadline
check "$stall_ready" 'deadline in a stalled write: the banner was read and the worker stood at its gate'
stall_fill
check "$stall_blocked" 'deadline in a stalled write: the FIFO refused a write before the worker released its events'
: > "$fake_home/fake-go"
stall_writer
printf '%s\n' 4000 > "$fake_home/fake-date-offset"
: > "$fake_home/fake-end"
jumped_in_write=no
[ -z "$writer_pid" ] || ! kill -0 "$writer_pid" 2>/dev/null || jumped_in_write=yes
stall_wait_runner 20
stall_cleanup
rm -f "$fake_bin/date" "$fake_home/fake-date-offset"
check "$jumped_in_write" 'deadline in a stalled write: the clock jumped and the worker was released while the write was still stalled'
check "$stall_done" 'deadline in a stalled write: the helper ends within its bound'
assert_json "$tmp/progress-stalled-deadline.json" '.ok == true and .result.answer == "ok" and .turn_completed == true' \
  'deadline in a stalled write: a worker that finished is not timed out by the time its progress took'
assert_same "$tmp/progress-stalled-deadline.json" "$run_dir/result.json" \
  'deadline in a stalled write: the envelope equals result.json'

# A progress read that hangs. A `tail` on the helper's PATH hangs on the
# printer's `-n +N` read while fake-tail-hang exists, and passes every other
# call through. The helper ends each such read after two seconds, in the wait
# loop and at the final flush, so the run ends with its normal envelope, no
# progress line and the closing line, and no hung read is left behind.
real_tail="$(type -P tail)"
cat > "$fake_bin/tail" <<EOF
#!/usr/bin/env bash
if [ -e "$fake_home/fake-tail-hang" ] && [ "\${1:-}" = -n ] && [ "\${2#+}" != "\${2:-}" ]; then
  printf '%s\n' "\$\$" >> "$fake_home/fake-tail-pids"
  exec sleep 600
fi
exec "$real_tail" "\$@"
EOF
chmod +x "$fake_bin/tail"
: > "$events"
printf '%s\n' \
  '{"type":"item.started","item":{"id":"item_1","type":"command_execution","command":"echo unread"}}' \
  '{"type":"turn.completed"}' > "$fake_home/fake-events-late"
rm -f "$fake_home/fake-go" "$fake_home/fake-released" "$fake_home/fake-waiting" \
  "$fake_home/fake-pid" "$fake_home/fake-tail-pids"
: > "$fake_home/fake-tail-hang"
run_dir="$tmp/run-progress-readhang"
HOME="$fake_home" PATH="$test_path" TMPDIR="$tmp" \
  CODEX_WORKER_MAX_SLOTS=1 CODEX_WORKER_SLOT_WAIT=1 \
  bash "$helper" run \
  --model default --effort low --sandbox read-only --workspace "$tmp" \
  --prompt-file "$prompt" --schema-file "$schema" --run-dir "$run_dir" \
  --timeout 300 > "$tmp/progress-readhang.json" 2> "$tmp/progress-readhang.err" &
runner_pid=$!
# The worker stands at its gate and the wait loop's first read has started
# before the worker is released, so the loop's read and the final flush's
# are two separate hung reads.
for _ in $(seq 1 300); do
  [ -e "$fake_home/fake-waiting" ] && [ -s "$fake_home/fake-tail-pids" ] && break
  sleep 0.2
done
: > "$fake_home/fake-go"
# One poll (at most 5 s) to see the worker gone, two seconds for the final
# flush's read, and slack.
stall_wait_runner 20
fake_worker="$(cat "$fake_home/fake-pid" 2>/dev/null || true)"
if [ "$stall_done" != yes ]; then
  kill -KILL "$runner_pid" 2>/dev/null || true
  wait "$runner_pid" 2>/dev/null || true
  [ -z "$fake_worker" ] || kill -KILL "$fake_worker" 2>/dev/null || true
fi
hung_reads=0 hung_left=no
for hung_pid in $(cat "$fake_home/fake-tail-pids" 2>/dev/null || true); do
  hung_reads=$((hung_reads + 1))
  if kill -0 "$hung_pid" 2>/dev/null; then
    hung_left=yes
    kill -KILL "$hung_pid" 2>/dev/null || true
  fi
done
rm -f "$fake_bin/tail" "$fake_home/fake-tail-hang" "$fake_home/fake-tail-pids" \
  "$fake_home/fake-events-late" "$fake_home/fake-go" "$fake_home/fake-released" \
  "$fake_home/fake-waiting"
check "$stall_done" 'hanging read: a progress read that hangs cannot hold the run'
if [ "$stall_rc" = 0 ]; then
  ok 'hanging read: the exit code is unchanged'
else
  fail 'hanging read: the exit code is unchanged'
fi
if [ "$hung_reads" -ge 2 ] && [ "$hung_left" = no ]; then
  ok 'hanging read: the read hung in the wait loop and at the final flush, and each was ended'
else
  fail 'hanging read: the read hung in the wait loop and at the final flush, and each was ended'
fi
assert_lines "$tmp/progress-readhang.err" \
  'hanging read: the banner and the closing line print, and no progress line' \
  "$(banner "$run_dir")" \
  "[codex-worker] end ok=true cmds=0 $(secs "$tmp/progress-readhang.json")s"
assert_json "$tmp/progress-readhang.json" '.ok == true and .result.answer == "ok" and .turn_completed == true' \
  'hanging read: the envelope is the normal one'
assert_same "$tmp/progress-readhang.json" "$run_dir/result.json" \
  'hanging read: the envelope equals result.json'

# relay: one read-only run carried across bounded calls. The fake worker
# stands at its gate until the suite releases it, so "still running" is a
# fact about the worker, never about the clock.
relay_gate() { # arm a worker that waits at its gate
  printf '%s\n' scripted > "$fake_home/fake-mode"
  : > "$events"
  printf '%s\n' '{"type":"turn.completed"}' > "$fake_home/fake-events-late"
  rm -f "$fake_home/fake-go" "$fake_home/fake-released" "$fake_home/fake-waiting"
}
relay_gate
run_dir="$tmp/run-relay"
relay_args=(relay --max 2 --model default --effort low --sandbox read-only
  --workspace "$tmp" --prompt-file "$prompt" --schema-file "$schema"
  --run-dir "$run_dir" --timeout 300)
before="$(exec_count)"
# Two calls race for the start; the claim lets one of them start the run.
run_worker "$tmp/relay-race.json" "$tmp/relay-race.err" "${relay_args[@]}" &
race_pid=$!
relay_started="$SECONDS"
run_worker "$tmp/relay-1.json" "$tmp/relay-1.err" "${relay_args[@]}"
relay_took=$((SECONDS - relay_started))
wait "$race_pid" 2>/dev/null || true
for _ in $(seq 1 300); do [ -e "$fake_home/fake-waiting" ] && break; sleep 0.2; done
assert_json "$tmp/relay-1.json" '.pending == true and (has("ok") | not)' \
  'relay: a worker that outlives --max returns pending'
assert_json "$tmp/relay-race.json" '.pending == true' \
  'relay: a call racing the start waits on the same run'
if [ "$relay_took" -le 12 ]; then
  ok 'relay: a pending call returns near its --max'
else
  fail 'relay: a pending call returns near its --max'
fi
assert_single_json "$tmp/relay-1.json" 'relay: a pending call prints exactly one object'
if [ ! -e "$run_dir/result.json" ] && [ -e "$fake_home/fake-waiting" ] \
   && [ ! -e "$fake_home/fake-released" ] \
   && kill -0 "$(cat "$run_dir.relay/pid")" 2>/dev/null; then
  ok 'relay: the runner outlives the call that started it, with no envelope yet'
else
  fail 'relay: the runner outlives the call that started it, with no envelope yet'
fi
run_worker "$tmp/relay-2.json" "$tmp/relay-2.err" "${relay_args[@]}"
assert_json "$tmp/relay-2.json" '.pending == true' \
  'relay: a repeated call waits on the same run'
: > "$fake_home/fake-go"
relay_args[2]=60
run_worker "$tmp/relay-3.json" "$tmp/relay-3.err" "${relay_args[@]}"
assert_json "$tmp/relay-3.json" '.pending == false and .ok == true and (has("error_class") | not)' \
  'relay: the call after the worker finishes reports the verdict'
assert_json "$run_dir/result.json" '.ok == true and .result.answer == "ok" and .turn_completed == true' \
  'relay: result.json is the run'"'"'s own envelope'
run_worker "$tmp/relay-4.json" "$tmp/relay-4.err" "${relay_args[@]}"
assert_same "$tmp/relay-3.json" "$tmp/relay-4.json" \
  'relay: a call after the end repeats the verdict'
if [ "$(exec_count)" -eq "$((before + 1))" ]; then
  ok 'relay: five calls on one run dir, two of them racing, start one worker'
else
  fail 'relay: five calls on one run dir, two of them racing, start one worker'
fi

# The documented stop: TERM to the recorded pid ends the runner through its
# own signal path, and the next call reports that envelope.
relay_gate
run_dir="$tmp/run-relay-term"
relay_args[2]=2
relay_args[${#relay_args[@]}-3]="$run_dir"
run_worker "$tmp/relay-term-1.json" "$tmp/relay-term-1.err" "${relay_args[@]}"
for _ in $(seq 1 300); do [ -e "$fake_home/fake-waiting" ] && break; sleep 0.2; done
term_worker="$(cat "$fake_home/fake-pid" 2>/dev/null || true)"
kill -TERM "$(cat "$run_dir.relay/pid")" 2>/dev/null || true
relay_args[2]=60
run_worker "$tmp/relay-term-2.json" "$tmp/relay-term-2.err" "${relay_args[@]}"
assert_json "$tmp/relay-term-2.json" '.pending == false and .ok == false and .error_class == "interrupted"' \
  'relay: TERM to the recorded pid ends the run as interrupted'
if [ -n "$term_worker" ] && ! kill -0 "$term_worker" 2>/dev/null; then
  ok 'relay: the worker is gone once the interrupted verdict is back'
else
  fail 'relay: the worker is gone once the interrupted verdict is back'
fi
rm -f "$fake_home/fake-events-late" "$fake_home/fake-go" "$fake_home/fake-released" "$fake_home/fake-waiting"
printf '%s\n' success > "$fake_home/fake-mode"

# A refusal before the run dir is used reaches the runner's stdout only;
# relay mirrors it so the harvest file is still the one authority.
before="$(exec_count)"
run_dir="$tmp/run-relay-usage"
run_worker "$tmp/relay-usage.json" "$tmp/relay-usage.err" relay --max 30 \
  --sandbox read-only --workspace "$tmp" --prompt-file "$prompt" --run-dir "$run_dir"
assert_json "$tmp/relay-usage.json" '.pending == false and .ok == false and .error_class == "usage"' \
  'relay: an early refusal comes back as a verdict, not as pending'
assert_json "$run_dir/result.json" '.ok == false and .error_class == "usage" and (.error | contains("--model is required"))' \
  'relay: an envelope that only reached stdout is mirrored into result.json'
run_worker "$tmp/relay-write.json" "$tmp/relay-write.err" relay \
  --model default --sandbox workspace-write --workspace "$tmp" \
  --prompt-file "$prompt" --run-dir "$tmp/run-relay-write"
assert_json "$tmp/relay-write.json" '.pending == false and .ok == false and .error_class == "usage" and (.error | contains("read-only"))' \
  'relay: a write run is refused with a status object'
run_worker "$tmp/relay-nodir.json" "$tmp/relay-nodir.err" relay \
  --model default --workspace "$tmp" --prompt-file "$prompt"
assert_json "$tmp/relay-nodir.json" '.pending == false and .ok == false and .error_class == "usage" and (.error | contains("--run-dir"))' \
  'relay: a call without --run-dir is refused'
run_worker "$tmp/relay-max.json" "$tmp/relay-max.err" relay --max 00 \
  --model default --workspace "$tmp" --prompt-file "$prompt" --run-dir "$tmp/run-relay-write"
assert_json "$tmp/relay-max.json" '.pending == false and .error_class == "usage" and (.error | contains("--max"))' \
  'relay: --max 00 is refused'
# A finished run's directory with no relay claim beside it: its old success
# must not come back as this call's verdict.
run_worker "$tmp/relay-stale.json" "$tmp/relay-stale.err" relay --max 30 \
  --model default --workspace "$tmp" --prompt-file "$prompt" --run-dir "$tmp/run-success"
assert_json "$tmp/relay-stale.json" '.pending == false and .ok == false and .error_class == "usage" and (.error | contains("must be empty"))' \
  'relay: a used run dir is refused, its old result is not reported'
assert_single_json "$tmp/relay-stale.json" 'relay: a refusal prints exactly one object'
assert_same "$tmp/success.json" "$tmp/run-success/result.json" \
  'relay: a refusal leaves the used run dir'"'"'s envelope untouched'
if [ "$(exec_count)" = "$before" ] && [ ! -e "$tmp/run-relay-write.relay" ] \
   && [ ! -e "$tmp/run-success.relay" ]; then
  ok 'relay: refusals start no worker and leave no state'
else
  fail 'relay: refusals start no worker and leave no state'
fi

printf '\n%s checks, %s failures\n' "$((checks + fails))" "$fails"
exit "$fails"
