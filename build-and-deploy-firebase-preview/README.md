# build-and-deploy-firebase-preview

Builds the application and deploys to Firebase Hosting preview channel for PR testing.

## Usage

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

## Inputs

| Input | Required | Default | Description |
|-------|----------|---------|-------------|
| `build-command` | Yes | - | Build command to run (e.g., `yarn build-dev`) |
| `firebase-project` | Yes | - | Firebase project ID |
| `firebase-target` | Yes | - | Firebase hosting target name |
| `firebase-service-account` | Yes | - | Firebase service account JSON (from secrets) |
| `channel-id` | Yes | - | Preview channel ID (e.g., `pr-123`) |
| `firebase-tools-version` | No | `15.5.1` | Firebase CLI version |

## Outputs

| Output | Description |
|--------|-------------|
| `preview-url` | URL of the deployed preview |

## What it does

- Cleans any existing `dist/` directory
- Runs the build command
- Verifies build output exists and is non-empty
- Sets up Firebase service account credentials
- Deploys to Firebase Hosting preview channel
- Returns the preview URL
- Cleans up credentials (always runs, even on failure)

## Troubleshooting

### Build Failures

This action validates:

- Build command exits successfully
- `dist/` directory is created
- `dist/` directory is not empty

If the build fails, check:

1. Build command is correct for your environment
2. Dependencies are installed correctly
3. Environment variables are set (if needed)

### Firebase Deployment Failures

Common issues:

- **Invalid service account**: Ensure secret contains valid JSON
- **Wrong target name**: Check Firebase hosting configuration
- **Permissions**: Service account needs Firebase Hosting Admin role
