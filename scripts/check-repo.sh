#!/usr/bin/env bash
set -euo pipefail

repo_root="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

command -v node >/dev/null 2>&1 || {
  printf 'FAIL: node is required for repository checks\n' >&2
  exit 1
}
command -v jq >/dev/null 2>&1 || {
  printf 'FAIL: jq is required for the Codex worker and its tests\n' >&2
  exit 1
}
command -v claude >/dev/null 2>&1 || {
  printf 'FAIL: claude is required for plugin validation\n' >&2
  exit 1
}

node scripts/check-repo.mjs

while IFS= read -r -d '' script; do
  bash -n "$script"
done < <(git ls-files -z '*.sh')

bash skills/orchestrate/scripts/test-codex-worker.sh
bash skills/orchestrate/scripts/test-gemini-worker.sh
bash skills/orchestrate/scripts/test-stage-wait.sh
node skills/drawio/scripts/test-validate-drawio.mjs
node skills/excalidraw/scripts/test-excalidraw.mjs
if command -v python3 >/dev/null 2>&1 && python3 -c 'import sys; sys.exit(sys.version_info < (3, 7))' 2>/dev/null; then
  python3 skills/history-audit/scripts/test-history-audit.py
else
  printf 'SKIP: history-audit tests need python3 >= 3.7\n'
fi

bash skills/orchestrate/scripts/check-helper-resolution.sh

# Strict validation with one known warning allowed: the root CLAUDE.md is the
# import adapter for agent sessions working in this repository, not plugin
# context, so "not loaded as project context" is expected. Any error, any
# other warning, or a second warning fails as --strict would.
validate_out="$(claude plugin validate . 2>&1)" || {
  printf '%s\n' "$validate_out" >&2
  exit 1
}
warnings="$(printf '%s\n' "$validate_out" \
  | sed -n 's/.*Found \([0-9][0-9]*\) warning.*/\1/p' \
  | awk '{ n += $1 } END { print n + 0 }')"
# Anchored to the warning's own line, and read from a here-string: `grep -q`
# behind a pipe can exit early and fail the pipeline under pipefail.
known_warning='^[[:space:]]*❯ root: CLAUDE\.md at the plugin root is not loaded as project context\.'
if [ "$warnings" -gt 1 ] \
  || { [ "$warnings" -eq 1 ] && ! grep -qE "$known_warning" <<<"$validate_out"; }; then
  printf '%s\n' "$validate_out" >&2
  printf 'FAIL: plugin validation warnings beyond the root CLAUDE.md adapter\n' >&2
  exit 1
fi
claude plugin validate .claude-plugin/plugin.json
git diff --check
git diff --check "$(git hash-object -t tree /dev/null)"

printf 'PASS: static and provider-free checks completed\n'
printf 'NOT covered: real provider runs, pretty-pdf rendering, native diagram\n'
printf 'rendering, agents/*.md frontmatter, and plugin install inventory\n'
printf '(run an isolated "claude plugin details" check for releases).\n'
