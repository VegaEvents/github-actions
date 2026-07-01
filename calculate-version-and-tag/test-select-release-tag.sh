#!/usr/bin/env bash
# Self-check for select_release_tag() — the guard that stops a foreign tag
# lineage (e.g. calendar-v*) from becoming the app's version baseline.
# Run: bash calculate-version-and-tag/test-select-release-tag.sh
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=./calculate-version.sh
source "$HERE/calculate-version.sh"

FAILS=0
check() { # desc, expected_out, expected_exit, actual_out, actual_exit
  if [ "$4" = "$2" ] && [ "$5" = "$3" ]; then
    echo "ok   - $1"
  else
    echo "FAIL - $1: expected out='$2' exit=$3, got out='$4' exit=$5"
    FAILS=$((FAILS + 1))
  fi
}

# Fresh throwaway repo per scenario so tag state is isolated.
new_repo() {
  local d; d="$(mktemp -d)"
  git -C "$d" init -q
  git -C "$d" config user.email t@t.t
  git -C "$d" config user.name t
  git -C "$d" commit -q --allow-empty -m init
  echo "$d"
}
run() { # cd into repo, capture stdout + exit of select_release_tag
  local d="$1"; local out; local ec
  out="$(cd "$d" && select_release_tag 2>/dev/null)"; ec=$?
  echo "$out"; return $ec
}

# 1. The incident: a package tag sits on top of real releases. Must ignore it.
d="$(new_repo)"
git -C "$d" tag v2.86.5; git -C "$d" tag v2.86.6; git -C "$d" tag calendar-v0.1.0
out="$(run "$d")"; ec=$?
check "ignores foreign calendar-v* tag, picks newest vX.Y.Z" "v2.86.6" "0" "$out" "$ec"

# 2. Brand-new repo, no tags at all -> seed first release.
d="$(new_repo)"
out="$(run "$d")"; ec=$?
check "no tags seeds v0.0.0" "v0.0.0" "0" "$out" "$ec"

# 3. Only a foreign tag, no app releases yet -> still a first release, not error.
d="$(new_repo)"
git -C "$d" tag calendar-v0.1.0
out="$(run "$d")"; ec=$?
check "only foreign tag seeds v0.0.0" "v0.0.0" "0" "$out" "$ec"

# 4. v-ish but malformed tags only -> refuse to guess (exit 2), print nothing.
d="$(new_repo)"
git -C "$d" tag v2.86; git -C "$d" tag v2.86.6-rc1
out="$(run "$d")"; ec=$?
check "malformed v* tags exit 2" "" "2" "$out" "$ec"

# 5. Version sort, not lexical: v2.86.10 > v2.86.9.
d="$(new_repo)"
git -C "$d" tag v2.86.9; git -C "$d" tag v2.86.10
out="$(run "$d")"; ec=$?
check "version-sorts (v2.86.10 > v2.86.9)" "v2.86.10" "0" "$out" "$ec"

# resolve_baseline_or_die: the wrapper action.yml uses at all 3 sites. It must
# print the baseline on exit 0 for a healthy repo, and hard-exit 1 (not seed
# v0.0.0) when select_release_tag refuses with exit 2. Command substitution runs
# it in a subshell, so its `exit 1` is captured here rather than killing us.
run_die() { local d="$1"; local out; out="$(cd "$d" && resolve_baseline_or_die 2>/dev/null)"; local ec=$?; echo "$out"; return $ec; }

# 6. Healthy repo -> prints baseline, exit 0.
d="$(new_repo)"
git -C "$d" tag v1.2.3
out="$(run_die "$d")"; ec=$?
check "resolve_baseline_or_die prints baseline on healthy repo" "v1.2.3" "0" "$out" "$ec"

# 7. Malformed-only tags -> hard exit 1, prints nothing (does NOT seed v0.0.0).
d="$(new_repo)"
git -C "$d" tag v2.86; git -C "$d" tag v2.86.6-rc1
out="$(run_die "$d")"; ec=$?
check "resolve_baseline_or_die exits 1 (no guess) on malformed tags" "" "1" "$out" "$ec"

echo "---"
if [ "$FAILS" -eq 0 ]; then echo "all passed"; else echo "$FAILS failed"; exit 1; fi
