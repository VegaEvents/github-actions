#!/bin/bash

# Selects the app's release baseline: the newest tag matching vX.Y.Z (strict
# semver, no prerelease). Logs to stderr; prints ONLY the tag on stdout so it is
# safe to capture with $(...). Deliberately ignores foreign tag lineages such as
# calendar-v* — callers should warn when one is present (see action.yml) rather
# than let it become the baseline, which is what took the pipeline down when
# `git describe --tags` grabbed calendar-v0.1.0 and fed it to `npx semver`.
#
# Exit codes:
#   0 - printed a usable baseline (a real vX.Y.Z tag, or v0.0.0 for the very
#       first release when the repo has no tags at all)
#   2 - v* tags exist but NONE are valid vX.Y.Z. We refuse to guess; the caller
#       should surface this loudly and stop, rather than silently pick something.
select_release_tag() {
  local latest
  latest=$(git tag -l 'v*' --sort=-v:refname | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | head -n1)

  if [ -n "$latest" ]; then
    echo "Selected release baseline tag: $latest" >&2
    echo "$latest"
    return 0
  fi

  # No valid vX.Y.Z tag. Distinguish "brand new repo, first release" from
  # "there are v-ish tags but they're malformed" — the latter is suspicious.
  if git tag -l 'v*' | grep -q .; then
    echo "Found v* tag(s) but none match vX.Y.Z:" >&2
    git tag -l 'v*' >&2
    return 2
  fi

  echo "No release tags found - seeding first release at v0.0.0" >&2
  echo "v0.0.0"
  return 0
}

# Resolves the release baseline or dies loudly. Enforces select_release_tag's
# exit-2 "refuse to guess" contract in ONE place so every caller behaves
# identically — the retry loop used to `|| echo v0.0.0` here, silently seeding
# v0.0.0 on a malformed-tag repo (the exact guess the guard exists to prevent).
# Prints only the tag on stdout; safe to capture with $(...). On exit 2 it emits
# the workflow error to stderr and exits — under `set -e` (Actions bash default)
# a failed $(...) assignment propagates that exit to the parent (verified).
# Call sites still append `|| exit 1` so the guard survives a refactor into an
# errexit-suppressed context (an `if !` condition, a `||` chain, or `local`).
resolve_baseline_or_die() {
  local tag ec
  set +e; tag=$(select_release_tag); ec=$?; set -e
  if [ "$ec" -ne 0 ]; then
    echo "::error title=No valid release tag::Could not determine a version baseline (select_release_tag exit $ec). If v* tags exist but none match vX.Y.Z, inspect 'git tag -l' and remove or fix the offending tag(s) before retrying." >&2
    exit 1
  fi
  echo "$tag"
}

# Function to calculate version from commits (logs to stderr; only version to stdout)
calculate_version() {
  local latest_tag=$1
  local latest_version="${latest_tag#v}"
  
  echo "Latest tag: $latest_tag" >&2
  echo "Latest version: $latest_version" >&2

  # Get commits since latest tag. Type detection (feat/fix/perf/!) reads
  # subjects only, so a body paragraph starting "feat: ..." can't inflate the
  # bump; full bodies are scanned ONLY for BREAKING CHANGE, which per
  # conventional commits is a footer and lives in the body.
  local range subjects bodies
  if [ "$latest_tag" = "v0.0.0" ]; then
    range="HEAD"
  else
    range="$latest_tag..HEAD"
  fi
  subjects=$(git log --format="%s" "$range")
  bodies=$(git log --format="%B" "$range")

  if [ -z "$subjects" ]; then
    echo "No new commits since last tag" >&2
    echo "$latest_version"
    return 0
  fi

  echo "Commits since $latest_tag:" >&2
  echo "$subjects" >&2

  # Determine bump type from conventional commits
  local bump=""
  if echo "$bodies" | grep -qiE '^BREAKING CHANGE' || echo "$subjects" | grep -qiE '^[a-z]+(\([^)]+\))?!:'; then
    bump="major"
    echo "Found breaking change - major bump" >&2
  elif echo "$subjects" | grep -qiE '^feat(\([^)]+\))?:'; then
    bump="minor"
    echo "Found feat commit - minor bump" >&2
  elif echo "$subjects" | grep -qiE '^(fix|perf)(\([^)]+\))?:'; then
    bump="patch"
    echo "Found fix/perf commit - patch bump" >&2
  else
    bump="patch"
    echo "No conventional commit found - defaulting to patch bump" >&2
  fi

  echo "Bump type: $bump" >&2
  npx -y semver@7.8.5 "$latest_version" -i "$bump"
}
