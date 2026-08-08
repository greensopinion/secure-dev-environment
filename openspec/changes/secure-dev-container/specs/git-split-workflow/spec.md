## ADDED Requirements

### Requirement: Credential-requiring git operations run on Mac only
The system SHALL ensure that git push, git pull, git fetch, and git clone are performed from the Mac terminal where SSH keys are available, not from inside the container.

#### Scenario: git push from inside the container fails
- **WHEN** a developer runs git push inside the container
- **THEN** the command fails due to missing credentials (no SSH key, no token configured)

#### Scenario: git push from Mac terminal succeeds
- **WHEN** a developer runs git push from a Mac terminal in the project directory
- **THEN** the push succeeds using the Mac's SSH credentials

---

### Requirement: Local git operations work inside the container
The system SHALL allow git add, git reset, git stash, git commit, git diff, git log, git status, and other local git operations inside the container.

#### Scenario: git add and git commit work in container
- **WHEN** a developer edits a file and runs git add followed by git commit inside the container
- **THEN** the commit is created successfully and is visible from both Mac and container

#### Scenario: git stash works in container
- **WHEN** a developer runs git stash inside the container
- **THEN** the working tree changes are stashed and the stash is visible from both Mac and container

#### Scenario: Changes made in container are visible on Mac
- **WHEN** a developer creates a commit inside the container
- **THEN** the commit appears in git log when run from the Mac terminal (because they share the same .git directory via bind mount)

---

### Requirement: Git configuration prevents accidental credential exposure
The system SHALL configure git inside the container to not use credential helpers that could prompt for or cache credentials.

#### Scenario: No credential helper is configured
- **WHEN** a developer inspects git config inside the container
- **THEN** no credential.helper is set (or it is explicitly set to empty)

#### Scenario: Git does not prompt for passwords
- **WHEN** a git operation requiring auth is attempted inside the container
- **THEN** it fails immediately without interactive prompting
