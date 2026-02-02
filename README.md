# GitHub Actions - Shared Workflows

Custom GitHub Actions for deploying Vega web applications. These actions consolidate common deployment patterns across vega-web, vega-web-lite, and GroundControl.

## 📦 Available Actions

### 1. `calculate-version-and-tag`

Calculates the next semantic version from conventional commits and creates a git tag. This action analyzes commit messages since the last tag to determine the appropriate version bump (major, minor, or patch) and atomically creates the new tag.

**Usage:**

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

**Inputs:**
| Input | Required | Default | Description |
|-------|----------|---------|-------------|
| `merge-commit-sha` | No | `''` | The merge commit SHA to tag (for PR merges) |
| `ref` | No | `''` | The git ref to use if merge-commit-sha is not provided |
| `github-token` | Yes | - | GitHub token for pushing tags (use `${{ secrets.GITHUB_TOKEN }}`) |

**Outputs:**
| Output | Description |
|--------|-------------|
| `version` | The calculated semantic version (without v prefix, e.g., `1.2.3`) |
| `tag_name` | The git tag name (with v prefix, e.g., `v1.2.3`) |

**What it does:**

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

**Race Condition Handling:**

This action is designed to work safely in concurrent workflows:
- Re-fetches tags before each attempt to detect conflicts
- Retries with recalculated version if another job created a tag
- Uses atomic git operations to prevent duplicate tags
- Fails after 3 attempts with clear error message

**Example in deployment workflow:**

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

---

### 2. `setup-node-yarn`

Sets up Node.js environment with Yarn and installs dependencies.

**Usage:**

```yaml
- uses: actions/checkout@v6

- uses: VegaEvents/github-actions/setup-node-yarn@v1
  # Uses Node.js 24 by default

- uses: VegaEvents/github-actions/setup-node-yarn@v1
  with:
    node-version: "20" # Optional: override Node version
```

**Inputs:**
| Input | Required | Default | Description |
|-------|----------|---------|-------------|
| `node-version` | No | `24` | Node.js version to install |

**What it does:**

- Sets up Node.js with the specified version
- Enables Corepack for Yarn
- Installs dependencies with `yarn install --immutable`
- Optimized for self-hosted runners (no remote caching overhead)

---

### 3. `build-and-deploy-firebase-preview`

Builds the application and deploys to Firebase Hosting preview channel for PR testing.

**Usage:**

```yaml
- uses: VegaEvents/github-actions/build-and-deploy-firebase-preview@v1
  id: deploy
  with:
    build-command: "yarn build-dev"
    firebase-project: "fluttervega-f312c"
    firebase-target: "admin-dev-vegaevents"
    firebase-service-account: ${{ secrets.FIREBASE_SERVICE_ACCOUNT_DEV }}
    channel-id: "pr-${{ github.event.pull_request.number }}"

- run: echo "Deployed to ${{ steps.deploy.outputs.preview-url }}"
```

**Inputs:**
| Input | Required | Default | Description |
|-------|----------|---------|-------------|
| `build-command` | Yes | - | Build command to run (e.g., `yarn build-dev`) |
| `firebase-project` | Yes | - | Firebase project ID |
| `firebase-target` | Yes | - | Firebase hosting target name |
| `firebase-service-account` | Yes | - | Firebase service account JSON (from secrets) |
| `channel-id` | Yes | - | Preview channel ID (e.g., `pr-123`) |
| `firebase-tools-version` | No | `15.1.0` | Firebase CLI version |

**Outputs:**
| Output | Description |
|--------|-------------|
| `preview-url` | URL of the deployed preview environment |

**What it does:**

- Cleans any existing `dist/` directory
- Runs the build command
- Verifies build output exists and is non-empty
- Sets up Firebase service account credentials
- Deploys to Firebase Hosting preview channel
- Returns the preview URL
- Cleans up credentials (always runs, even on failure)

---

### 4. `comment-preview-urls`

Creates or updates a PR comment with preview deployment URLs.

**Usage:**

