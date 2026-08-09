# Secure Remote Development Environment for Node.js/npm Projects

## Objective

I want to redesign my development environment to reduce the impact of **npm/Node.js supply-chain attacks**.

The specific concern is that malicious npm dependencies can execute arbitrary code during operations such as:

- `npm install`
- `npm test`
- `npm run build`
- application execution
- other npm lifecycle scripts

A compromised dependency running on my developer laptop could potentially access valuable credentials and other sensitive information available to that machine.

The goal is therefore:

> **Run Node.js, npm, `node_modules`, tests, builds, and application code outside the credential-rich developer laptop, while retaining a normal VS Code development experience.**

The developer machine should ideally become a trusted UI/administration device rather than the environment in which untrusted third-party JavaScript executes.

---

# Current Environment

The primary development machine is a Mac.

The application is a Node.js/npm web service, with a typical workflow involving:

```text
npm install
npm test
npm run build
npm run ...
node ...
```

I use VS Code as my primary IDE.

I also sometimes need to perform infrastructure administration from the development machine, including:

```text
terraform plan
terraform apply
gcloud ...
```

The development machine therefore legitimately contains credentials that I do **not** want arbitrary npm dependencies to access.

These may include:

- Git SSH credentials
- Google Cloud authentication
- Terraform-related credentials
- other development/infrastructure credentials

I want to preserve the ability to perform these administrative operations locally.

---

# Threat Model

Assume that an npm dependency can become malicious.

For example:

```text
npm install
    ↓
malicious dependency executes
    ↓
arbitrary code runs with the privileges of the developer environment
```

The malicious package should be considered potentially hostile.

It may attempt to access:

- environment variables
- SSH keys
- SSH agents
- Git credentials
- GCP credentials
- Terraform credentials
- files in the developer's home directory
- VS Code configuration
- other developer tools
- source code
- browser/application credentials
- configuration files
- cloud credentials
- CI/CD credentials

The goal is **not necessarily to prevent the malicious code from compromising the development environment**.

Instead, the goal is to ensure that:

> **A compromised Node/npm environment has very little access to the developer's valuable credentials.**

Ideally, if the development environment becomes compromised, it can simply be destroyed and recreated.

---

# Proposed Architecture

The initial concept is:

```text
                         TRUSTED
                            │
                            ▼
                 ┌──────────────────────┐
                 │       Mac            │
                 │                      │
                 │ VS Code              │
                 │ Terraform            │
                 │ gcloud               │
                 │ Git                  │
                 │ SSH credentials      │
                 │ GCP credentials      │
                 │                      │
                 │ NO Node.js           │
                 │ NO npm               │
                 │ NO node_modules      │
                 └──────────┬───────────┘
                            │
                       SSH / Remote
                            │
                            ▼
                 ┌──────────────────────┐
                 │    Linux Dev VM      │
                 │                      │
                 │ VS Code Server       │
                 │ Node.js              │
                 │ npm                  │
                 │ Git                  │
                 │ node_modules         │
                 │ tests                │
                 │ builds               │
                 │ application          │
                 │                      │
                 │ MINIMAL CREDENTIALS  │
                 └──────────────────────┘
                            │
                            ▼
                    npm / Git / etc.
```

VS Code would remain running on the Mac, but the actual development environment would run remotely.

The preferred workflow is:

```text
VS Code on Mac
      ↓
Remote SSH
      ↓
Linux development environment
      ↓
Node/npm/tests/builds
```

The source repository should ideally live on the Linux environment rather than being mounted from the Mac.

This is intentional.

I do **not** want to simply mount the Mac's home directory into Linux, because that could allow malicious code to access the Mac's credentials.

---

# Why Remote Execution Is Important

A local setup looks like:

```text
Mac
├── VS Code
├── Node
├── npm
├── node_modules
├── ~/.ssh
├── GCP credentials
├── Terraform credentials
└── source code
```

A malicious npm package therefore potentially has access to all of these.

The proposed setup is:

```text
Mac
├── VS Code
├── ~/.ssh
├── GCP credentials
├── Terraform credentials
└── gcloud / Terraform

Linux VM
├── Node
├── npm
├── node_modules
├── source
└── tests/builds
```

The important security boundary is:

> The environment that executes arbitrary third-party JavaScript should not contain valuable developer credentials.

---

# Git Authentication

One complication is Git.

I normally want to be able to do:

```bash
git push
```

from the remote development environment.

One possible approach is SSH agent forwarding:

```text
Mac
│
├── private SSH key
└── ssh-agent
       │
       │ agent forwarding
       ▼
Linux VM
       │
       │ git push
       ▼
GitHub/GitLab
```

The private key itself does not get copied to the VM.

However, agent forwarding has an important security limitation:

