## ADDED Requirements

### Requirement: No SSH keys are accessible inside the container
The system SHALL NOT mount, forward, or otherwise expose the Mac's SSH keys or SSH agent socket to the container.

#### Scenario: SSH agent socket is not available
- **WHEN** a process inside the container attempts to access SSH_AUTH_SOCK
- **THEN** the environment variable is unset and no socket file exists

#### Scenario: SSH private keys are not mounted
- **WHEN** a process inside the container lists files in ~/.ssh/ or /root/.ssh/
- **THEN** no private key files from the Mac are present

---

### Requirement: No GCP credentials are accessible inside the container
The system SHALL NOT mount or expose Google Cloud credentials, application default credentials, or gcloud configuration to the container.

#### Scenario: GCP application default credentials are absent
- **WHEN** a process inside the container checks for ~/.config/gcloud/ or GOOGLE_APPLICATION_CREDENTIALS
- **THEN** no credentials are found

#### Scenario: gcloud CLI is not available
- **WHEN** a process inside the container attempts to run gcloud
- **THEN** the command is not found

---

### Requirement: No Terraform credentials are accessible inside the container
The system SHALL NOT expose Terraform state, backend credentials, or cloud provider credentials to the container.

#### Scenario: Terraform credentials are absent
- **WHEN** a process inside the container checks for ~/.terraform.d/ or TF_TOKEN_* environment variables
- **THEN** no Terraform credentials are found

---

### Requirement: No Docker socket is exposed to the container
The system SHALL NOT mount /var/run/docker.sock or expose Docker daemon access to the development container.

#### Scenario: Docker socket is not mounted
- **WHEN** a process inside the container attempts to communicate with the Docker daemon
- **THEN** the connection fails (no socket, no TCP endpoint)

---

### Requirement: Container bind mount is scoped to the project directory only
The system SHALL mount only the specific project directory into the container, not the developer's home directory or any parent directory.

#### Scenario: Container cannot access Mac home directory
- **WHEN** a process inside the container attempts to traverse above /workspace
- **THEN** it cannot reach the Mac's home directory, ~/.ssh, ~/.config, or any other Mac-level files

---

### Requirement: No environment variables leak credentials into the container
The system SHALL NOT pass Mac-level credential environment variables (e.g., GOOGLE_APPLICATION_CREDENTIALS, AWS_*, TF_TOKEN_*, SSH_AUTH_SOCK) into the container.

#### Scenario: Credential environment variables are unset
- **WHEN** a process inside the container enumerates environment variables
- **THEN** none of the Mac's credential-bearing environment variables are present
