#!/usr/bin/env bash
# rebuild.sh
# Destroy and rebuild the development container from scratch.
# Run from the Mac terminal, in the project directory that uses the Dev Container.
#
# Usage:
#   ./scripts/rebuild.sh              # Rebuild container only
#   ./scripts/rebuild.sh --clean      # Rebuild container AND remove node_modules volume
#
# This is the "nuke from orbit" recovery script. Use it when:
# - A supply-chain compromise is suspected
# - The container is in a bad state
# - You want a fresh environment

set -euo pipefail

CLEAN=false
if [ "${1:-}" = "--clean" ]; then
  CLEAN=true
fi

echo "=== Secure Dev Container: Rebuild ==="

# Determine the project name (used by Docker Compose for naming)
PROJECT_DIR=$(basename "$(pwd)")
COMPOSE_PROJECT="${PROJECT_DIR}"

echo ""
echo "Project: $PROJECT_DIR"
echo "Clean mode: $CLEAN"
echo ""

# Stop and remove the dev container
echo "→ Stopping containers..."
docker compose -f .devcontainer/docker-compose.yml down --remove-orphans 2>/dev/null || true

if [ "$CLEAN" = true ]; then
  echo "→ Removing node_modules volume..."
  # The volume name depends on how Docker Compose names it
  # Try common patterns
  docker volume rm "${COMPOSE_PROJECT}_node_modules" 2>/dev/null || \
    docker volume rm "devcontainer_node_modules" 2>/dev/null || \
    echo "  (no volume found to remove — ok)"
fi

# Rebuild the image from scratch
echo "→ Rebuilding container image (no cache)..."
docker compose -f .devcontainer/docker-compose.yml build --no-cache

echo ""
echo "✅ Rebuild complete."
echo ""
echo "Next steps:"
echo "  1. Reopen this folder in VS Code"
echo "  2. VS Code will prompt to 'Reopen in Container' — do it"
echo "  3. Run 'npm install' inside the container"
if [ "$CLEAN" = true ]; then
  echo "  4. node_modules was removed — npm install will recreate from scratch"
fi
