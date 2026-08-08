# New Project Onboarding

How to configure a new Node.js project repository to use the secure Dev Container template.

## Overview

Each Node.js project needs a `.devcontainer/` directory that references the shared template from the `developer-environment` repository. There are several mechanisms to achieve this.

## Option A: Copy Template (Simplest)

Copy the `.devcontainer/` directory from developer-environment into your project:

```bash
cp -r ~/projects/developer-environment/.devcontainer ~/projects/my-new-project/
```

Then customize if needed (e.g., add project-specific extensions).

**Pros**: Simple, self-contained, no external dependency at runtime.
**Cons**: Won't auto-update when the template changes.

## Option B: Symlink (Single Machine)

```bash
cd ~/projects/my-new-project
ln -s ~/projects/developer-environment/.devcontainer .devcontainer
```

**Pros**: Always uses latest template. Zero maintenance.
**Cons**: Only works on your machine (symlink target is absolute path). Don't commit the symlink.

## Option C: Git Submodule (Team-Friendly)

```bash
cd ~/projects/my-new-project
git submodule add git@github.com:<org>/developer-environment.git .dev-env
# Then in .devcontainer/devcontainer.json, reference the submodule's Dockerfile
```

**Pros**: Version-controlled, works for teams.
**Cons**: Submodules add complexity.

## Recommended: Option A + Pull Updates Manually

For a single developer, copy the template and periodically update:

```bash
# When the template changes:
cp -r ~/projects/developer-environment/.devcontainer ~/projects/my-project/
```

## After Adding .devcontainer/

1. Open the project in VS Code
2. VS Code prompts "Reopen in Container" — do it
3. Wait for the image to build (first time only)
4. Run `npm install` inside the container
5. Verify: `./scripts/verify-isolation.sh` (copy the script too, or run from developer-environment)

## Project-Specific Customizations

You may need to customize `devcontainer.json` for specific projects:

### Additional extensions

```jsonc
{
  "customizations": {
    "vscode": {
      "extensions": [
        // ... base extensions ...
        "dbaeumer.vscode-eslint",  // if project uses ESLint
        "esbenp.prettier-vscode"   // if project uses Prettier
      ]
    }
  }
}
```

### Additional environment variables (non-secret)

```jsonc
{
  "remoteEnv": {
    "NODE_ENV": "development",
    "API_PORT": "3000"
  }
}
```

### npm allowScripts

If your project needs native modules that require install scripts, add to `package.json`:

```json
{
  "allowScripts": {
    "esbuild": true,
    "sharp": true,
    "better-sqlite3": true
  }
}
```

Run `npm approve-scripts` to interactively build the allow-list, then commit the change.

## What Not to Add

Never add to the project's `.devcontainer/`:
- SSH agent forwarding
- Mounts to `~/.ssh`, `~/.config/gcloud`, `~/.terraform.d`
- Docker socket mount
- Cloud credential environment variables
