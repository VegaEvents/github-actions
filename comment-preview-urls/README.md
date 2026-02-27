# comment-preview-urls

Creates or updates a PR comment with preview deployment URLs.

## Usage

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

## Inputs

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

## What it does

- Formats deployment information into a table
- Finds existing preview comment on the PR (if any)
- Creates new comment or updates existing one
- Shows environment status with emoji indicators
- Includes version and commit information

## Troubleshooting

### Comment Not Appearing

Ensure workflow has correct permissions:

```yaml
permissions:
  contents: write
  pull-requests: write
```
