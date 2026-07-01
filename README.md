# GitHub Actions - Shared Workflows

Custom GitHub Actions for deploying Vega web applications. These actions consolidate common deployment patterns across vega-web, vega-web-lite, and GroundControl.

## Available Actions

| Action | Description |
|--------|-------------|
| [`calculate-version-and-tag`](./calculate-version-and-tag/README.md) | Calculates the next semantic version from conventional commits and creates a git tag |
| [`setup-node-yarn`](./setup-node-yarn/README.md) | Sets up Node.js environment with Yarn |
| [`build-and-deploy-firebase-preview`](./build-and-deploy-firebase-preview/README.md) | Builds the application and deploys to Firebase Hosting preview channel |
| [`comment-preview-urls`](./comment-preview-urls/README.md) | Creates or updates a PR comment with preview deployment URLs |
| [`setup-gh`](./setup-gh/README.md) | Installs and authenticates the GitHub CLI (`gh`) |


## Versioning

This repository uses semantic versioning with Git tags:

- `@v1` - Latest v1.x.x release (recommended for stability with auto-updates)
- `@v1.0.0` - Specific version (use for maximum reproducibility)
- `@main` - Bleeding edge (not recommended for production)

### Releases are automatic

Every merge to `main` triggers the [Release workflow](.github/workflows/release.yml), which:

1. Calculates the next version from conventional commits since the last release tag matching `vX.Y.Z` (foreign lineages like `calendar-v*` are ignored)
2. Creates and pushes the new semver tag (e.g., `v3.0.2`)
3. Updates the floating major tag (e.g., `v3`) so consumers on `@v3` pick up the release

There is no manual release step — **the version bump is decided entirely by your commit messages**, so conventional-commit hygiene *is* the release process:

| Commit prefix | Bump |
|---|---|
| `BREAKING CHANGE` / `type!:` | major |
| `feat:` | minor |
| `fix:` / `perf:` | patch |
| anything else | patch |

Every merge cuts a release. To batch changes into one version, land them in a single squashed merge.

## Contributing

When adding new actions or updating existing ones:

1. **Test locally** in one app first
2. **Add a README** in the action's directory with usage docs
3. **Update the table** in this README
4. **Tag appropriately** following semantic versioning
5. **Update all apps** that should use the new version

## Resources

- [GitHub Actions: Creating composite actions](https://docs.github.com/en/actions/creating-actions/creating-a-composite-action)
- [GitHub Actions: Workflow syntax](https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions)
- [Firebase Hosting: Preview channels](https://firebase.google.com/docs/hosting/test-preview-deploy)
