#!/bin/sh
# Regression check for how this repo's Codex-lane surfaces locate the helper.
#
# Two defects, both found 2026-07-26 and both guarded here.
#
# Reachability: the candidate list held only $CLAUDE_PLUGIN_ROOT, which nothing
# sets when content is deployed by symlink rather than installed as a plugin,
# and the session repo's git toplevel. Every other repo got missing_dependency,
# and it stayed invisible because the lane is exercised almost entirely from
# here — the one condition under which the list works.
#
# Trust: that git-toplevel candidate named the repo being worked on, so a
# skills/orchestrate/scripts/codex-worker.sh committed in any repo under review
# would have been executed with the session's privileges. It was removed in
# 0.8.4, and the canaries below assert it stays removed. Every surviving
# candidate is a location this repo's own content is deployed to.
#
# So: scenarios run from a cwd that is NOT this repo, deployment shapes are
# simulated with throwaway HOMEs so the verdict does not depend on how the
# machine running this happens to be wired, and two canaries plant a hostile
# helper in the session repo and require it to lose.
#
# The list is duplicated across surfaces by necessity — a subagent file loads
# no references, and a SKILL.md may not reference a sibling skill (AGENTS.md
# § Conventions). This makes the duplication safe: the surfaces are named
# explicitly (grep alone would silently stop seeing a file whose anchor line
# was reindented), required byte-identical, and the block that runs is
# extracted from the file rather than transcribed here.
#
# Known and accepted: the block is not `set -u` safe, because hardening
# ${CLAUDE_PLUGIN_ROOT} into fallback syntax would break the harness's literal
# placeholder rewrite. Claude Code's Bash tool does not run with nounset.
#
# Usage: sh skills/orchestrate/scripts/check-helper-resolution.sh

set -u

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo=$(CDPATH= cd -- "$script_dir/../../.." && pwd)
helper="$repo/skills/orchestrate/scripts/codex-worker.sh"
rel_helper="skills/orchestrate/scripts/codex-worker.sh"

# Every surface that must carry the candidate list, named explicitly.
SURFACES="agents/codex-worker.md
skills/orchestrate/SKILL.md
skills/second-opinion/SKILL.md"
EXPECTED_CANDIDATES=3

[ -x "$helper" ] || { echo "FAIL: helper missing or not executable: $helper" >&2; exit 1; }

tmp=$(mktemp -d) || exit 1
trap 'rm -rf "$tmp"' EXIT INT TERM
fails=0

# Git for Windows emulates `ln -s` by copying unless native symlinks are
# enabled. The deployment cases below specifically test symlink resolution;
# without a real link they otherwise produce four misleading path failures.
symlink_target="$tmp/symlink-probe-target"
symlink_link="$tmp/symlink-probe-link"
mkdir -p "$symlink_target"
if ! ln -s "$symlink_target" "$symlink_link" 2>/dev/null || [ ! -L "$symlink_link" ]; then
  case "$(uname -s 2>/dev/null || true)" in
    MINGW*|MSYS*|CYGWIN*)
      echo "FAIL: this check needs real Windows symlinks; start a new shell with MSYS=winsymlinks:nativestrict (and enable Windows Developer Mode if creation is denied), then rerun it" >&2 ;;
    *)
      echo "FAIL: this check needs working symbolic-link support" >&2 ;;
  esac
  exit 1
fi

# Every line of the candidate list, wherever it sits and whatever markdown
# wraps it. Anchored on the first candidate; stops at the first line that is
# neither an assignment nor a fallback.
extract() {
  awk '
    { sub(/\r$/, "") }  # a CRLF worktree (WSL on a Windows checkout) must not
                        # leak \r into the candidate paths — MSYS strips it in
                        # text mode, Linux awk does not
    /^HELPER="\$\{CLAUDE_PLUGIN_ROOT\}/ { in_block = 1 }
    in_block && /^(HELPER=|\[ -x "\$HELPER" \] \|\|)/ { print; next }
    in_block { exit }
  ' "$1"
}

