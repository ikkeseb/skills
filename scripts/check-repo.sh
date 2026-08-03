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
done < <(find skills/orchestrate/scripts -type f -name '*.sh' -print0)

bash skills/orchestrate/scripts/test-codex-worker.sh
node skills/drawio/scripts/test-validate-drawio.mjs
node skills/excalidraw/scripts/test-excalidraw.mjs

bash skills/orchestrate/scripts/check-helper-resolution.sh

claude plugin validate . --strict
claude plugin validate .claude-plugin/plugin.json
git diff --check

printf 'PASS: repository checks completed\n'
