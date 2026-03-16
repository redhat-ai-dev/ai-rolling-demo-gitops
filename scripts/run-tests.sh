#!/bin/bash

# SCRIPTS_DIR: the scripts/ subdirectory relative to this file
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPTS_DIR/logging.sh"

# PRIVATE_ENV: the private-env file containing environment variables needed for the tests
PRIVATE_ENV="$SCRIPTS_DIR/private-env"

# Check if private-env file exists
if [ ! -f "$PRIVATE_ENV" ]; then
  log_fail "private-env not found at $PRIVATE_ENV. Please create it before running tests."
  exit 1
fi

# shellcheck source=/dev/null
source "$PRIVATE_ENV"

# Required environment variables for the test suite (see tests/README.md)
required_vars=(
  RHDH_BASE_URL
  RHDH_ENVIRONMENT
  ROLLING_DEMO_TEST_USERNAME
  KEYCLOAK_CLIENT_ID
  KEYCLOAK_CLIENT_SECRET
)

missing=()
for var in "${required_vars[@]}"; do
  if [ -z "${!var}" ]; then
    missing+=("$var")
  fi
done

if (( ${#missing[@]} )); then
  for var in "${missing[@]}"; do
    log_fail "$var is not set in private-env. Exiting..."
  done
  exit 1
fi

log "All required environment variables are set."

# GITOPS_DIR: the root directory of the gitops repository
GITOPS_DIR="$(cd "$SCRIPTS_DIR/.." && pwd)"

# TESTS_DIR: the tests/ subdirectory containing the test suite
TESTS_DIR="$GITOPS_DIR/tests"

# VENV_ACTIVATE: the path to the activate script of the virtual environment
VENV_ACTIVATE="$TESTS_DIR/.venv/bin/activate"

# Check if the virtual environment exists
if [ ! -f "$VENV_ACTIVATE" ]; then
  log_fail "Virtual environment not found at $TESTS_DIR/.venv. Run 'uv sync' inside tests/ first."
  exit 1
fi

# shellcheck source=/dev/null
source "$VENV_ACTIVATE"

# Check if uv is available after activating the virtual environment
if ! command -v uv >/dev/null 2>&1; then
  log_fail "uv not found after activating the virtual environment. Make sure uv is installed."
  exit 1
fi

# Check if pytest is available through uv
if ! uv run pytest --version >/dev/null 2>&1; then
  log_fail "pytest not found. Run 'uv sync' inside tests/ first."
  exit 1
fi

log "Environment variables for tests:"
log "RHDH_BASE_URL=$RHDH_BASE_URL"
log "RHDH_ENVIRONMENT=$RHDH_ENVIRONMENT"
log "ROLLING_DEMO_TEST_USERNAME=$ROLLING_DEMO_TEST_USERNAME"
log "KEYCLOAK_CLIENT_ID=$KEYCLOAK_CLIENT_ID"
log "KEYCLOAK_CLIENT_SECRET=****"
log "PLAYWRIGHT_HEADLESS=${PLAYWRIGHT_HEADLESS:-true}"

# Run the tests using pytest
log "Running tests in $TESTS_DIR..."
cd "$TESTS_DIR" && env \
  RHDH_BASE_URL="$RHDH_BASE_URL" \
  RHDH_ENVIRONMENT="$RHDH_ENVIRONMENT" \
  ROLLING_DEMO_TEST_USERNAME="$ROLLING_DEMO_TEST_USERNAME" \
  KEYCLOAK_CLIENT_ID="$KEYCLOAK_CLIENT_ID" \
  KEYCLOAK_CLIENT_SECRET="$KEYCLOAK_CLIENT_SECRET" \
  PLAYWRIGHT_HEADLESS="${PLAYWRIGHT_HEADLESS:-true}" \
  uv run pytest -v
