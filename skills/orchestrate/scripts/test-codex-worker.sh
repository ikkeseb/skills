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
    read-policy-denied)
      printf '%s\n' '{"answer":"incomplete"}' > "$output"
      printf '%s\n' '{"type":"turn.completed"}'
      printf '%s\n' 'ERROR: exec_command failed: CreateProcess rejected: blocked by policy' >&2
      return 0 ;;
    missing-result)
      printf '%s\n' '{"type":"turn.completed"}'
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

printf '\n%s checks, %s failures\n' "$((checks + fails))" "$fails"
exit "$fails"
