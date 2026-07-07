#!/usr/bin/env bash
# Self-check for calculate_version() — bump-type detection from conventional
# commits. Subjects drive the type (feat/fix/perf/!); bodies are scanned only
# for BREAKING CHANGE footers, so a body line starting "feat:" must NOT
# inflate the bump.
# Run: bash calculate-version-and-tag/test-calculate-version.sh
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

# Fresh throwaway repo per scenario, baseline tag v1.2.0 on the init commit.
new_repo() {
  local d; d="$(mktemp -d)"
  git -C "$d" init -q
  git -C "$d" config user.email t@t.t
  git -C "$d" config user.name t
  git -C "$d" commit -q --allow-empty -m init
  git -C "$d" tag v1.2.0
  echo "$d"
}
run() { # repo, baseline_tag -> stdout + exit of calculate_version
  local d="$1"; local tag="$2"; local out; local ec
  out="$(cd "$d" && calculate_version "$tag" 2>/dev/null)"; ec=$?
  echo "$out"; return $ec
}

# 1. feat subject -> minor.
d="$(new_repo)"
git -C "$d" commit -q --allow-empty -m 'feat: add thing'
out="$(run "$d" v1.2.0)"; ec=$?
check "feat: bumps minor" "1.3.0" "0" "$out" "$ec"

# 2. fix subject -> patch.
d="$(new_repo)"
git -C "$d" commit -q --allow-empty -m 'fix: squash bug'
out="$(run "$d" v1.2.0)"; ec=$?
check "fix: bumps patch" "1.2.1" "0" "$out" "$ec"

# 3. perf subject -> patch.
d="$(new_repo)"
git -C "$d" commit -q --allow-empty -m 'perf(core): faster'
out="$(run "$d" v1.2.0)"; ec=$?
check "perf(scope): bumps patch" "1.2.1" "0" "$out" "$ec"

# 4. feat!: subject -> major.
d="$(new_repo)"
git -C "$d" commit -q --allow-empty -m 'feat!: drop old API'
out="$(run "$d" v1.2.0)"; ec=$?
check "feat!: bumps major" "2.0.0" "0" "$out" "$ec"

# 5. BREAKING CHANGE footer in body (fix subject) -> major.
d="$(new_repo)"
git -C "$d" commit -q --allow-empty -m 'fix: small thing' -m 'BREAKING CHANGE: removes the old endpoint'
out="$(run "$d" v1.2.0)"; ec=$?
check "BREAKING CHANGE footer bumps major" "2.0.0" "0" "$out" "$ec"

# 6. Body line starting "feat:" must NOT inflate a fix commit to minor.
d="$(new_repo)"
git -C "$d" commit -q --allow-empty -m 'fix: small thing' -m 'feat: mentioned in prose, not a real feat'
out="$(run "$d" v1.2.0)"; ec=$?
check "feat: in body does not inflate bump" "1.2.1" "0" "$out" "$ec"

# 7. Unrecognized prefix -> defaults to patch.
d="$(new_repo)"
git -C "$d" commit -q --allow-empty -m 'chore: tidy up'
out="$(run "$d" v1.2.0)"; ec=$?
check "unrecognized prefix defaults to patch" "1.2.1" "0" "$out" "$ec"

# 8. No commits since tag -> current version unchanged, no bump.
d="$(new_repo)"
out="$(run "$d" v1.2.0)"; ec=$?
check "no new commits returns version unchanged" "1.2.0" "0" "$out" "$ec"

# 9. First release: v0.0.0 baseline scans full history.
d="$(new_repo)"
git -C "$d" commit -q --allow-empty -m 'feat: first feature'
out="$(run "$d" v0.0.0)"; ec=$?
check "v0.0.0 baseline with feat gives 0.1.0" "0.1.0" "0" "$out" "$ec"

echo "---"
if [ "$FAILS" -eq 0 ]; then echo "all passed"; else echo "$FAILS failed"; exit 1; fi
