## Context

The developer works on multiple Node.js monorepos on a Mac that also holds SSH keys, GCP credentials, and Terraform state. npm supply-chain attacks mean any `npm install` could execute hostile code with access to those credentials. The goal is to isolate Node.js execution inside a local Docker container while preserving a near-native VS Code editing experience.

The developer-environment repository serves as the single source of truth for all container configuration, automation scripts, and operational runbooks.

Current state: No containerization. Node.js runs directly on the Mac alongside all credentials.

## Goals / Non-Goals

**Goals:**
- Isolate Node.js/npm execution from Mac credentials (SSH, GCP, Terraform)
- Preserve seamless VS Code editing, testing, and debugging experience
- Support multiple Node.js monorepos with a shared container template
- Make the development environment disposable and rebuildable
- Document all workflows as runbooks in this repository
- Keep git push/pull on the Mac (credentials never enter the container)

**Non-Goals:**
- Protecting against Dart/Flutter supply-chain attacks (future phase)
- Docker-in-Docker or local Docker image builds (deferred)
- DevPod or multi-provider orchestration
- Mitigating Terraform provider supply-chain risk
- Network-level isolation (egress filtering) — container needs outbound HTTPS for npm and Claude API
- Protecting against a compromised VS Code extension (trusted Mac-side code)

## Decisions

### 1. Docker Desktop as the container runtime

**Choice**: Run dev containers locally via Docker Desktop on macOS.

**Alternatives considered**:
- Cloud VM (GCE/EC2): Better network isolation, but adds latency and cost. Overkill for npm supply-chain threat model.
- Local VM (UTM/Parallels): Stronger hypervisor boundary, but more complex setup and resource management. Docker is simpler for dev containers.
- Podman: Compatible but less VS Code extension support on macOS currently.

**Rationale**: Docker Desktop is the standard Dev Containers runtime, has excellent VS Code integration, and provides sufficient process/filesystem isolation for this threat model. The security boundary is "no credentials inside the container" rather than "container escape is impossible."

### 2. Bind mount for source, Docker volume for node_modules

**Choice**: 
```
~/projects/repo → /workspace         (bind mount)
node_modules_vol → /workspace/node_modules  (named volume)
```

**Alternatives considered**:
- Full Docker volume for everything: Better isolation and I/O, but source doesn't survive volume deletion and git operations from Mac are awkward.
- Bind mount for everything including node_modules: Severe I/O performance issues on macOS (thousands of small files), and exposes untrusted node_modules to Mac filesystem.

**Rationale**: Hybrid approach gives us: source on Mac (git operations work, survives container destruction), node_modules in volume (fast I/O, not on Mac filesystem, disposable). The bind mount is scoped to only the project directory — never `~/` or parent directories.

### 3. Git split: credentials on Mac, local ops in container

**Choice**: git push/pull/fetch/clone from Mac terminal only. git add/commit/stash/diff/log from either.

**Alternatives considered**:
- SSH agent forwarding into container: Allows push from container but exposes SSH identity to compromised processes.
- Fine-grained PAT in container: Scoped and revocable, but still places a credential inside the blast radius.
- Git credential helper bridging: Complex, and still puts auth capability inside the container.

**Rationale**: By never placing any git credential inside the container, we eliminate the entire class of "compromised process pushes malicious code" attacks. The UX trade-off (push from a Mac terminal) is acceptable given the developer already uses a Mac terminal for terraform/gcloud.

### 4. Minimal extension set, container-side execution

**Choice**: Container-side extensions: Jest, YAML, Claude Code, HashiCorp Terraform (language server only). Mac-side: Dev Containers extension, theme.

**Alternatives considered**:
- More extensions: Each extension running in the container is more attack surface and more potential credential leakage.
- Fewer extensions: Could drop Terraform language server, but syntax support while editing .tf files is valuable.

**Rationale**: Each container-side extension has access to the container filesystem and can execute commands. Minimizing the set reduces attack surface. Claude Code needs command execution (for running tests, reading code) — acceptable because it's bounded by the same container isolation. Terraform extension provides language server without needing the terraform binary or cloud credentials.

### 5. Shared template in developer-environment repo

**Choice**: Store the canonical `.devcontainer/` configuration (Dockerfile, devcontainer.json) in this repository. Individual project repos reference it.

**Mechanism**: Projects use a local `.devcontainer/devcontainer.json` that points to the shared Dockerfile via a relative path or build context, OR projects symlink/copy from this repo. The exact mechanism will be determined during implementation — options include:
- Git submodule
- Symlink from project to this repo
- Script that copies template into project
- VS Code workspace-level devcontainer config

**Rationale**: Centralizes updates (Node version bumps, extension changes, security hardening). Avoids drift across multiple repos.

### 6. Repository structure

```
developer-environment/
├── .devcontainer/
│   ├── Dockerfile              # Shared dev image
│   ├── devcontainer.json       # Shared container config
│   └── docker-compose.yml      # Volume definitions
├── scripts/
│   ├── rebuild.sh              # Destroy and rebuild environment
│   └── setup.sh               # Initial Mac setup verification
├── docs/
│   ├── secure-remote-dev-environment.md  # (existing design doc)
│   ├── runbooks/
│   │   ├── initial-setup.md
│   │   ├── daily-workflow.md
│   │   ├── new-project-onboarding.md
│   │   ├── compromise-response.md
│   │   ├── terraform-workflow.md
│   │   └── troubleshooting.md
├── openspec/                   # (existing)
└── README.md
```

### 7. Git identity in container

**Choice**: Configure git user.name and user.email via devcontainer.json postCreateCommand or environment variables. No credential helper configured.

**Rationale**: Commits need an author identity but no secrets. Setting `credential.helper` to empty string ensures git never prompts for or caches credentials inside the container.

## Risks / Trade-offs

- **[Source code exposure]** → A compromised process can read/modify source via the bind mount. Mitigation: review `git diff` before pushing from Mac. This is accepted — you need the code to develop.
- **[Network exfiltration]** → A compromised process has outbound HTTPS (needed for npm install and Claude API). It could exfiltrate source code. Mitigation: accept this risk for now; egress filtering is a future enhancement.
- **[Claude Code API key]** → Claude Code extension needs an API key/auth token inside the container to reach the Claude API. This credential IS inside the blast radius. Mitigation: use a scoped API key that only grants Claude API access, not other services. Revoke/rotate if container is compromised.
- **[Stale node_modules]** → Volume survives container rebuilds unless explicitly removed. Could mask issues. Mitigation: rebuild script includes volume removal option.
- **[macOS Docker I/O]** → Bind mount performance on macOS is mediocre for large file trees. Mitigation: node_modules in volume (the main I/O bottleneck). Source file operations (read/write individual files) are fast enough.
- **[Template distribution]** → No settled mechanism for how projects consume the shared template. Mitigation: start with manual copy + runbook; iterate on automation once the pattern is proven.

## Open Questions

1. ~~What specific Node.js version to pin?~~ → **Node 24** (LTS "Krypton", matches production, supported through April 2028)
2. Exact mechanism for projects to consume the shared template (submodule vs copy vs symlink)?
3. Should the container have a non-root user for additional defense-in-depth?
4. Does Claude Code's authentication use an API key env var, or VS Code's built-in auth? This determines what credential enters the container.
5. Should we add a postCreateCommand that runs npm install automatically on container creation?
