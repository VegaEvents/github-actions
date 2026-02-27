# setup-gh

Installs and authenticates the GitHub CLI (`gh`). Useful for self-hosted runners that don't have `gh` pre-installed.

## Usage

```yaml
- uses: VegaEvents/github-actions/setup-gh@v1
  with:
    gh-token: ${{ secrets.GITHUB_TOKEN }}
```

## Inputs

| Input | Required | Default | Description |
|-------|----------|---------|-------------|
| `gh-token` | Yes | - | GitHub token used to authenticate the CLI |

## What it does

- Checks if `gh` is already installed (skips installation if so)
- Installs `gh` via the official apt repository (Linux) or Homebrew (macOS)
- Fails with a clear error on unsupported platforms
- Authenticates using the provided token and verifies with `gh auth status`
