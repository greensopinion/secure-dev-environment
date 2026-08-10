# Secure Development Environment

npm supply-chain attacks compromise developer workstations by executing malicious code during `npm install`. The pattern is consistent: a dependency runs a postinstall script that harvests credentials from the local filesystem and exfiltrates them. Recent examples:

- [ChainDrop worm](https://www.microsoft.com/en-us/security/blog/2026/08/04/chaindrop-supply-chain-compromise-anatomy-self-propagating-worm/) (August 2026) — a self-propagating worm infected 400+ packages including `keyv` and `flat-cache`, affecting packages with 2 billion monthly downloads. Microsoft advised rotating credentials for any developer workstation that ran `npm install` on an affected version.
- [Axios compromise](https://www.microsoft.com/en-us/security/blog/2026/04/01/mitigating-the-axios-npm-supply-chain-compromise/) (March 2026) — attackers hijacked a maintainer's npm account and published backdoored versions that installed a cross-platform RAT. The malicious versions were live for 3 hours before detection.
- [Red Hat npm scope poisoning](https://www.microsoft.com/en-us/security/blog/2026/06/02/preinstall-persistence-inside-red-hat-npm-miasma-credential-stealing-campaign/) (June 2026) — 32 packages under `@redhat-cloud-services` were modified to steal credentials from developer workstations and CI/CD runners.

This repository provides a Docker-based development environment that isolates Node.js execution from developer credentials. If a dependency is compromised, it can read source code and reach the internet — but it cannot access SSH keys, cloud credentials, or the Docker daemon. The container is disposable. Destroy it, rebuild from the config, and continue working.

## How It Works

The Mac runs VS Code and holds credentials. The container runs Node.js and holds nothing of value beyond source code.

```
┌──────────────────────────────────────────────────────────────────────┐
│  Mac (trusted)                                                       │
│  ┌────────────────────────────────────────────────────────────────┐  │
│  │ VS Code (Dev Containers ext)                                   │  │
│  │ Git (all mutations + push/pull)                                │  │
│  │ Terraform / gcloud                                             │  │
│  │ SSH keys, GCP credentials                                      │  │
│  └───────────┬────────────────────────────────────────────────────┘  │
│              │ bind mount (project dir only, .git read-only)         │
│              ▼                                                       │
│  ┌────────────────────────────────────────────────────────────────┐  │
│  │ Docker Container                                               │  │
│  │ Node.js 24 + npm 12                                            │  │
│  │ Source code at /workspace (writable)                           │  │
│  │ .git (read-only), .devcontainer (read-only)                    │  │
│  │ node_modules in Docker volume                                  │  │
│  │ Git read-only (status, diff, log)                              │  │
│  │                                                                │  │
│  │ NO SSH keys · NO GCP creds · NO Docker socket                  │  │
│  └────────────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────────┘
```

## Security Model

The core principle: the machine that executes untrusted third-party JavaScript must not be the machine that holds valuable developer credentials.

### What's Protected

| Credential | Location | Container Access |
|-----------|----------|-----------------|
| SSH keys | Mac `~/.ssh/` | None — not mounted, agent not forwarded |
| GCP credentials | Mac `~/.config/gcloud/` | None — not mounted |
| AWS credentials | Mac `~/.aws/` | None — not mounted |
| Terraform credentials | Mac `~/.terraform.d/` | None — not mounted |
| Git push capability | Mac SSH agent | Explicitly blocked via `SSH_AUTH_SOCK=""` |
| Git metadata (.git/) | In workspace | Read-only — cannot modify hooks, config, or refs |
| Container config (.devcontainer/) | In workspace | Read-only — cannot weaken future security |
| Docker daemon | Mac Docker socket | Not mounted |
| Mac services | host.docker.internal | Overridden to 127.0.0.1 |
| Cloud metadata (169.254.169.254) | Blocked by Docker Desktop |

### What a Compromised Container Can Access

| Resource | Notes |
|----------|-------|
| Source code | Read/write via bind mount. Review `git diff` on Mac before committing. |
| Terraform state (if local) | `terraform.tfstate` in the project directory is readable via bind mount. Use remote state backends to avoid this. |
| Outbound network | Unrestricted TCP/UDP to the public internet. LAN and host services are potentially reachable; no egress firewall is applied. |
| node_modules | In a disposable Docker volume. |

### npm-Level Hardening

The container enforces npm security settings via environment variables, which have higher precedence than any `.npmrc` file. A hostile repository cannot override them.

- **Install scripts off by default** — npm 12 disables dependency install scripts unless the project explicitly lists them in `allowScripts` in package.json.
- `strict-allow-scripts=true` — `npm install` fails if any dependency has unreviewed install scripts, forcing explicit approval.
- `min-release-age=21` — refuses any package version published less than 21 days ago.
- `audit=true` — runs `npm audit` on every install.

### Accepted Risks

- **Source code exfiltration**: A compromised process can read source and send it anywhere over the network. Egress filtering is not implemented — npm and other tools need general internet access.
- **Working tree modification**: Container code can modify source files, Makefiles, scripts, and other working-tree content. `.git` and `.devcontainer` are read-only, but other files the host may later execute (e.g., Terraform config, shell scripts) remain writable. Review changes before running host-side tools.

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

The [threat model](docs/concept/secure-remote-dev-environment.md) explains the reasoning behind this architecture: what attacks it mitigates, what attack paths remain, and why specific tradeoffs were made. The [openspec/](openspec/) directory contains the structured design process that produced this repository.

## Disclaimer

I am not a security professional. This project represents a best-effort approach to reducing npm supply-chain attack surface based on publicly available information. It has not been audited. Review the [threat model](docs/concept/secure-remote-dev-environment.md) and accepted risks before relying on it.

## License

[MIT](LICENSE)
