# disposable-environment Specification

## Purpose
TBD - created by archiving change secure-dev-container. Update Purpose after archive.
## Requirements
### Requirement: Container can be destroyed and rebuilt without data loss
The system SHALL ensure that destroying and rebuilding the development container does not result in loss of source code or committed work, since source lives on the Mac via bind mount.

#### Scenario: Rebuild after suspected compromise
- **WHEN** a developer destroys the container and its node_modules volume, then rebuilds
- **THEN** source code is intact (on Mac), node_modules is reinstalled fresh, and the development environment is functional

#### Scenario: Uncommitted changes survive container rebuild
- **WHEN** a developer has uncommitted changes in the working tree and rebuilds the container
- **THEN** the uncommitted changes are still present (they live on the Mac filesystem)

---

### Requirement: node_modules volume can be independently destroyed
The system SHALL use a named Docker volume for node_modules that can be removed without affecting the container image or source code.

#### Scenario: Clean node_modules rebuild
- **WHEN** a developer removes the node_modules volume and restarts the container
- **THEN** npm install recreates node_modules from scratch in a fresh volume

---

### Requirement: Rebuild automation is scripted
The system SHALL provide a script or documented command sequence that tears down the container and volumes and rebuilds from the Dev Container configuration.

#### Scenario: One-command environment reset
- **WHEN** a developer runs the rebuild script
- **THEN** the old container and node_modules volume are removed, a new container is built from the Dockerfile, and the environment is ready for development

---

### Requirement: Container image is reproducible
The system SHALL ensure that rebuilding the container image from the same Dockerfile and devcontainer.json produces a functionally equivalent environment.

#### Scenario: Two developers get the same environment
- **WHEN** two developers build the container from the same .devcontainer/ configuration
- **THEN** both get the same Node version, same tools, same extensions installed

