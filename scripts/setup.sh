#!/usr/bin/env bash
# setup.sh
# Verify Mac prerequisites for the secure development environment.
# Run on the Mac before first use.
#
# Checks:
# - Docker Desktop is installed and running
# - VS Code is installed
# - VS Code Dev Containers extension is installed
# - Required environment variables are set (GIT_USER_NAME, GIT_USER_EMAIL)

set -euo pipefail

PASS=0
WARN=0
FAIL=0

check() {
  local description="$1"
  local result="$2"
  local detail="${3:-}"

  if [ "$result" = "pass" ]; then
    echo "✓ $description"
    PASS=$((PASS + 1))
  elif [ "$result" = "warn" ]; then
    echo "⚠ $description"
    [ -n "$detail" ] && echo "  → $detail"
    WARN=$((WARN + 1))
  else
    echo "✗ $description"
    [ -n "$detail" ] && echo "  → $detail"
    FAIL=$((FAIL + 1))
  fi
}

echo "=== Secure Dev Environment: Mac Setup Check ==="
echo ""

# Docker Desktop
if command -v docker &>/dev/null; then
  if docker info &>/dev/null 2>&1; then
    check "Docker Desktop installed and running" "pass"
  else
    check "Docker Desktop installed but not running" "fail" "Start Docker Desktop and retry"
  fi
else
  check "Docker Desktop installed" "fail" "Install from https://www.docker.com/products/docker-desktop/"
fi

# VS Code
if command -v code &>/dev/null; then
  check "VS Code installed" "pass"
else
  check "VS Code installed" "fail" "Install from https://code.visualstudio.com/"
fi

# Dev Containers extension
if command -v code &>/dev/null; then
  if code --list-extensions 2>/dev/null | grep -qi "ms-vscode-remote.remote-containers"; then
    check "VS Code Dev Containers extension installed" "pass"
  else
    check "VS Code Dev Containers extension installed" "fail" "Run: code --install-extension ms-vscode-remote.remote-containers"
  fi
fi

# Git user identity environment variables
if [ -n "${GIT_USER_NAME:-}" ]; then
  check "GIT_USER_NAME is set" "pass"
else
  check "GIT_USER_NAME is not set" "warn" "Set in ~/.zshrc or ~/.bashrc: export GIT_USER_NAME=\"Your Name\""
fi

if [ -n "${GIT_USER_EMAIL:-}" ]; then
  check "GIT_USER_EMAIL is set" "pass"
else
  check "GIT_USER_EMAIL is not set" "warn" "Set in ~/.zshrc or ~/.bashrc: export GIT_USER_EMAIL=\"you@example.com\""
fi

# Node.js should NOT be on Mac (advisory)
if command -v node &>/dev/null; then
  check "Node.js is installed on Mac (not required — runs in container)" "warn" "Consider removing to enforce isolation: brew uninstall node"
else
  check "No Node.js on Mac (good — it runs in the container)" "pass"
fi

# Git hooks should point to a safe directory
GIT_HOOKS_PATH=$(git config --global core.hooksPath 2>/dev/null || echo "")
if [ -n "$GIT_HOOKS_PATH" ] && [ "$GIT_HOOKS_PATH" != ".git/hooks" ]; then
  check "Git hooks redirected to safe location ($GIT_HOOKS_PATH)" "pass"
else
  check "Git hooks not redirected (container can write malicious hooks)" "warn" "Run: mkdir -p ~/.git-hooks && git config --global core.hooksPath ~/.git-hooks"
fi

# Summary
echo ""
echo "=== Results: $PASS passed, $WARN warnings, $FAIL failed ==="

if [ $FAIL -gt 0 ]; then
  echo ""
  echo "❌ Fix the failures above before proceeding."
  exit 1
elif [ $WARN -gt 0 ]; then
  echo ""
  echo "⚠️  Warnings are advisory. You can proceed but should address them."
  exit 0
else
  echo ""
  echo "✅ All prerequisites met. You're ready to go."
  exit 0
fi
