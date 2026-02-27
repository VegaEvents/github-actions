# setup-node-yarn

Sets up Node.js environment with Yarn and installs dependencies.

## Usage

```yaml
- uses: actions/checkout@v6

- uses: VegaEvents/github-actions/setup-node-yarn@v1
  # Uses Node.js 24 by default

- uses: VegaEvents/github-actions/setup-node-yarn@v1
  with:
    node-version: "20" # Optional: override Node version
```

## Inputs

| Input | Required | Default | Description |
|-------|----------|---------|-------------|
| `node-version` | No | `24` | Node.js version to install |

## What it does

- Sets up Node.js with the specified version
- Enables Corepack (so Yarn can be used via `corepack enable` / `yarn` in later steps)
