#!/bin/bash
set -euo pipefail

# SCRIPTS_DIR: the scripts/ subdirectory relative to this file
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPTS_DIR/logging.sh"

# PRIVATE_ENV: the private-env file containing environment variables needed for the tests
PRIVATE_ENV="$SCRIPTS_DIR/private-env"

# Source private-env if it exists; otherwise rely on env vars already being set (e.g. in CI).
if [ -f "$PRIVATE_ENV" ]; then
  # shellcheck source=/dev/null
  source "$PRIVATE_ENV"
fi

# Default RHDH_BASE_URL from CI_HOSTNAME if not already set (matches ci-setup.sh and the CI workflow)
CI_HOSTNAME="${CI_HOSTNAME:-rhdh-ci.apps.testing}"
RHDH_BASE_URL="${RHDH_BASE_URL:-https://$CI_HOSTNAME}"

# Required environment variables for the auth-impersonation test suite
required_vars=(
  RHDH_BASE_URL
  RHDH_ENVIRONMENT
  ROLLING_DEMO_TEST_USERNAME
  KEYCLOAK_CLIENT_ID
  KEYCLOAK_CLIENT_SECRET
)

missing=()
for var in "${required_vars[@]}"; do
  if [ -z "${!var:-}" ]; then
    missing+=("$var")
  fi
done

if (( ${#missing[@]} )); then
  for var in "${missing[@]}"; do
    log_fail "$var is not set. Exiting..."
  done
  exit 1
fi

log "All required environment variables are set."

# GITOPS_DIR: the root directory of the gitops repository
GITOPS_DIR="$(cd "$SCRIPTS_DIR/.." && pwd)"

# TESTS_DIR: the tests/ subdirectory containing the test suite
TESTS_DIR="$GITOPS_DIR/tests"

if ! command -v node >/dev/null 2>&1; then
  log_fail "Node.js is not installed. Install Node.js 20+ and retry."
  exit 1
fi

if ! command -v npm >/dev/null 2>&1; then
  log_fail "npm is not installed. Install npm and retry."
  exit 1
fi

if [ ! -f "$TESTS_DIR/package.json" ]; then
  log_fail "Missing tests/package.json. Cannot run Playwright tests."
  exit 1
fi

log "Environment variables for tests:"
log "RHDH_BASE_URL=$RHDH_BASE_URL"
log "RHDH_ENVIRONMENT=$RHDH_ENVIRONMENT"
log "ROLLING_DEMO_TEST_USERNAME=***"
log "KEYCLOAK_CLIENT_ID=***"
log "KEYCLOAK_CLIENT_SECRET=****"
log "PLAYWRIGHT_HEADLESS=${PLAYWRIGHT_HEADLESS:-true}"

log "Installing Node dependencies in $TESTS_DIR..."
cd "$TESTS_DIR"
if [ -f package-lock.json ]; then
  npm ci
else
  npm install
fi

log "Running Playwright tests..."
env \
  RHDH_BASE_URL="$RHDH_BASE_URL" \
  RHDH_ENVIRONMENT="$RHDH_ENVIRONMENT" \
  ROLLING_DEMO_TEST_USERNAME="$ROLLING_DEMO_TEST_USERNAME" \
  KEYCLOAK_CLIENT_ID="$KEYCLOAK_CLIENT_ID" \
  KEYCLOAK_CLIENT_SECRET="$KEYCLOAK_CLIENT_SECRET" \
  PLAYWRIGHT_HEADLESS="${PLAYWRIGHT_HEADLESS:-true}" \
  npx playwright test ${PLAYWRIGHT_EXTRA_ARGS:-}