> A compromised process on the remote VM may be able to use the forwarded SSH agent to authenticate as the developer, even though it cannot extract the private key.

Therefore this needs to be evaluated carefully.

An alternative is to create a dedicated SSH key specifically for the remote development VM:

```text
Mac
└── personal SSH keys

Linux VM
└── dedicated development Git key
```

The dedicated key could have restricted access and could be revoked independently if the VM is compromised.

The security and usability trade-offs between these approaches should be investigated.

---

# GCP / Terraform Authentication

I sometimes need to run Terraform and GCP commands from my development machine.

I do **not** want to move all of these operations into the remote Node/npm environment simply for consistency.

The preferred model may therefore be:

```text
Mac
├── Terraform
├── gcloud
├── GCP authentication
└── infrastructure administration

Linux VM
├── Node
├── npm
├── tests
├── builds
└── application execution
```

This means the Mac remains a trusted infrastructure-administration environment.

The critical rule is:

> Do not expose the Mac's GCP credentials or Terraform credentials to the Node/npm environment.

A further improvement would be to use short-lived credentials and appropriately scoped IAM permissions rather than long-lived high-privilege credentials.

Production credentials ideally should not be present on either development environment and production infrastructure changes should preferably happen through CI/CD or another controlled administrative environment.

---

# VS Code Experience

A major requirement is that this should not feel like abandoning normal local development.

The desired workflow is:

1. Launch VS Code on the Mac.
2. Open/connect to the remote Linux development environment.
3. Edit code normally.
4. Use the integrated terminal normally.
5. Run tests normally.
6. Debug normally.
7. Run npm scripts normally.
8. Commit and push normally.

The user should not need to constantly think about which machine is actually executing the code.

VS Code Remote-SSH and/or Dev Containers may provide this experience.

---

# Dev Containers

An additional layer could be used:

```text
Mac
 │
 │ VS Code Remote SSH
 ▼
Linux VM
 │
 │ Docker
 ▼
Dev Container
 │
 ├── Node
 ├── npm
 ├── source
 ├── node_modules
 ├── tests
 └── build tools
```

The development environment could be described by files such as:

```text
.devcontainer/
    devcontainer.json
    Dockerfile
```

This provides a reproducible environment and makes it easier to destroy/recreate the environment.

However, Docker should not automatically be assumed to be the primary security boundary.

The stronger security boundary is:

> The Node/npm execution environment is on a separate machine from the credential-rich developer workstation.

---

# Disposable Development Environment

A desirable property is that the Linux environment can be treated as disposable.

If a suspicious npm package is detected:

```text
Compromised VM
      ↓
Destroy VM
      ↓
Create clean VM
      ↓
Clone repository
      ↓
Recreate development environment
```

Ideally the environment can be rebuilt automatically.

Possible tools/approaches include:

- shell provisioning scripts
- Terraform
- Ansible
- Dev Containers
- DevPod
- Nix
- cloud-init
- custom VM images

---

# DevPod

One project worth investigating is DevPod.

DevPod provides tooling for creating and managing reproducible development environments, potentially on remote machines/providers.

It may provide substantial convenience around:

- provisioning
- reproducibility
- dev containers
- multiple environments
- disposable workspaces
- VS Code integration

However, it is important to distinguish:

> Development-environment management

from:

> Credential isolation/security.

DevPod does not automatically solve credential isolation.

If credentials are mounted or forwarded into the environment, a malicious npm package may still be able to use them.

The question is therefore whether DevPod provides enough value over a simple:

```text
VS Code Remote-SSH
+
Linux VM
+
Dev Container
```

to justify its additional complexity.

---

# Home-Rolled vs DevPod

A simple home-rolled architecture might be:

```text
Mac
  │
  │ VS Code Remote-SSH
  ▼
Linux VM
  │
  ├── Node
  ├── npm
  ├── Git
  ├── Docker
  └── project
```

This is attractive because it is conceptually simple.

DevPod may become useful if there are many projects or environments:

```text
devpod up project-a
devpod up project-b
devpod up project-c
```

with each environment being reproducible and disposable.

The question to investigate is:

> How much practical value does DevPod add over a simple dedicated Linux VM + Remote-SSH + Dev Container setup for a single developer?

---

# Security Questions to Investigate

A detailed evaluation should specifically investigate the following.

## 1. VS Code Remote-SSH

Determine exactly what is executed locally versus remotely.

Investigate:

- VS Code extensions
- extension host
- integrated terminal
- debugging
- language servers
- Git integration
- credential helpers
- environment variables
- port forwarding
- filesystem access

Could a malicious npm process running remotely access anything on the Mac through VS Code?

---

## 2. SSH Agent Forwarding

Determine:

