# calculate-version-and-tag

Calculates the next semantic version from conventional commits and creates a git tag. This action analyzes commit messages since the last tag to determine the appropriate version bump (major, minor, or patch) and atomically creates the new tag.

## Usage

```yaml
- uses: VegaEvents/github-actions/calculate-version-and-tag@v1
  id: version
  with:
    merge-commit-sha: ${{ github.event.pull_request.merge_commit_sha }}
    ref: ${{ github.ref }}
    github-token: ${{ secrets.GITHUB_TOKEN }}

- run: echo "Version ${{ steps.version.outputs.version }}"
- run: echo "Tag ${{ steps.version.outputs.tag_name }}"
```

## Inputs

| Input | Required | Default | Description |
|-------|----------|---------|-------------|
| `merge-commit-sha` | No | `''` | The merge commit SHA to tag (for PR merges) |
| `ref` | No | `''` | The git ref to use if merge-commit-sha is not provided |
| `github-token` | Yes | - | GitHub token for pushing tags (use `${{ secrets.GITHUB_TOKEN }}`) |

## Outputs

| Output | Description |
|--------|-------------|
| `version` | The calculated semantic version (without v prefix, e.g., `1.2.3`) |
| `tag_name` | The git tag name (with v prefix, e.g., `v1.2.3`) |

## What it does

- Checks out the repository with full git history
- Sets up Node.js for running semver calculations
- Fetches all existing git tags
- Analyzes commit messages since the last tag using conventional commit format:
  - `BREAKING CHANGE` or `type!:` → major bump (e.g., 1.0.0 → 2.0.0)
  - `feat:` → minor bump (e.g., 1.0.0 → 1.1.0)
  - `fix:` or `perf:` → patch bump (e.g., 1.0.0 → 1.0.1)
  - Other commits → defaults to patch bump
- Handles race conditions with retry logic (3 attempts)
- Atomically creates and pushes the new git tag
- Short-circuits if no version bump is needed or tag already exists
- Returns both the version number and tag name for use in subsequent jobs

## Race Condition Handling

This action is designed to work safely in concurrent workflows:

- Re-fetches tags before each attempt to detect conflicts
- Retries with recalculated version if another job created a tag
- Uses atomic git operations to prevent duplicate tags
- Fails after 3 attempts with clear error message

## Example in deployment workflow

```yaml
jobs:
  ci:
    uses: ./.github/workflows/ci.yml

  calculate-version:
    needs: ci
    runs-on:
      group: app-builders-2
    if: needs.ci.result == 'success'
    concurrency:
      group: calculate-version-${{ github.repository }}-${{ github.ref }}
      cancel-in-progress: false
    permissions:
      contents: write
    outputs:
      version: ${{ steps.version.outputs.version }}
      tag_name: ${{ steps.version.outputs.tag_name }}
    steps:
      - uses: VegaEvents/github-actions/calculate-version-and-tag@v1
        id: version
        with:
          merge-commit-sha: ${{ github.event.pull_request.merge_commit_sha }}
          ref: ${{ github.ref }}
          github-token: ${{ secrets.GITHUB_TOKEN }}

  deploy-prod:
    needs: [ci, calculate-version]
    env:
      VERSION: ${{ needs.calculate-version.outputs.version }}
    steps:
      - run: echo "Deploying version $VERSION"
```
