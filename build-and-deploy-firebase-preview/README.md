# build-and-deploy-firebase-preview

Builds the application and deploys to Firebase Hosting preview channel for PR testing.

The caller must authenticate to GCP before invoking this action — e.g. via `google-github-actions/auth@v2` using Workload Identity Federation. The action relies on `GOOGLE_APPLICATION_CREDENTIALS` (set by that step) for Firebase CLI auth.

## Usage

```yaml
permissions:
  contents: read
  id-token: write

# ...

- uses: google-github-actions/auth@v2
  with:
    workload_identity_provider: projects/<PROJECT_NUMBER>/locations/global/workloadIdentityPools/github/providers/<PROVIDER_ID>
    service_account: <SA_EMAIL>

- uses: VegaEvents/github-actions/build-and-deploy-firebase-preview@v3
  id: deploy
  with:
    build-command: "yarn build-dev"
    firebase-project: "fluttervega-f312c"
    firebase-target: "admin-dev-vegaevents"
    channel-id: "pr-${{ github.event.pull_request.number }}"

- run: echo "Deployed to ${{ steps.deploy.outputs.preview-url }}"
```

## Inputs

| Input | Required | Default | Description |
|-------|----------|---------|-------------|
| `build-command` | Yes | - | Build command to run (e.g., `yarn build-dev`) |
| `firebase-project` | Yes | - | Firebase project ID |
| `firebase-target` | Yes | - | Firebase hosting target name |
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
- Deploys to Firebase Hosting preview channel using caller-provided ADC
- Returns the preview URL, and **fails the step if that URL cannot be determined**, rather than
  returning an empty string (see Troubleshooting)

## Breaking changes in v3

- Removed `firebase-service-account` input. Callers must authenticate via `google-github-actions/auth@v2` (or equivalent) before invoking this action. Migration: delete the input, add an `auth@v2` step with `workload_identity_provider` + `service_account`, and add `id-token: write` to the job's `permissions`.

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

- **Missing credentials**: Ensure `google-github-actions/auth@v2` ran before this step and the job declares `id-token: write`
- **Wrong target name**: Check Firebase hosting configuration
- **Permissions**: Service account needs Firebase Hosting Admin role on the target project

### "Deploy succeeded but no preview URL could be parsed"

The channel deployed, but the action could not read a URL out of the Firebase CLI's `--json` payload,
so it failed the step instead of handing downstream jobs an empty string.

The step logs the raw stdout under `Firebase output:` and stderr under `Firebase stderr:` — read those
first. The usual cause is something other than JSON reaching stdout, or the `--only <target>` value not
matching the key Firebase returns under `result`.

This condition used to be silent: the parse failed, the step still reported success, and the empty
output surfaced much later in whatever consumed it — a CSP or smoke-test job invoked with an empty URL,
or a PR comment stuck on "Pending" for a channel that was actually live.
