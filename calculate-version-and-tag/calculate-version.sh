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

# Function to calculate version from commits (logs to stderr; only version to stdout)
calculate_version() {
  local latest_tag=$1
  local latest_version="${latest_tag#v}"
  
  echo "Latest tag: $latest_tag" >&2
  echo "Latest version: $latest_version" >&2

  # Get commits since latest tag
  local commits
  if [ "$latest_tag" = "v0.0.0" ]; then
    commits=$(git log --format="%B" HEAD)
  else
    commits=$(git log "$latest_tag"..HEAD --format="%B")
  fi

  if [ -z "$commits" ]; then
    echo "No new commits since last tag" >&2
    echo "$latest_version"
    return 0
  fi

  echo "Commits since $latest_tag:" >&2
  echo "$commits" >&2

  # Determine bump type from conventional commits
  local bump=""
  if echo "$commits" | grep -qiE '(^BREAKING CHANGE|^[a-z]+(\([^)]+\))?!:)'; then
    bump="major"
    echo "Found breaking change - major bump" >&2
  elif echo "$commits" | grep -qiE '^feat(\([^)]+\))?:'; then
    bump="minor"
    echo "Found feat commit - minor bump" >&2
  elif echo "$commits" | grep -qiE '^(fix|perf)(\([^)]+\))?:'; then
    bump="patch"
    echo "Found fix/perf commit - patch bump" >&2
  else
    bump="patch"
    echo "No conventional commit found - defaulting to patch bump" >&2
  fi

  echo "Bump type: $bump" >&2
  npx semver "$latest_version" -i "$bump"
}
