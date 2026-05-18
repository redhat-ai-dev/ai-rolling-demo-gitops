#!/bin/bash
set -euo pipefail

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

export PYTEST_EXTRA_ARGS="-x"
exec "$SCRIPTS_DIR/run-tests.sh"
