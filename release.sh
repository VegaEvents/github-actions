#!/bin/bash

# GitHub Actions Release Script
# Automates versioning, tagging, and pushing for the shared actions repository
#
# Usage:
#   ./release.sh patch    # Bumps from v1.0.1 to v1.0.2
#   ./release.sh minor    # Bumps from v1.0.1 to v1.1.0
#   ./release.sh major    # Bumps from v1.0.1 to v2.0.0
#   ./release.sh v1.2.3   # Sets specific version

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
  echo -e "${BLUE}ℹ${NC} $1"
}

print_success() {
  echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
  echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
  echo -e "${RED}✗${NC} $1"
}

# Check if we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
  print_error "Not in a git repository"
  exit 1
fi

# Check for uncommitted changes
if ! git diff-index --quiet HEAD --; then
  print_error "You have uncommitted changes. Commit or stash them first."
  git status --short
  exit 1
fi

# Check if we're on main branch
CURRENT_BRANCH=$(git branch --show-current)
if [ "$CURRENT_BRANCH" != "main" ]; then
  print_warning "You're on branch '$CURRENT_BRANCH', not 'main'"
  read -p "Continue anyway? (y/N) " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 1
  fi
fi

# Get the latest tag
LATEST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "v0.0.0")
print_info "Latest tag: $LATEST_TAG"

# Parse version numbers
if [[ $LATEST_TAG =~ ^v([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
  MAJOR="${BASH_REMATCH[1]}"
  MINOR="${BASH_REMATCH[2]}"
  PATCH="${BASH_REMATCH[3]}"
else
  print_error "Could not parse latest tag: $LATEST_TAG"
  exit 1
fi

# Determine new version based on input
BUMP_TYPE=$1

if [ -z "$BUMP_TYPE" ]; then
  print_error "Usage: $0 {patch|minor|major|vX.Y.Z}"
  echo ""
  echo "Examples:"
  echo "  $0 patch    # $LATEST_TAG → v$MAJOR.$MINOR.$((PATCH + 1))"
  echo "  $0 minor    # $LATEST_TAG → v$MAJOR.$((MINOR + 1)).0"
  echo "  $0 major    # $LATEST_TAG → v$((MAJOR + 1)).0.0"
  echo "  $0 v1.2.3   # $LATEST_TAG → v1.2.3"
  exit 1
fi

case $BUMP_TYPE in
  patch)
    NEW_VERSION="v$MAJOR.$MINOR.$((PATCH + 1))"
    ;;
  minor)
    NEW_VERSION="v$MAJOR.$((MINOR + 1)).0"
    ;;
  major)
    NEW_VERSION="v$((MAJOR + 1)).0.0"
    ;;
  v*)
    # Custom version provided
    if [[ $BUMP_TYPE =~ ^v([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
      NEW_VERSION="$BUMP_TYPE"
    else
      print_error "Invalid version format: $BUMP_TYPE (expected vX.Y.Z)"
      exit 1
    fi
    ;;
  *)
    print_error "Invalid bump type: $BUMP_TYPE"
    print_info "Use: patch, minor, major, or vX.Y.Z"
    exit 1
    ;;
esac

print_info "New version: $NEW_VERSION"

# Extract major version for floating tag
if [[ $NEW_VERSION =~ ^v([0-9]+)\. ]]; then
  MAJOR_TAG="v${BASH_REMATCH[1]}"
else
  print_error "Could not extract major version from $NEW_VERSION"
  exit 1
fi

# Prompt for confirmation
echo ""
print_warning "This will:"
echo "  1. Create tag: $NEW_VERSION"
echo "  2. Update floating tag: $MAJOR_TAG"
echo "  3. Push to origin"
echo ""
read -p "Continue? (y/N) " -n 1 -r
echo

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  print_info "Aborted"
  exit 0
fi

# Prompt for release notes
echo ""
print_info "Enter release notes (press Ctrl+D when done):"
RELEASE_NOTES=$(cat)

if [ -z "$RELEASE_NOTES" ]; then
  RELEASE_NOTES="Release $NEW_VERSION"
fi

# Create the version tag
print_info "Creating tag $NEW_VERSION..."
git tag -a "$NEW_VERSION" -m "$RELEASE_NOTES"
print_success "Tag $NEW_VERSION created"

# Update the major version tag
print_info "Updating floating tag $MAJOR_TAG..."
git tag -fa "$MAJOR_TAG" -m "Update $MAJOR_TAG to $NEW_VERSION"
print_success "Tag $MAJOR_TAG updated"

# Push to origin
print_info "Pushing to origin..."
git push origin "$NEW_VERSION"
git push origin "$MAJOR_TAG" --force
print_success "Tags pushed to origin"

echo ""
print_success "Release $NEW_VERSION complete!"
echo ""
print_info "Actions can now use:"
echo "  uses: VegaEvents/github-actions/setup-node-yarn@$NEW_VERSION"
echo "  uses: VegaEvents/github-actions/setup-node-yarn@$MAJOR_TAG"
