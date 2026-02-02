#!/bin/bash

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
