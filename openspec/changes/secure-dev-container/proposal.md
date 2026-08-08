## Why

npm supply-chain attacks can execute arbitrary code during `npm install`, `npm test`, `npm run build`, and application execution. On a typical developer Mac, a compromised dependency has access to SSH keys, GCP credentials, Terraform state, and other high-value secrets. The goal is to move Node.js/npm execution into an isolated Docker container so that a compromised dependency has no access to the developer's credentials, while preserving a near-native VS Code development experience.

## What Changes

- Introduce a shared Dev Container template (Dockerfile + devcontainer.json) that provides the Node.js development environment inside Docker Desktop on Mac.
- Source code is bind-mounted from the Mac; `node_modules` lives in a Docker volume (performance + isolation).
- Git push/pull/clone happens on the Mac only (SSH keys never enter the container). Git staging/committing/stashing works inside the container (no credentials needed).
- VS Code connects to the container via the Dev Containers extension. Only a minimal set of extensions runs inside: Jest, YAML, Claude Code, HashiCorp Terraform (syntax/language server only).
- Terraform/gcloud remain on the Mac with their credentials. The container has no GCP credentials, no SSH keys, no agent forwarding, no Docker socket.
- The container is disposable — rebuild from the `.devcontainer/` config at any time.
- All configuration, templates, and SOPs (runbooks) live in this `developer-environment` repo as a single source of truth.

## Capabilities

### New Capabilities
- `container-template`: Shared Dev Container configuration (Dockerfile, devcontainer.json) for Node.js projects, with pinned Node version, volume strategy, and minimal extension set.
- `credential-isolation`: Security boundary configuration ensuring no Mac credentials (SSH, GCP, Terraform) cross into the container. Explicit deny-list of mounts and forwarding.
- `git-split-workflow`: Git workflow where credential-requiring operations (push/pull/fetch/clone) run on Mac, and local operations (add/commit/stash/diff/log) run in either environment.
- `disposable-environment`: Automation for tearing down and rebuilding the development container from scratch, including volume cleanup and fresh state.
- `runbooks`: Standard operating procedures covering all supported use-cases: initial setup, daily workflow, adding a new project, rebuilding after compromise, Terraform workflow, and troubleshooting.

### Modified Capabilities
<!-- No existing capabilities to modify — this is the initial change. -->

## Impact

- **Developer workflow**: Git push/pull moves to a Mac terminal. All other development (editing, testing, building, debugging) happens in the container via VS Code.
- **Docker Desktop**: Required on Mac. Resource allocation (CPU, memory) needs to be appropriate for Node.js builds.
- **VS Code configuration**: Dev Containers extension required. Local extensions reduced to minimum. Per-project extensions declared in devcontainer.json.
- **Terraform**: No change to Terraform workflow. Runs on Mac with local credentials as before. Language server in container for syntax support only.
- **Repository structure**: This `developer-environment` repo gains `.devcontainer/` template, runbook docs, and automation scripts.
- **Per-project repos**: Each Node.js repo will reference or copy the shared Dev Container template (mechanism TBD — symlink, copy, or VS Code workspace config).
