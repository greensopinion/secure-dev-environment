## 1. Dockerfile and Base Image

- [ ] 1.1 Create `.devcontainer/Dockerfile` with pinned Node.js 24 (`node:24-bookworm`)
- [ ] 1.2 Install git, curl, and essential build tools in the image
- [ ] 1.3 Install terraform-ls (language server binary only, no terraform CLI)
- [ ] 1.4 Configure a non-root developer user in the image
- [ ] 1.5 Set git config to disable credential helper (`credential.helper ""`) and disable interactive prompts
- [ ] 1.6 Install npm 12 in the image (override the Node 24 bundled npm if necessary)
- [ ] 1.7 Create `~/.npmrc` in the image with `ignore-scripts=true`, `min-release-age=21`, and `audit=true`

## 2. devcontainer.json Configuration

- [ ] 2.1 Create `.devcontainer/devcontainer.json` with build context pointing to the Dockerfile
- [ ] 2.2 Configure bind mount: host project directory → `/workspace`
- [ ] 2.3 Configure named Docker volume for `/workspace/node_modules`
- [ ] 2.4 Declare container-side extensions: Jest, YAML, Claude Code, HashiCorp Terraform
- [ ] 2.5 Configure `postCreateCommand` to set git user.name and user.email from environment variables
- [ ] 2.6 Explicitly exclude SSH agent forwarding (do NOT set `"agent forwarding"` or mount SSH_AUTH_SOCK)
- [ ] 2.7 Ensure no host environment variables for credentials are passed through (no GCP, AWS, TF_TOKEN vars)

## 3. Docker Compose (Volume Definitions)

- [ ] 3.1 Create `.devcontainer/docker-compose.yml` defining the named node_modules volume
- [ ] 3.2 Configure the service with the correct bind mount and volume mount
- [ ] 3.3 Verify container cannot access host filesystem beyond the project mount

## 4. Credential Isolation Verification

- [ ] 4.1 Create a verification script (`scripts/verify-isolation.sh`) that checks from inside the container: no SSH keys, no GCP creds, no Terraform creds, no Docker socket, no credential env vars
- [ ] 4.2 Run verification script inside a built container and confirm all checks pass
- [ ] 4.3 Document the verification script in the troubleshooting runbook

## 5. Rebuild Automation

- [ ] 5.1 Create `scripts/rebuild.sh` that stops the container, removes node_modules volume, and triggers a fresh build
- [ ] 5.2 Create `scripts/setup.sh` that verifies Mac prerequisites (Docker Desktop installed, VS Code Dev Containers extension installed)
- [ ] 5.3 Test full destroy-and-rebuild cycle: run rebuild.sh, reopen in container, verify working environment

## 6. Runbooks

- [ ] 6.1 Write `docs/runbooks/initial-setup.md` — prerequisites, installation, first container launch
- [ ] 6.2 Write `docs/runbooks/daily-workflow.md` — open project, edit, test, commit (container), push (Mac)
- [ ] 6.3 Write `docs/runbooks/new-project-onboarding.md` — how to configure a new repo to use the shared template
- [ ] 6.4 Write `docs/runbooks/compromise-response.md` — destroy container, verify Mac, rebuild, revoke credentials if needed
- [ ] 6.5 Write `docs/runbooks/terraform-workflow.md` — terraform plan/apply from Mac terminal alongside container development
- [ ] 6.6 Write `docs/runbooks/troubleshooting.md` — common issues and resolutions

## 7. Integration Testing

- [ ] 7.1 Open a sample Node.js project using the Dev Container config and verify: VS Code connects, extensions load, terminal works
- [ ] 7.2 Run `npm install` inside container, verify node_modules lands in the volume (not on Mac filesystem)
- [ ] 7.3 Run `npm test` inside container, verify tests pass
- [ ] 7.4 Create a git commit inside container, verify it's visible from Mac `git log`
- [ ] 7.5 Verify `git push` fails from inside container (no credentials)
- [ ] 7.6 Verify `git push` succeeds from Mac terminal for the same repo
- [ ] 7.7 Open a .tf file and verify syntax highlighting / language server works without terraform binary

## 8. README and Documentation

- [ ] 8.1 Update repository README.md with project overview, architecture diagram, and links to runbooks
- [ ] 8.2 Document the shared template consumption mechanism (how other repos use this config)
- [ ] 8.3 Add security model summary to README (what's protected, what's not, accepted risks)
