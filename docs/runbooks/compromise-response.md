# Compromise Response

What to do if you suspect a malicious npm package has executed in the container.

## Indicators of Compromise

- npm advisory alerts for a package you have installed
- Unexpected network activity from the container
- Strange processes running inside the container
- Modified source files you didn't change (check `git diff` on Mac)
- Reports of a supply-chain attack affecting a package in your dependency tree

## Immediate Response

### Step 1: Stop the Container

From Mac terminal:

```bash
cd ~/projects/<affected-project>
docker compose -f .devcontainer/docker-compose.yml down
```

Or from Docker Desktop: stop the container.

### Step 2: Assess Source Code Integrity

From Mac terminal (NOT the container):

```bash
cd ~/projects/<affected-project>
git status
git diff
```

Review any unexpected changes. A malicious package could have:
- Modified source files (inserting backdoors)
- Added new files
- Modified `.devcontainer/` config (to weaken isolation next time)

If changes look suspicious:

```bash
git checkout -- .  # discard all working tree changes
# or selectively:
git checkout -- <suspicious-file>
```

### Step 3: Verify Mac Is Clean

The Mac should NOT be compromised if isolation held. Verify:

```bash
# Check that no unexpected processes are running
ps aux | grep -i node  # should find nothing

# SSH keys should be unchanged
ls -la ~/.ssh/
sha256sum ~/.ssh/id_* 2>/dev/null  # compare with known-good hashes

# GCP credentials should be unchanged
ls -la ~/.config/gcloud/
```

### Step 4: Destroy the Container and Volumes

Nuclear option — destroy everything related to this project's container:

```bash
cd ~/projects/<affected-project>
./scripts/rebuild.sh --clean
```

This removes:
- The container
- The node_modules volume (where malicious code lived)
- Rebuilds the image from scratch (no cache)

### Step 5: Rebuild Clean

1. Reopen project in VS Code → "Reopen in Container"
2. Review `package.json` and `package-lock.json` for the compromised package
3. Remove or replace the compromised dependency
4. Run `npm install` with clean dependencies
5. Run `./scripts/verify-isolation.sh` to confirm isolation

### Step 6: Rotate Credentials (If Isolation Was Breached)

If you have ANY reason to believe isolation was broken (e.g., SSH agent was accidentally forwarded, Docker socket was mounted):

- Rotate SSH keys: generate new keys, update GitHub/GitLab
- Rotate GCP credentials: `gcloud auth revoke` and re-authenticate
- Rotate any tokens that were accessible
- Review Git history for unauthorized pushes

## What the Attacker Could Have Accessed

If isolation held correctly:
- ✅ Source code (readable and writable via bind mount)
- ✅ Outbound network (could exfiltrate source)
- ❌ SSH keys (not in container)
- ❌ GCP credentials (not in container)
- ❌ Terraform state (not in container)
- ❌ Docker daemon (no socket)
- ❌ Mac filesystem beyond project directory

## Prevention

After recovering:
1. Update the compromised package or replace it
2. Run `npm audit` to check for other known issues
3. Consider adding the package to a deny-list if it's not essential
4. Review your `allowScripts` list — was the compromised package allowed to run install scripts?

## Record the Incident

Note what happened, what package was involved, and what you did. This helps if the same pattern emerges later.
