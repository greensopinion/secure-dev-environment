# Secure Development Environment

Isolate Node.js/npm execution from developer credentials using Docker Dev Containers.

## Architecture

```
┌──────────────────────────────────────────────────────────────────────┐
│  Mac (trusted)                                                       │
│  ┌────────────────────────────────────────────────────────────────┐  │
│  │ VS Code (Dev Containers ext)                                   │  │
│  │ Git (push/pull/clone)                                          │  │
│  │ Terraform / gcloud                                             │  │
│  │ SSH keys, GCP credentials                                      │  │
│  │ NO Node.js, NO npm                                             │  │
│  └───────────┬────────────────────────────────────────────────────┘  │
│              │ bind mount (project dir only)                          │
│              ▼                                                        │
│  ┌────────────────────────────────────────────────────────────────┐  │
│  │ Docker Container                                               │  │
│  │ Node.js 24 + npm 12                                            │  │
│  │ Source code at /workspace (from Mac)                           │  │
│  │ node_modules in Docker volume (fast, isolated)                 │  │
│  │ Git (staging/committing only — no push credentials)            │  │
│  │ terraform-ls (syntax support, no CLI)                          │  │
│  │                                                                │  │
│  │ NO SSH keys · NO GCP creds · NO Docker socket                  │  │
│  └────────────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────────┘
```

## Security Model

**Threat**: Malicious npm packages executing arbitrary code during install/test/build.

**Mitigation**: The machine that executes untrusted JavaScript does not have access to developer credentials.

### What's Protected

| Credential | Location | Container Access |
|-----------|----------|-----------------|
| SSH keys | Mac `~/.ssh/` | ❌ None |
| GCP credentials | Mac `~/.config/gcloud/` | ❌ None |
| Terraform state | Mac project dir | ❌ Not mounted separately |
| Git push capability | Mac SSH agent | ❌ Not forwarded |
| Docker daemon | Mac Docker socket | ❌ Not mounted |

### What a Compromised Container Can Access

| Resource | Access | Notes |
|----------|--------|-------|
| Source code | ✅ Read/write | Via bind mount (necessary for development) |
| Outbound HTTPS | ✅ | Needed for npm registry, Claude API |
| node_modules | ✅ | In volume, disposable |

### Additional Hardening (npm level)

- `ignore-scripts=true` — install scripts disabled by default (npm 12 allowScripts)
- `min-release-age=21` — refuse packages published less than 21 days ago
- `audit=true` — automatic vulnerability checks on install

### Accepted Risks

- Source code is readable by a compromised process (necessary for development)
- Outbound network allows exfiltration of source (egress filtering is a future enhancement)
- Claude Code API key is inside the container (scoped, revocable)

## Quick Start

```bash
# 1. Verify prerequisites
./scripts/setup.sh

# 2. Open a project with .devcontainer/ in VS Code
# 3. Click "Reopen in Container" when prompted
# 4. Inside container:
npm install
npm test
```

## Repository Contents

```
.devcontainer/
├── Dockerfile              # Dev container image (Node 24, npm 12, terraform-ls)
├── devcontainer.json       # VS Code container config
└── docker-compose.yml      # Volume definitions

scripts/
├── setup.sh               # Verify Mac prerequisites
├── rebuild.sh             # Destroy and rebuild container
└── verify-isolation.sh    # Confirm credential isolation (run inside container)

docs/runbooks/
├── initial-setup.md       # First-time setup
├── daily-workflow.md      # Everyday usage
├── new-project-onboarding.md  # Adding the template to a new repo
├── compromise-response.md # What to do if compromised
├── terraform-workflow.md  # Terraform alongside container dev
└── troubleshooting.md     # Common issues
```

## Using the Template in Other Repos

This repository provides the canonical Dev Container configuration. To use it in another Node.js project:

**Simplest approach** — copy the `.devcontainer/` directory:

```bash
cp -r ~/projects/developer-environment/.devcontainer ~/projects/my-project/
```

**For ongoing sync** — symlink (single machine only):

```bash
cd ~/projects/my-project
ln -s ~/projects/developer-environment/.devcontainer .devcontainer
```

See [New Project Onboarding](docs/runbooks/new-project-onboarding.md) for all options.

## Runbooks

| Scenario | Runbook |
|----------|---------|
| First-time setup | [initial-setup.md](docs/runbooks/initial-setup.md) |
| Everyday development | [daily-workflow.md](docs/runbooks/daily-workflow.md) |
| Adding template to a new repo | [new-project-onboarding.md](docs/runbooks/new-project-onboarding.md) |
| Suspected compromise | [compromise-response.md](docs/runbooks/compromise-response.md) |
| Terraform operations | [terraform-workflow.md](docs/runbooks/terraform-workflow.md) |
| Something's broken | [troubleshooting.md](docs/runbooks/troubleshooting.md) |
