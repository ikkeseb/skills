#!/bin/sh
# Regression check for the codex-worker agent's helper-path resolution.
#
# The bug this guards (found 2026-07-26): the agent carried only two
# candidates — $CLAUDE_PLUGIN_ROOT, which nothing sets when the agent is
# deployed as a plain file, and the session repo's git toplevel, which only
# points at the helper when the session is rooted in the skills repo. The
# whole Codex lane therefore failed with missing_dependency from every other
# repo, and stayed invisible because it is exercised mostly from here.
#
# So: every scenario below runs from a cwd that is NOT this repo, except the
# one that deliberately tests the in-repo path. The snippet under test is
# extracted from agents/codex-worker.md rather than copied, so editing the
# candidates away fails this check instead of silently passing it.
#
# Deployment shapes are simulated with throwaway HOMEs, so the result does
# not depend on how the machine running this happens to be set up.
#
# Usage: sh skills/orchestrate/scripts/check-helper-resolution.sh

set -u

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo=$(CDPATH= cd -- "$script_dir/../../.." && pwd)
agent_file="$repo/agents/codex-worker.md"
helper="$repo/skills/orchestrate/scripts/codex-worker.sh"

[ -f "$agent_file" ] || { echo "FAIL: agent file not found: $agent_file" >&2; exit 1; }
[ -x "$helper" ] || { echo "FAIL: helper missing or not executable: $helper" >&2; exit 1; }

tmp=$(mktemp -d) || exit 1
trap 'rm -rf "$tmp"' EXIT INT TERM

# Extract the first fenced bash block — the helper-resolution snippet.
snippet="$tmp/resolve.sh"
awk '/^```bash$/ { n++; next } /^```$/ { if (n == 1) exit; next } n == 1' \
  "$agent_file" > "$snippet"
grep -q 'CLAUDE_PLUGIN_ROOT' "$snippet" || {
  echo "FAIL: no helper-resolution block found in $agent_file" >&2; exit 1; }

canon() {
  [ -e "$1" ] || return 1
  (CDPATH= cd -- "$(dirname -- "$1")" 2>/dev/null &&
     printf '%s/%s\n' "$(pwd -P)" "$(basename -- "$1")")
}
helper_canon=$(canon "$helper")

# resolve <cwd> <home> <plugin-root>   — empty plugin-root means unset
resolve() {
  HOME="$2" CLAUDE_PLUGIN_ROOT="$3" sh -c '
    [ -n "$CLAUDE_PLUGIN_ROOT" ] || unset CLAUDE_PLUGIN_ROOT
    cd "$1" || exit 1
    . "$2"
    printf %s "$HELPER"' _ "$1" "$snippet"
}

fails=0
expect_helper() {
  if [ -x "$2" ] && [ "$(canon "$2")" = "$helper_canon" ]; then
    printf 'ok    %s\n' "$1"
  else
    printf 'FAIL  %s\n      resolved to: %s\n' "$1" "${2:-<empty>}"
    fails=$((fails + 1))
  fi
}
expect_nothing() {
  if [ -x "$2" ]; then
    printf 'FAIL  %s\n      expected no candidate to match, got: %s\n' "$1" "$2"
    fails=$((fails + 1))
  else
    printf 'ok    %s\n' "$1"
  fi
}

# Foreign session locations: a git repo that is not this one, and a plain dir.
foreign_repo="$tmp/foreign-repo"
mkdir -p "$foreign_repo" && (cd "$foreign_repo" && git init -q .) || {
  echo "FAIL: could not create a throwaway git repo" >&2; exit 1; }
plain_dir="$tmp/plain-dir"; mkdir -p "$plain_dir"

# Deployment shapes, each as its own HOME.
bare_home="$tmp/home-bare"; mkdir -p "$bare_home"
skill_home="$tmp/home-skill-symlink"
mkdir -p "$skill_home/.claude/skills"
ln -s "$repo/skills/orchestrate" "$skill_home/.claude/skills/orchestrate"
clone_home="$tmp/home-clone"
mkdir -p "$clone_home"
ln -s "$repo" "$clone_home/skills"

expect_helper 'plugin install, foreign cwd (candidate 1)' \
  "$(resolve "$foreign_repo" "$bare_home" "$repo")"
expect_helper 'session rooted in the skills repo (candidate 2)' \
  "$(resolve "$repo" "$bare_home" '')"
expect_helper 'symlinked skill deploy, foreign git repo (candidate 3)' \
  "$(resolve "$foreign_repo" "$skill_home" '')"
expect_helper 'symlinked skill deploy, non-git cwd (candidate 3)' \
  "$(resolve "$plain_dir" "$skill_home" '')"
expect_helper 'repo cloned at $HOME/skills, foreign git repo (candidate 4)' \
  "$(resolve "$foreign_repo" "$clone_home" '')"
expect_nothing 'no deployment at all — check can actually fail' \
  "$(resolve "$foreign_repo" "$bare_home" '')"

if [ "$fails" -eq 0 ]; then
  echo "all scenarios passed"
else
  printf '%s scenario(s) failed\n' "$fails" >&2
fi
exit "$fails"
