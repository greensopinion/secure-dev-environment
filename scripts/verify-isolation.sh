#!/usr/bin/env bash
# verify-isolation.sh
# Run INSIDE the dev container to confirm credential isolation.
# Exit code 0 = all checks pass. Non-zero = isolation breach detected.

set -euo pipefail

PASS=0
FAIL=0

check() {
  local description="$1"
  local result="$2"  # "pass" or "fail"
  local detail="${3:-}"

  if [ "$result" = "pass" ]; then
    echo "✓ PASS: $description"
    PASS=$((PASS + 1))
  else
    echo "✗ FAIL: $description"
    [ -n "$detail" ] && echo "        $detail"
    FAIL=$((FAIL + 1))
  fi
}

echo "=== Credential Isolation Verification ==="
echo ""

# 1. No SSH private keys
if ls ~/.ssh/id_* 2>/dev/null | grep -q .; then
  check "No SSH private keys in ~/.ssh/" "fail" "Found key files"
elif ls /root/.ssh/id_* 2>/dev/null | grep -q .; then
  check "No SSH private keys in /root/.ssh/" "fail" "Found key files"
else
  check "No SSH private keys accessible" "pass"
fi

# 2. No SSH agent socket
if [ -n "${SSH_AUTH_SOCK:-}" ] && [ -S "${SSH_AUTH_SOCK}" ]; then
  check "No SSH agent socket" "fail" "SSH_AUTH_SOCK=$SSH_AUTH_SOCK"
else
  check "No SSH agent socket" "pass"
fi

# 3. No GCP credentials
if [ -d ~/.config/gcloud ] && [ "$(ls -A ~/.config/gcloud 2>/dev/null)" ]; then
  check "No GCP credentials (~/.config/gcloud)" "fail" "Directory exists and is non-empty"
elif [ -n "${GOOGLE_APPLICATION_CREDENTIALS:-}" ]; then
  check "No GCP credentials (env var)" "fail" "GOOGLE_APPLICATION_CREDENTIALS is set"
else
  check "No GCP credentials" "pass"
fi

# 4. No gcloud CLI
if command -v gcloud &>/dev/null; then
  check "No gcloud CLI" "fail" "gcloud binary found at $(which gcloud)"
else
  check "No gcloud CLI" "pass"
fi

# 5. No Terraform credentials
if [ -d ~/.terraform.d ] && [ "$(ls -A ~/.terraform.d 2>/dev/null)" ]; then
  check "No Terraform credentials (~/.terraform.d)" "fail" "Directory exists"
elif env | grep -q "^TF_TOKEN_"; then
  check "No Terraform credentials (env vars)" "fail" "TF_TOKEN_* env vars found"
else
  check "No Terraform credentials" "pass"
fi

# 6. No Docker socket
if [ -S /var/run/docker.sock ]; then
  check "No Docker socket" "fail" "/var/run/docker.sock exists"
else
  check "No Docker socket" "pass"
fi

# 7. No credential environment variables
LEAKED_VARS=""
for var in AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN \
           GOOGLE_APPLICATION_CREDENTIALS GOOGLE_CLOUD_PROJECT \
           TF_TOKEN_app_terraform_io SSH_AUTH_SOCK \
           DOCKER_HOST DOCKER_TLS_VERIFY; do
  if [ -n "${!var:-}" ]; then
    LEAKED_VARS="$LEAKED_VARS $var"
  fi
done

if [ -n "$LEAKED_VARS" ]; then
  check "No credential environment variables" "fail" "Found:$LEAKED_VARS"
else
  check "No credential environment variables" "pass"
fi

# 8. Cannot traverse above /workspace to reach host home
if [ -f /workspace/../.ssh/id_rsa ] 2>/dev/null || [ -f /workspace/../.ssh/id_ed25519 ] 2>/dev/null; then
  check "Cannot reach host home via path traversal" "fail" "Found SSH keys above /workspace"
else
  check "Cannot reach host home via path traversal" "pass"
fi

# 9. Git credential helper is empty
GIT_CRED_HELPER=$(git config --global credential.helper 2>/dev/null || echo "")
if [ -z "$GIT_CRED_HELPER" ]; then
  check "Git credential helper is disabled" "pass"
else
  check "Git credential helper is disabled" "fail" "credential.helper=$GIT_CRED_HELPER"
fi

# Summary
echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="

if [ $FAIL -gt 0 ]; then
  echo ""
  echo "⚠️  ISOLATION BREACH DETECTED — review the failures above."
  exit 1
else
  echo ""
  echo "✅ All isolation checks passed."
  exit 0
fi
