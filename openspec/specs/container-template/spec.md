# container-template Specification

## Purpose
TBD - created by archiving change secure-dev-container. Update Purpose after archive.
## Requirements
### Requirement: Shared Dockerfile defines the Node.js development image
The system SHALL provide a Dockerfile that builds a development image with a pinned Node.js version, npm, git, and terraform-ls (language server only, no terraform binary).

#### Scenario: Image builds successfully with pinned Node version
- **WHEN** a developer builds the Dockerfile
- **THEN** the resulting image contains the exact Node.js version specified in the Dockerfile (not a floating tag like `node:lts`)

#### Scenario: Image includes git for local operations
- **WHEN** a developer opens a terminal inside the container
- **THEN** git is available and can perform local operations (add, commit, stash, diff, log)

#### Scenario: Image includes terraform-ls for syntax support
- **WHEN** a developer opens a .tf file in VS Code inside the container
- **THEN** the Terraform language server provides syntax highlighting, formatting, and basic validation without requiring cloud credentials or the terraform binary

---

### Requirement: npm is configured with supply-chain protections
The system SHALL configure npm inside the container with `ignore-scripts=true`, `min-release-age=21`, and `audit=true` at the image level (`~/.npmrc`), so that any project opened in the container inherits these protections regardless of its own configuration.

#### Scenario: Recently published package is refused
- **WHEN** a developer runs npm install and a dependency version was published less than 21 days ago
- **THEN** npm refuses to install that version

#### Scenario: Audit runs automatically on install
- **WHEN** a developer runs npm install
- **THEN** npm audit runs and reports any known vulnerabilities

#### Scenario: Install scripts are disabled by default
- **WHEN** a developer runs npm install in a project with no `allowScripts` in package.json
- **THEN** no lifecycle scripts (preinstall, install, postinstall) execute for any dependency

#### Scenario: Project can opt in to specific install scripts
- **WHEN** a project has an `allowScripts` section in package.json listing specific packages
- **THEN** only those listed packages have their install scripts executed

#### Scenario: Repo without hardening config still gets protection
- **WHEN** a project repository has no `.npmrc` file of its own
- **THEN** the image-level `.npmrc` settings still apply (scripts off, audit on, min-release-age enforced)

---

### Requirement: devcontainer.json declares the container configuration
The system SHALL provide a devcontainer.json that configures VS Code's Dev Containers extension with the correct volume mounts, extensions, and settings.

#### Scenario: Source code is bind-mounted from the Mac
- **WHEN** VS Code opens the project in a Dev Container
- **THEN** the project source code from the Mac filesystem is available at /workspace inside the container

#### Scenario: node_modules uses a Docker volume
- **WHEN** npm install runs inside the container
- **THEN** node_modules is written to a named Docker volume mounted at /workspace/node_modules, not to the Mac filesystem

#### Scenario: Only approved extensions are installed in the container
- **WHEN** VS Code opens the project in a Dev Container
- **THEN** exactly these extensions are installed container-side: Jest, YAML, Claude Code, HashiCorp Terraform, and no others

---

### Requirement: devcontainer.json configures git identity
The system SHALL configure git user.name and user.email inside the container so that commits can be created without interactive prompts.

#### Scenario: Git commit works inside the container
- **WHEN** a developer runs git commit inside the container
- **THEN** the commit is created with the configured user.name and user.email without prompting for identity

---

### Requirement: Template is reusable across Node.js projects
The system SHALL provide the Dev Container configuration as a shared template in the developer-environment repository that can be referenced by multiple Node.js project repositories.

#### Scenario: A new Node.js project uses the template
- **WHEN** a developer sets up a new Node.js project for containerized development
- **THEN** they can use the shared template from developer-environment without duplicating the Dockerfile or devcontainer.json

#### Scenario: Template updates propagate to projects
- **WHEN** the shared template is updated (e.g., Node version bump)
- **THEN** projects referencing the template receive the update on next container rebuild

