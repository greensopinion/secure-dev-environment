# Troubleshooting

Common issues and their resolutions.

## Container Won't Start

### "Cannot connect to the Docker daemon"

Docker Desktop isn't running. Start it from Applications or:

```bash
open -a Docker
```

Wait 30 seconds for it to initialize, then retry.

### "image build failed" during container creation

Check the Dockerfile for errors:

```bash
cd ~/projects/<project>
docker compose -f .devcontainer/docker-compose.yml build --no-cache
```

Common causes:
- Network issue downloading packages (retry)
- terraform-ls download URL changed (check https://github.com/hashicorp/terraform-ls/releases)
- Base image tag changed (verify `node:24-bookworm` still exists)

### Container starts but VS Code can't connect

1. Check Docker Desktop shows the container running
2. Try: Command Palette → "Dev Containers: Rebuild Container"
3. Check Docker resource allocation (need at least 2 GB RAM for the container)

## npm Issues

### "npm install" hangs or fails

```bash
# Check network from inside container
curl -s https://registry.npmjs.org/ | head -c 100

# If network works but install fails, try clearing npm cache
npm cache clean --force
```

### "Scripts are disabled" errors

Expected behavior. The image disables install scripts by default. If a package needs scripts:

```bash
# See which packages want to run scripts
npm deny-scripts

# Approve specific ones
npm approve-scripts
```

This adds them to `allowScripts` in `package.json`. Commit the change.

### "Package version too new" (min-release-age)

A dependency was published less than 21 days ago. Options:
- Wait (safest — the 21-day quarantine is protecting you)
- Override for one install: `npm install --ignore-release-age`
- If you published the package yourself, override is safe

## Git Issues

### "git push" fails from inside container

Expected. Push from Mac terminal instead:

```bash
# Mac terminal
cd ~/projects/<project>
git push
```

### "git commit" fails inside container — no identity

The container needs `GIT_USER_NAME` and `GIT_USER_EMAIL` environment variables set on the Mac:

```bash
# Add to ~/.zshrc
export GIT_USER_NAME="Your Name"
export GIT_USER_EMAIL="your@email.com"
```

Then rebuild the container (or run the postCreateCommand manually):

```bash
git config --global user.name "$GIT_USER_NAME"
git config --global user.email "$GIT_USER_EMAIL"
```

### Changes made in container not visible on Mac (or vice versa)

This shouldn't happen — both share the same files via bind mount. If it does:
- Check the bind mount is correct in `docker-compose.yml`
- Ensure you're looking at the right directory
- Try `ls /workspace` inside container vs `ls ~/projects/<project>` on Mac

## Performance

### VS Code feels slow / file operations lag

macOS Docker bind mounts are slower than native filesystem. Mitigations:
- node_modules is in a volume (should already be fast)
- Increase Docker Desktop CPU/RAM allocation
- Avoid very large bind mounts (don't mount all of `~/`)

### npm install is slow

node_modules volume should give near-native I/O. If still slow:
- Check Docker Desktop resource allocation
- Consider: `npm install --prefer-offline` after first install
- Network speed affects initial package downloads

## Credential Isolation

### Verify isolation is intact

Run from inside the container:

```bash
/workspace/scripts/verify-isolation.sh
```

All checks should pass. If any fail, review what changed in the `.devcontainer/` configuration.

### Accidentally mounted SSH keys or credentials

1. Stop the container immediately: `docker compose -f .devcontainer/docker-compose.yml down`
2. Fix the `.devcontainer/` configuration
3. Rebuild: `./scripts/rebuild.sh --clean`
4. If the compromised container ran npm install or any npm scripts, treat it as a potential compromise — see [Compromise Response](compromise-response.md)

## Extensions

### Extension not loading in container

Check that it's listed in `devcontainer.json` under `customizations.vscode.extensions`. Extensions not listed won't be installed.

### Extension asks for credentials

Some extensions try to authenticate. If an extension is requesting credentials that would compromise isolation, either:
- Don't install it in the container
- Configure it to skip authentication
- Move it to Mac-side (if it's a UI-only extension)

## Nuclear Option

When all else fails:

```bash
cd ~/projects/<project>
./scripts/rebuild.sh --clean
```

This destroys everything (container + volumes) and rebuilds from scratch. Source code is safe (it's on the Mac).
