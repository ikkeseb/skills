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
node skills/drawio/scripts/test-validate-drawio.mjs
node skills/excalidraw/scripts/test-excalidraw.mjs

bash skills/orchestrate/scripts/check-helper-resolution.sh

claude plugin validate . --strict
claude plugin validate .claude-plugin/plugin.json
git diff --check
git diff --check "$(git hash-object -t tree /dev/null)"

printf 'PASS: static and provider-free checks completed\n'
printf 'NOT covered: real provider runs, pretty-pdf rendering, native diagram\n'
printf 'rendering, agents/*.md frontmatter, and plugin install inventory\n'
printf '(run an isolated "claude plugin details" check for releases).\n'