```yaml
- uses: VegaEvents/github-actions/comment-preview-urls@v1
  with:
    github-token: ${{ secrets.GITHUB_TOKEN }}
    pr-number: ${{ github.event.pull_request.number }}
    commit-sha: ${{ github.event.pull_request.head.sha }}
    dev-url: ${{ needs.deploy-dev.outputs.preview_url }}
    dev-status: ${{ needs.deploy-dev.result }}
    staging-url: ${{ needs.deploy-staging.outputs.preview_url }}
    staging-status: ${{ needs.deploy-staging.result }}
    prod-url: ${{ needs.deploy-prod.outputs.preview_url }}
    prod-status: ${{ needs.deploy-prod.result }}
    version: ${{ needs.bump-version.outputs.new-version }}
    version-bumped: ${{ needs.bump-version.outputs.version-bumped }}
```

**Inputs:**
| Input | Required | Default | Description |
|-------|----------|---------|-------------|
| `github-token` | Yes | - | GitHub token for API access |
| `pr-number` | Yes | - | Pull request number |
| `commit-sha` | Yes | - | Commit SHA (truncated to 7 chars in display) |
| `dev-url` | No | `''` | Dev environment preview URL |
| `dev-status` | No | `pending` | Dev deployment status (`success`/`failure`/`skipped`) |
| `staging-url` | No | `''` | Staging environment preview URL |
| `staging-status` | No | `pending` | Staging deployment status |
| `prod-url` | No | `''` | Production environment preview URL |
| `prod-status` | No | `pending` | Production deployment status |
| `version` | No | `''` | Version string (optional) |
| `version-bumped` | No | `false` | Whether version was auto-bumped |

**What it does:**

- Formats deployment information into a table
- Finds existing preview comment on the PR (if any)
- Creates new comment or updates existing one
- Shows environment status with emoji indicators
- Includes version and commit information

---

## 🚀 Complete Workflow Example

Here's how all three actions work together in a PR preview workflow:

```yaml
name: Deploy PR Preview

on:
  pull_request:
    types: [opened, synchronize, reopened]
    branches:
      - main

concurrency:
  group: pr-preview-${{ github.event.pull_request.number }}
  cancel-in-progress: true

permissions:
  contents: write
  pull-requests: write

jobs:
  # Your existing bump-version and ci jobs
  bump-version:
    uses: ./.github/workflows/bump-version.yml
    # ...

  ci:
    needs: bump-version
    uses: ./.github/workflows/ci.yml

  # Deploy to dev environment
  deploy-dev:
    needs: [bump-version, ci]
    runs-on:
      group: app-builders-2
    if: needs.ci.result == 'success'
    outputs:
      preview_url: ${{ steps.deploy.outputs.preview-url }}
    env:
      BRYNTUM_NPM_TOKEN: ${{ secrets.BRYNTUM_AUTH_TOKEN }} # vega-web only

    steps:
      - uses: actions/checkout@v6
        with:
          ref: ${{ github.event.pull_request.head.ref }}

      - uses: VegaEvents/github-actions/setup-node-yarn@v1

      # vega-web only: Configure Bryntum
      - name: Configure Bryntum npm registry
        run: |
          npm config set "@bryntum:registry=https://npm-us.bryntum.com"
          npm config set "//npm-us.bryntum.com/:_authToken=${{ secrets.BRYNTUM_AUTH_TOKEN }}"

      - uses: VegaEvents/github-actions/build-and-deploy-firebase-preview@v1
        id: deploy
        with:
          build-command: yarn build-dev
          firebase-project: fluttervega-f312c
          firebase-target: admin-dev-vegaevents
          firebase-service-account: ${{ secrets.FIREBASE_SERVICE_ACCOUNT_DEV }}
          channel-id: pr-${{ github.event.pull_request.number }}

  # Deploy to staging environment (similar pattern)
  deploy-staging:
    # ... similar to deploy-dev with staging values

  # Deploy to prod environment (similar pattern)
  deploy-prod:
    # ... similar to deploy-dev with prod values

  # Comment on PR with all preview URLs
  comment-on-pr:
    needs: [bump-version, deploy-dev, deploy-staging, deploy-prod]
    runs-on:
      group: app-builders-2
    if: always()

    steps:
      - uses: VegaEvents/github-actions/comment-preview-urls@v1
        with:
          github-token: ${{ secrets.GITHUB_TOKEN }}
          pr-number: ${{ github.event.pull_request.number }}
          commit-sha: ${{ github.event.pull_request.head.sha }}
          dev-url: ${{ needs.deploy-dev.outputs.preview_url }}
          dev-status: ${{ needs.deploy-dev.result }}
          staging-url: ${{ needs.deploy-staging.outputs.preview_url }}
          staging-status: ${{ needs.deploy-staging.result }}
          prod-url: ${{ needs.deploy-prod.outputs.preview_url }}
          prod-status: ${{ needs.deploy-prod.result }}
          version: ${{ needs.bump-version.outputs.new-version }}
          version-bumped: ${{ needs.bump-version.outputs.version-bumped }}
```

