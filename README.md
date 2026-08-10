# Secure Development Environment

npm supply-chain attacks compromise developer workstations by executing malicious code during `npm install`. The pattern is consistent: a dependency runs a postinstall script that harvests credentials from the local filesystem and exfiltrates them. Recent examples:

- [ChainDrop worm](https://www.microsoft.com/en-us/security/blog/2026/08/04/chaindrop-supply-chain-compromise-anatomy-self-propagating-worm/) (August 2026) — a self-propagating worm infected 400+ packages including `keyv` and `flat-cache`, affecting packages with 2 billion monthly downloads. Microsoft advised rotating credentials for any developer workstation that ran `npm install` on an affected version.
- [Axios compromise](https://www.microsoft.com/en-us/security/blog/2026/04/01/mitigating-the-axios-npm-supply-chain-compromise/) (March 2026) — attackers hijacked a maintainer's npm account and published backdoored versions that installed a cross-platform RAT. The malicious versions were live for 3 hours before detection.
- [Red Hat npm scope poisoning](https://www.microsoft.com/en-us/security/blog/2026/06/02/preinstall-persistence-inside-red-hat-npm-miasma-credential-stealing-campaign/) (June 2026) — 32 packages under `@redhat-cloud-services` were modified to steal credentials from developer workstations and CI/CD runners.

This repository provides a Docker-based development environment that isolates Node.js execution from developer credentials. If a dependency is compromised, it can read source code and reach the internet — but it cannot access SSH keys, cloud credentials, or the Docker daemon. The container is disposable. Destroy it, rebuild from the config, and continue working.

A dedicated remote VM or GitHub Codespace provides stronger isolation than a local Docker container. This project makes a different tradeoff: keep development local with a normal VS Code + Docker workflow, while keeping npm and other project code away from host credentials, trusted Git metadata, and other high-value resources.

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
| Cloud metadata (169.254.169.254) | Not expected to be reachable in Docker Desktop; not relied upon as a security boundary |

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

npm hardening protects normal installs and prevents project configuration from silently weakening policy. A developer can still explicitly override npm policy with command-line flags; container isolation remains the final security boundary.

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

This project targets developers who want a local VS Code + Docker workflow while isolating Node.js/npm execution from credentials on the host. Depending on your threat model, one of these approaches may fit better.

[GitHub Codespaces](https://github.com/features/codespaces) and remote development VMs provide a stronger isolation boundary by moving the development environment off your workstation entirely. If you are comfortable developing remotely, this is preferable from an isolation perspective. The tradeoffs are reliance on remote infrastructure, connectivity, cost, and having source hosted remotely.

[VS Code Dev Containers](https://code.visualstudio.com/docs/devcontainers/containers) are the foundation this project builds on rather than replaces. A standard Dev Container provides environment isolation, but its security depends on what is mounted or forwarded into it. This repository adds an opinionated configuration intended specifically for running potentially malicious npm code: no host credentials or Docker socket, read-only Git and container metadata, npm supply-chain policies, and automated isolation checks.

[DevPod](https://github.com/loft-sh/devpod) runs dev-container-based environments locally, on remote machines, or in cloud infrastructure. It is a good option for portable or remote development environments without being tied to GitHub Codespaces. The security properties depend on the provider and how the workspace is configured.

A disposable VM running the entire development environment gives a cleaner isolation boundary than a local Docker container and may be preferable for higher-risk work. The tradeoff is additional resource usage and workflow complexity.

[LavaMoat](https://github.com/LavaMoat/LavaMoat) takes a different approach by sandboxing JavaScript modules at runtime, restricting what individual dependencies can access. This complements container isolation rather than replacing it.

[Socket](https://socket.dev/) analyzes packages for suspicious or malicious behavior before installation. Detection reduces the chance of installing compromised dependencies, while this project assumes detection may fail and focuses on limiting what malicious code can reach.

[npm 12 allowScripts](https://docs.npmjs.com/cli/v12/commands/npm-approve-scripts) provides built-in control over dependency lifecycle scripts and is used as one of the defense-in-depth layers in this project. npm policy reduces exposure, but the container remains the security boundary if malicious JavaScript executes through another path.

This project does not claim to provide stronger isolation than a properly configured remote VM. The goal is a different tradeoff: keep development local and familiar while reducing the credentials and trusted host state exposed to npm and other project code.

## Design

The [threat model](docs/concept/secure-remote-dev-environment.md) explains the reasoning behind this architecture: what attacks it mitigates, what attack paths remain, and why specific tradeoffs were made. The [openspec/](openspec/) directory contains the structured design process that produced this repository.

## Disclaimer

I am not a security professional. This project represents a best-effort approach to reducing npm supply-chain attack surface based on publicly available information. It has not been audited. Review the [threat model](docs/concept/secure-remote-dev-environment.md) and accepted risks before relying on it.

## License

[MIT](LICENSE)
