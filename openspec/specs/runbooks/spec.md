# runbooks Specification

## Purpose
TBD - created by archiving change secure-dev-container. Update Purpose after archive.
## Requirements
### Requirement: Initial setup runbook exists
The system SHALL provide a runbook documenting how to set up the secure development environment from scratch on a new Mac.

#### Scenario: New developer follows setup runbook
- **WHEN** a developer follows the initial setup runbook
- **THEN** they have Docker Desktop installed, the Dev Container template available, and can open a project in the containerized environment

---

### Requirement: Daily workflow runbook exists
The system SHALL provide a runbook documenting the daily development workflow: opening projects, editing, testing, committing, and pushing.

#### Scenario: Developer follows daily workflow
- **WHEN** a developer follows the daily workflow runbook
- **THEN** they can open a project in a container, edit code, run tests, commit changes, and push from the Mac terminal

---

### Requirement: New project onboarding runbook exists
The system SHALL provide a runbook documenting how to configure a new Node.js project repository to use the shared Dev Container template.

#### Scenario: Developer onboards a new repo
- **WHEN** a developer follows the new project onboarding runbook for an existing Node.js repo
- **THEN** the repo is configured to use the shared Dev Container template and can be opened in the containerized environment

---

### Requirement: Compromise response runbook exists
The system SHALL provide a runbook documenting what to do if a supply-chain compromise is suspected: how to destroy the environment, verify Mac safety, and rebuild.

#### Scenario: Developer responds to suspected compromise
- **WHEN** a developer suspects a malicious dependency has executed
- **THEN** they follow the compromise response runbook to destroy the container and volumes, verify no credentials were exposed, and rebuild cleanly

---

### Requirement: Terraform workflow runbook exists
The system SHALL provide a runbook documenting how to perform Terraform operations alongside the containerized Node.js development workflow.

#### Scenario: Developer runs terraform plan
- **WHEN** a developer needs to run terraform plan for infrastructure in the same monorepo
- **THEN** they follow the Terraform runbook to execute from the Mac terminal with appropriate credentials

---

### Requirement: Troubleshooting runbook exists
The system SHALL provide a runbook documenting common issues and their resolutions: container won't start, volume issues, extension problems, performance problems, git conflicts between Mac and container.

#### Scenario: Developer resolves a common issue
- **WHEN** a developer encounters a known issue (e.g., container won't rebuild, node_modules volume corrupted)
- **THEN** they find the issue in the troubleshooting runbook and follow the resolution steps