---

## 📌 Versioning

This repository uses semantic versioning with Git tags:

- `@v1` - Latest v1.x.x release (recommended for stability with auto-updates)
- `@v1.0.0` - Specific version (use for maximum reproducibility)
- `@main` - Bleeding edge (not recommended for production)

**Updating actions:**

```bash
# Make changes to actions
git add .
git commit -m "fix: improve error handling in build action"
git push

# Use the release script (recommended)
./release.sh patch

# Or manually tag
git tag v1.0.1
git push origin v1.0.1
git tag -fa v1 -m "Update v1 to v1.0.1"
git push origin v1 --force
```

**Release script usage:**
```bash
./release.sh patch    # Bug fixes (1.0.1 → 1.0.2)
./release.sh minor    # New features (1.0.2 → 1.1.0)
./release.sh major    # Breaking changes (1.1.0 → 2.0.0)
./release.sh v1.2.3   # Specific version
```

---

## 🔄 Migration Guide

### Before (Duplicated Code)

```yaml
# Same ~50 lines repeated in each job
- uses: actions/checkout@v6
- uses: actions/setup-node@v4
  with:
    node-version: 24
- run: corepack enable
- run: yarn install --immutable
- run: yarn build-dev
- run: echo '${{ secrets.FIREBASE_SERVICE_ACCOUNT_DEV }}' > ...
- run: npx firebase-tools@15.1.0 hosting:channel:deploy ...
- run: rm -f $RUNNER_TEMP/firebase-service-account.json
```

### After (Consolidated)

```yaml
# 3 clean, reusable action calls
- uses: actions/checkout@v6
- uses: VegaEvents/github-actions/setup-node-yarn@v1
- uses: VegaEvents/github-actions/build-and-deploy-firebase@v1
  with:
    build-command: yarn build-dev
    firebase-project: fluttervega-f312c
    firebase-target: admin-dev-vegaevents
    firebase-service-account: ${{ secrets.FIREBASE_SERVICE_ACCOUNT_DEV }}
    channel-id: pr-${{ github.event.pull_request.number }}
```

---

## 🐛 Troubleshooting

### Build Failures

The `build-and-deploy-firebase` action validates:

- ✅ Build command exits successfully
- ✅ `dist/` directory is created
- ✅ `dist/` directory is not empty

If build fails, check:

1. Build command is correct for your environment
2. Dependencies are installed correctly
3. Environment variables are set (if needed)

### Firebase Deployment Failures

Common issues:

- **Invalid service account**: Ensure secret contains valid JSON
- **Wrong target name**: Check Firebase hosting configuration
- **Permissions**: Service account needs Firebase Hosting Admin role

### Comment Not Appearing

Ensure workflow has correct permissions:

```yaml
permissions:
  contents: write
  pull-requests: write
```

---

## 📝 Maintenance

### When to Update Actions

**Patch updates (v1.0.x):** Bug fixes, no breaking changes

- Update tag and move `v1` pointer
- All apps using `@v1` get the fix automatically

**Minor updates (v1.x.0):** New features, backward compatible

- Update tag and move `v1` pointer
- Apps can opt into new features via inputs

**Major updates (v2.0.0):** Breaking changes

- Create new `v2` tag
- Update apps one at a time
- Keep `v1` available for gradual migration

---

## 🤝 Contributing

When adding new actions or updating existing ones:

1. **Test locally** in one app first
2. **Update this README** with any new inputs/outputs
3. **Tag appropriately** following semantic versioning
4. **Update all apps** that should use the new version

---

## 📚 Resources

- [GitHub Actions: Creating composite actions](https://docs.github.com/en/actions/creating-actions/creating-a-composite-action)
- [GitHub Actions: Workflow syntax](https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions)
- [Firebase Hosting: Preview channels](https://firebase.google.com/docs/hosting/test-preview-deploy)