snippet="$tmp/resolve.sh"
canonical=""
canonical_file=""
for f in $SURFACES; do
  if [ ! -f "$repo/$f" ]; then
    printf 'FAIL  %s is missing\n' "$f"; fails=$((fails + 1)); continue
  fi
  anchors=$(grep -c '^HELPER="${CLAUDE_PLUGIN_ROOT}' "$repo/$f")
  if [ "$anchors" -ne 1 ]; then
    printf 'FAIL  %s has %s anchor lines, expected exactly 1\n' "$f" "$anchors"
    fails=$((fails + 1)); continue
  fi
  block=$(extract "$repo/$f")
  lines=$(printf '%s\n' "$block" | wc -l | tr -d ' ')
  if [ "$lines" -ne "$EXPECTED_CANDIDATES" ]; then
    printf 'FAIL  %s has %s candidates, expected %s\n' "$f" "$lines" "$EXPECTED_CANDIDATES"
    fails=$((fails + 1)); continue
  fi
  if [ -z "$canonical" ]; then
    canonical=$block; canonical_file=$f
    printf '%s\n' "$canonical" > "$snippet"
    printf 'found %s (canonical, %s candidates)\n' "$f" "$lines"
  elif [ "$block" = "$canonical" ]; then
    printf 'found %s (identical)\n' "$f"
  else
    printf 'FAIL  %s drifted from %s\n' "$f" "$canonical_file"
    printf '%s\n' "$block" | diff -u "$snippet" - || true
    fails=$((fails + 1))
  fi
done
[ -s "$snippet" ] || { echo "FAIL: no usable candidate list found" >&2; exit 1; }

# A copy nobody declared is a copy nobody checks.
undeclared=$(cd "$repo" && grep -rl '^HELPER="${CLAUDE_PLUGIN_ROOT}' \
    --exclude-dir=.git --exclude-dir=local . 2>/dev/null | sed 's|^\./||' |
  grep -v -e '^CHANGELOG\.md$' -e "^skills/orchestrate/scripts/" |
  grep -vxF "$SURFACES" | sort)
if [ -n "$undeclared" ]; then
  printf 'FAIL  candidate list also appears in undeclared file(s):\n%s\n' "$undeclared"
  fails=$((fails + 1))
fi
echo

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

# What a plugin install actually does: literal text substitution at load time,
# not an environment variable. Modelled separately because a rewrite that
# mangles the path would pass the env-var form and fail here.
resolve_rewritten() {
  sed "s|\${CLAUDE_PLUGIN_ROOT}|$2|g" "$snippet" > "$tmp/rewritten.sh"
  HOME="$3" sh -c 'cd "$1" || exit 1; . "$2"; printf %s "$HELPER"' \
    _ "$1" "$tmp/rewritten.sh"
}

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

# A repo under review that ships its own executable helper at the very path
# the removed candidate would have found.
hostile_repo="$tmp/hostile-repo"
mkdir -p "$hostile_repo/$(dirname "$rel_helper")"
(cd "$hostile_repo" && git init -q .)
printf '#!/bin/sh\necho HOSTILE_HELPER_EXECUTED\n' > "$hostile_repo/$rel_helper"
chmod +x "$hostile_repo/$rel_helper"

# Deployment shapes, each as its own HOME.
bare_home="$tmp/home-bare"; mkdir -p "$bare_home"
skill_home="$tmp/home-skill-symlink"
mkdir -p "$skill_home/.claude/skills"
ln -s "$repo/skills/orchestrate" "$skill_home/.claude/skills/orchestrate"
clone_home="$tmp/home-clone"; mkdir -p "$clone_home"
ln -s "$repo" "$clone_home/skills"

expect_helper 'plugin install, placeholder rewritten, foreign cwd' \
  "$(resolve_rewritten "$foreign_repo" "$repo" "$bare_home")"
expect_helper 'plugin root as env var, foreign cwd' \
  "$(resolve "$foreign_repo" "$bare_home" "$repo")"
expect_helper 'symlinked skill deploy, foreign git repo' \
  "$(resolve "$foreign_repo" "$skill_home" '')"
expect_helper 'symlinked skill deploy, non-git cwd' \
  "$(resolve "$plain_dir" "$skill_home" '')"
expect_helper 'repo cloned at $HOME/skills, foreign git repo' \
  "$(resolve "$foreign_repo" "$clone_home" '')"
expect_nothing 'no deployment, cwd is this repo — cwd is never trusted' \
  "$(resolve "$repo" "$bare_home" '')"
expect_nothing 'CANARY: session repo ships its own helper, no deployment' \
  "$(resolve "$hostile_repo" "$bare_home" '')"
expect_helper 'CANARY: session repo ships its own helper, real deploy present' \
  "$(resolve "$hostile_repo" "$skill_home" '')"
expect_nothing 'no deployment at all — check can actually fail' \
  "$(resolve "$foreign_repo" "$bare_home" '')"

echo
if [ "$fails" -eq 0 ]; then
  echo "all checks passed"
else
  printf '%s check(s) failed\n' "$fails" >&2
fi
exit "$fails"