- What can a compromised remote process do with a forwarded agent?
- Can it sign arbitrary authentication requests?
- Can it enumerate available keys?
- Can it extract the private key?
- Is agent forwarding appropriate for this threat model?

Compare this with:

- dedicated remote Git SSH key
- GitHub/GitLab deploy keys
- fine-grained access tokens
- short-lived credentials

---

## 3. Filesystem Mounts

Determine whether the Mac should expose:

```text
~/projects
```

or whether repositories should live entirely on the Linux VM.

The preferred security model is probably:

```text
Mac filesystem
       X
       │
       │ no general mount
       │
       ▼
Linux VM filesystem
```

Investigate whether any VS Code functionality implicitly mounts or exposes local files.

---

## 4. Credential Forwarding

Identify every mechanism by which credentials could accidentally cross the boundary:

- SSH agent
- GCP credentials
- environment variables
- Git credential helpers
- VS Code authentication
- Docker credentials
- npm credentials
- cloud CLI credentials
- browser integration
- secret managers

---

## 5. Git Credentials

Compare:

### Option A

SSH agent forwarding.

### Option B

Dedicated SSH key on remote VM.

### Option C

Git credential/token mechanism.

### Option D

Some other mechanism that provides authentication without exposing a long-lived developer credential.

Evaluate both usability and compromise impact.

---

## 6. GCP / Terraform

Determine whether it is safe to keep:

```text
gcloud
terraform
GCP credentials
```

on the Mac while Node/npm is completely absent.

Investigate whether Terraform or gcloud can accidentally execute arbitrary project code or npm scripts.

Also investigate whether infrastructure tooling should eventually move into a separate administrative environment.

---

## 7. Remote VM Security

Assume the Linux VM itself becomes compromised.

Determine what the attacker could access:

- source code
- Git credentials
- SSH agent
- cloud APIs
- network services
- other developer environments
- VM metadata services
- Docker daemon
- host filesystem
- other users

The VM should ideally have:

- minimal privileges
- no production credentials
- no unnecessary network access
- no access to the Mac filesystem
- no personal SSH keys
- no long-lived cloud credentials

---

## 8. VM vs Container Security

Evaluate whether:

```text
Mac → Linux VM → Node
```

is sufficient, or whether:

```text
Mac → Linux VM → Docker → Node
```

provides meaningful additional security.

Do not assume containers are an absolute security boundary.

The main security benefit comes from moving the execution environment away from the Mac.

---

# Desired End State

The ideal architecture is:

```text
                           TRUSTED
                              │
                              ▼
                 ┌──────────────────────────┐
                 │          Mac             │
                 │                          │
                 │ VS Code                  │
                 │ Git/admin tools          │
                 │ Terraform                │
                 │ gcloud                   │
                 │ GCP credentials          │
                 │ SSH credentials          │
                 │                          │
                 │ NO Node                   │
                 │ NO npm                    │
                 │ NO node_modules           │
                 └────────────┬─────────────┘
                              │
                         controlled
                         SSH connection
                              │
                              ▼
                 ┌──────────────────────────┐
                 │      Linux Dev VM        │
                 │                          │
                 │ VS Code Server           │
                 │ Docker / Dev Container   │
                 │ Node.js                  │
                 │ npm                      │
                 │ node_modules              │
                 │ source code               │
                 │ tests/builds              │
                 │                          │
                 │ MINIMAL CREDENTIALS      │
                 └──────────────────────────┘
                              │
                              ▼
                         Internet /
                         package registry
```

The security principle is:

> **The machine that executes arbitrary third-party JavaScript should not be the machine that holds valuable developer credentials.**

---

# Questions for Further Research

Please investigate this architecture critically rather than simply validating it.

Specifically:

1. Is this actually an effective mitigation against modern npm supply-chain attacks?
2. What attack paths remain from a compromised npm package running inside the remote VM?
3. What mechanisms in VS Code Remote-SSH could undermine the isolation?
4. How dangerous is SSH agent forwarding in this threat model?
5. Is a dedicated Git SSH key preferable?
6. Can GCP/Terraform safely remain on the Mac?
7. What credentials should never cross the Mac → VM boundary?
8. What filesystem mounts, if any, are safe?
9. Is DevPod materially better than a home-rolled Remote-SSH + VM solution?
10. Would Dev Containers add meaningful security or primarily reproducibility?
11. Would an ephemeral VM materially improve the security posture?
12. Are there existing open-source projects specifically designed around **secure/untrusted developer code execution with credential isolation**?
13. Are there better architectures than a remote VM?
14. What would the recommended architecture be for a single developer versus a team?
15. What specific configuration would you recommend for a Mac + Linux VM + VS Code + GitHub/GitLab + GCP + Terraform + Node/npm?

The final recommendation should prioritize **security boundaries and credential isolation** over convenience, while preserving a near-native VS Code development experience.