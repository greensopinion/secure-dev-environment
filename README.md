# Secure Development Environment

npm supply-chain attacks compromise developer workstations by executing malicious code during `npm install`. The pattern is consistent: a dependency runs a postinstall script that harvests credentials from the local filesystem and exfiltrates them. Recent examples:

- [ChainDrop worm](https://www.microsoft.com/en-us/security/blog/2026/08/04/chaindrop-supply-chain-compromise-anatomy-self-propagating-worm/) (August 2026) — a self-propagating worm infected 400+ packages including `keyv` and `flat-cache`, affecting packages with 2 billion monthly downloads. Microsoft advised rotating credentials for any developer workstation that ran `npm install` on an affected version.
- [Axios compromise](https://www.microsoft.com/en-us/security/blog/2026/04/01/mitigating-the-axios-npm-supply-chain-compromise/) (March 2026) — attackers hijacked a maintainer's npm account and published backdoored versions that installed a cross-platform RAT. The malicious versions were live for 3 hours before detection.
- [Red Hat npm scope poisoning](https://www.microsoft.com/en-us/security/blog/2026/06/02/preinstall-persistence-inside-red-hat-npm-miasma-credential-stealing-campaign/) (June 2026) — 32 packages under `@redhat-cloud-services` were modified to steal credentials from developer workstations and CI/CD runners.

This repository provides a Docker-based development environment that isolates Node.js execution from developer credentials. If a dependency is compromised, it can read source code and reach the internet — but it cannot access SSH keys, GCP credentials, Terraform state, or the Docker daemon. The container is disposable. Destroy it, rebuild from the config, and continue working.

## How It Works

The Mac runs VS Code and holds credentials. The container runs Node.js and holds nothing of value beyond source code.

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

Git push and pull run on the Mac where SSH keys live. Git add, commit, and other metadata-modifying operations also run on the Mac because `.git` is mounted read-only inside the container. Read-only Git commands like status, diff, and log work inside the container. Both sides see the same working tree through a bind mount.

## Security Model

The core principle: the machine that executes untrusted third-party JavaScript must not be the machine that holds valuable developer credentials.

### What's Protected

| Credential | Location | Container Access |
|-----------|----------|-----------------|
| SSH keys | Mac `~/.ssh/` | None — not mounted, agent not forwarded |
| GCP credentials | Mac `~/.config/gcloud/` | None — not mounted |
| Terraform state | Mac project dir | Not mounted separately |
| Git push capability | Mac SSH agent | Explicitly blocked via `SSH_AUTH_SOCK=""` |
| Git metadata (.git/) | In workspace | Read-only — cannot modify hooks, config, or refs |
| Container config (.devcontainer/) | In workspace | Read-only — cannot weaken future security |
| Docker daemon | Mac Docker socket | Not mounted |
| Git hooks execution | Mac `~/.git-hooks/` | Defense-in-depth alongside read-only .git |

### What a Compromised Container Can Access

| Resource | Notes |
|----------|-------|
| Source code | Read/write via bind mount. Necessary for development. Review `git diff` before pushing. |
| Outbound network | Unrestricted TCP/UDP to the public internet. Required for npm registry. Enables exfiltration of source code to arbitrary servers. |
| DNS | Can resolve arbitrary domains. |
| node_modules | In a disposable Docker volume. Destroy and recreate at any time. |

### What a Compromised Container Cannot Reach

| Resource | Mitigation |
|----------|-----------|
| Mac services via host.docker.internal | Overridden to 127.0.0.1 (points to container itself) |
| Cloud metadata (169.254.169.254) | Blocked by Docker Desktop |
| Host filesystem beyond /workspace | Not mounted |
| LAN / private network | Docker bridge is isolated from Mac's LAN |

### npm-Level Hardening

The container image sets three npm defaults that protect every project opened inside it, even if that project has no security configuration of its own:

- `ignore-scripts=true` — npm 12 disables install scripts by default. Each project opts in to specific packages via an `allowScripts` field in package.json, making the decision explicit and reviewable in pull requests.
- `min-release-age=21` — refuses any package version published less than 21 days ago. Most malicious packages are detected and removed within days of publication; this quarantine period lets the community catch them first.
- `audit=true` — runs `npm audit` on every install to surface known vulnerabilities.

### Accepted Risks

- **Source code exfiltration**: A compromised process can read all source code and send it anywhere over the network. Review `git diff` on the Mac before committing to detect modifications.
- **Unrestricted outbound network**: The container can make arbitrary TCP/UDP connections to the internet. Egress filtering (e.g., an allowlist proxy) would reduce this but is not implemented. This is a deliberate tradeoff — npm, curl, and other tools need general internet access.
- **DNS exfiltration**: Data can be exfiltrated via DNS queries. Mitigating this would require a restricted DNS resolver.
- **Working tree modification**: Container code can modify source files, Makefiles, scripts, and other working-tree content. The `.git` and `.devcontainer` directories are read-only, but other files the host may later execute (e.g., Terraform config, shell scripts) are writable. Review changes before running host-side tools against the working tree.

### Container Hardening

The container runs with reduced privileges:
- `no-new-privileges` — prevents privilege escalation via setuid binaries
- `cap_drop: ALL` with only CHOWN, SETUID, SETGID, DAC_OVERRIDE retained (minimum for Node.js development)
- `host.docker.internal` overridden to 127.0.0.1 — blocks access to Mac services
- Non-root user (`node`, UID 1000)

## Quick Start

```bash
# 1. Verify prerequisites (Docker Desktop, VS Code, Dev Containers extension)
./scripts/setup.sh

# 2. Open a project with .devcontainer/ in VS Code
# 3. Click "Reopen in Container" when prompted
# 4. Inside the container:
npm install
npm test
```

## Repository Contents

```
.devcontainer/
├── Dockerfile              # Dev image: Node 24, npm 12, terraform-ls
├── devcontainer.json       # VS Code container config, extensions, env
└── docker-compose.yml      # Volumes, Datastore emulator sidecar

scripts/
├── setup.sh               # Verify Mac prerequisites
├── rebuild.sh             # Destroy and rebuild container
└── verify-isolation.sh    # Confirm credential isolation (run inside container)

docs/
├── concept/
│   └── secure-remote-dev-environment.md   # Threat model and design thinking
└── runbooks/
    ├── initial-setup.md               # First-time setup
    ├── daily-workflow.md              # Everyday usage
    ├── new-project-onboarding.md      # Adding the template to a new repo
    ├── compromise-response.md         # What to do if compromised
    ├── terraform-workflow.md          # Terraform alongside container dev
    └── troubleshooting.md             # Common issues

openspec/                              # Design decisions, specs, and rationale
```

## Using the Template in Other Repos

This repository provides the canonical Dev Container configuration. To use it in another Node.js project, copy the `.devcontainer/` directory:

```bash
cp -r path/to/developer-environment/.devcontainer path/to/my-project/
```

For ongoing sync on a single machine, symlink instead:

```bash
cd path/to/my-project
ln -s path/to/developer-environment/.devcontainer .devcontainer
```

See [New Project Onboarding](docs/runbooks/new-project-onboarding.md) for all options including git submodules.

## Runbooks

| Scenario | Runbook |
|----------|---------|
| First-time setup | [initial-setup.md](docs/runbooks/initial-setup.md) |
| Everyday development | [daily-workflow.md](docs/runbooks/daily-workflow.md) |
| Adding template to a new repo | [new-project-onboarding.md](docs/runbooks/new-project-onboarding.md) |
| Suspected compromise | [compromise-response.md](docs/runbooks/compromise-response.md) |
| Terraform operations | [terraform-workflow.md](docs/runbooks/terraform-workflow.md) |
| Something's broken | [troubleshooting.md](docs/runbooks/troubleshooting.md) |

## Alternatives

- [LavaMoat](https://github.com/LavaMoat/LavaMoat) — runtime sandboxing of individual npm modules via SES compartments
- [Socket](https://socket.dev/) — detects malicious packages by analyzing behavior before installation
- [DevPod](https://github.com/loft-sh/devpod) — open-source dev environment management across any provider
- [Trail of Bits claude-code-devcontainer](https://github.com/trailofbits/claude-code-devcontainer) — filesystem isolation for AI coding agents
- [npm 12 allowScripts](https://docs.npmjs.com/cli/v12/commands/npm-approve-scripts) — built-in install script allow-listing (used in this project)

## Design

The [threat model](docs/concept/secure-remote-dev-environment.md) explains the reasoning behind this architecture in detail: what attacks it mitigates, what attack paths remain, and why specific tradeoffs were made. The [openspec/](openspec/) directory contains the structured design process — proposal, capability specs, technical design, and implementation tasks — that produced this repository.

## Disclaimer

I am not a security professional. This project represents a best-effort approach to reducing npm supply-chain attack surface based on publicly available information. It has not been audited. Review the [threat model](docs/concept/secure-remote-dev-environment.md) and accepted risks before relying on it.

## License

[MIT](LICENSE)
