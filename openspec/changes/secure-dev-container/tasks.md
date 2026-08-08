## 1. Dockerfile and Base Image

- [x] 1.1 Create `.devcontainer/Dockerfile` with pinned Node.js 24 (`node:24-bookworm`)
- [x] 1.2 Install git, curl, and essential build tools in the image
- [x] 1.3 Install terraform-ls (language server binary only, no terraform CLI)
- [x] 1.4 Configure a non-root developer user in the image
- [x] 1.5 Set git config to disable credential helper (`credential.helper ""`) and disable interactive prompts
- [x] 1.6 Install npm 12 in the image (override the Node 24 bundled npm if necessary)
- [x] 1.7 Create `~/.npmrc` in the image with `ignore-scripts=true`, `min-release-age=21`, and `audit=true`

## 2. devcontainer.json Configuration

- [x] 2.1 Create `.devcontainer/devcontainer.json` with build context pointing to the Dockerfile
- [x] 2.2 Configure bind mount: host project directory → `/workspace`
- [x] 2.3 Configure named Docker volume for `/workspace/node_modules`
- [x] 2.4 Declare container-side extensions: Jest, YAML, Claude Code, HashiCorp Terraform
- [x] 2.5 Configure `postCreateCommand` to set git user.name and user.email from environment variables
- [x] 2.6 Explicitly exclude SSH agent forwarding (do NOT set `"agent forwarding"` or mount SSH_AUTH_SOCK)
- [x] 2.7 Ensure no host environment variables for credentials are passed through (no GCP, AWS, TF_TOKEN vars)

## 3. Docker Compose (Volume Definitions)

- [x] 3.1 Create `.devcontainer/docker-compose.yml` defining the named node_modules volume
- [x] 3.2 Configure the service with the correct bind mount and volume mount
- [x] 3.3 Verify container cannot access host filesystem beyond the project mount

## 4. Credential Isolation Verification

- [x] 4.1 Create a verification script (`scripts/verify-isolation.sh`) that checks from inside the container: no SSH keys, no GCP creds, no Terraform creds, no Docker socket, no credential env vars
- [x] 4.2 Run verification script inside a built container and confirm all checks pass
- [x] 4.3 Document the verification script in the troubleshooting runbook

## 5. Rebuild Automation

- [x] 5.1 Create `scripts/rebuild.sh` that stops the container, removes node_modules volume, and triggers a fresh build
- [x] 5.2 Create `scripts/setup.sh` that verifies Mac prerequisites (Docker Desktop installed, VS Code Dev Containers extension installed)
- [x] 5.3 Test full destroy-and-rebuild cycle: run rebuild.sh, reopen in container, verify working environment

## 6. Runbooks

- [x] 6.1 Write `docs/runbooks/initial-setup.md` — prerequisites, installation, first container launch
- [x] 6.2 Write `docs/runbooks/daily-workflow.md` — open project, edit, test, commit (container), push (Mac)
- [x] 6.3 Write `docs/runbooks/new-project-onboarding.md` — how to configure a new repo to use the shared template
- [x] 6.4 Write `docs/runbooks/compromise-response.md` — destroy container, verify Mac, rebuild, revoke credentials if needed
- [x] 6.5 Write `docs/runbooks/terraform-workflow.md` — terraform plan/apply from Mac terminal alongside container development
- [x] 6.6 Write `docs/runbooks/troubleshooting.md` — common issues and resolutions

## 7. Integration Testing

- [x] 7.1 Open a sample Node.js project using the Dev Container config and verify: VS Code connects, extensions load, terminal works
- [x] 7.2 Run `npm install` inside container, verify node_modules lands in the volume (not on Mac filesystem)
- [x] 7.3 Run `npm test` inside container, verify tests pass
- [x] 7.4 Create a git commit inside container, verify it's visible from Mac `git log`
- [x] 7.5 Verify `git push` fails from inside container (no credentials)
- [x] 7.6 Verify `git push` succeeds from Mac terminal for the same repo
- [x] 7.7 Open a .tf file and verify syntax highlighting / language server works without terraform binary

## 8. README and Documentation

- [x] 8.1 Update repository README.md with project overview, architecture diagram, and links to runbooks
- [x] 8.2 Document the shared template consumption mechanism (how other repos use this config)
- [x] 8.3 Add security model summary to README (what's protected, what's not, accepted risks)
