# Initial Setup

Set up the secure development environment on a new Mac.

## Prerequisites

- macOS (Apple Silicon or Intel)
- Administrator access (for installing software)

## Steps

### 1. Install Docker Desktop

Download and install from https://www.docker.com/products/docker-desktop/

After installation:
- Launch Docker Desktop
- Allocate at least 4 GB RAM and 2 CPUs (Settings → Resources)
- Enable "Use Virtualization framework" (Settings → General)

### 2. Install VS Code

Download from https://code.visualstudio.com/ or:

```bash
brew install --cask visual-studio-code
```

### 3. Install the Dev Containers Extension

```bash
code --install-extension ms-vscode-remote.remote-containers
```

### 4. Configure VS Code Settings

Open VS Code settings (Cmd+,) and set:

- `remote.autoForwardPorts`: **false** (prevents automatic port exposure)
- `git.useIntegratedAskPass`: **false** (prevents credential prompts inside containers)

### 5. Set Git Identity Environment Variables

Add to `~/.zshrc` (or `~/.bashrc`):

```bash
export GIT_USER_NAME="Your Full Name"
export GIT_USER_EMAIL="your.email@example.com"
```

Then reload:

```bash
source ~/.zshrc
```

These get passed into the container so that `git log` and other read-only commands display the correct author when inspecting commits made on the Mac.

### 6. Redirect Git Hooks to a Trusted Location (Defense-in-Depth)

`.git` is mounted read-only inside the container, so container code cannot modify hooks or config. As an additional safeguard, point Mac-side Git hooks to a directory outside the repository:

```bash
mkdir -p ~/.git-hooks
git config --global core.hooksPath ~/.git-hooks
```

This means Git on the Mac only runs hooks from `~/.git-hooks/`, not from per-repository `.git/hooks/`. If you use legitimate hooks (commit-msg linters, pre-commit checks), place them in `~/.git-hooks/`.

### 7. Clone This Repository

```bash
cd ~/projects  # or wherever you keep repos
git clone git@github.com:<org>/developer-environment.git
```

### 8. Run the Setup Verification

```bash
cd developer-environment
./scripts/setup.sh
```

Fix any failures before proceeding.

### 9. Remove Node.js from Mac (Recommended)

If Node.js is installed on your Mac, consider removing it to enforce the isolation boundary:

```bash
brew uninstall node
# or: nvm deactivate && nvm uninstall <version>
```

Node.js runs inside the container — you don't need it on the Mac.

**If Node.js must stay** (e.g., required by tools like `openspec`), add this guard to `~/.zshrc` to prevent accidental `npm install` on the Mac:

```bash
npm() {
  case "$1" in
    install|ci|test|run|start|exec)
      echo "⚠️  Blocked: 'npm $1' should run inside the dev container, not on Mac."
      echo "   Open the project in VS Code → Reopen in Container → use the container terminal."
      return 1
      ;;
    *)
      command npm "$@"
      ;;
  esac
}
```

This allows common read-only npm commands such as npm --version and npm list, while blocking several common commands that install dependencies or execute project/package scripts. It is an accident-prevention guard, not a complete security boundary.

### 10. First Container Launch

Open a Node.js project that has `.devcontainer/` configuration:

1. Open the project folder in VS Code
2. VS Code will prompt: "Reopen in Container" — click it
3. Wait for the container to build (first time takes a few minutes)
4. Verify the terminal opens inside the container
5. Run `npm install` to populate the node_modules volume
6. Run `./scripts/verify-isolation.sh` (from inside the container) to confirm credential isolation

## What NOT to Do

- Prefer no Node.js/npm on the Mac. If required by trusted host tools, never use the host installation for project dependencies, builds, tests, or scripts.
- Do NOT mount `~/.ssh` or `~/.config` into containers
- Do NOT forward SSH agent into containers
- Do NOT set cloud credential environment variables in the container

## Next

See [Daily Workflow](daily-workflow.md) for everyday usage.
