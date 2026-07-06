#!/bin/bash
set -euo pipefail

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

export PLAYWRIGHT_EXTRA_ARGS="--max-failures=1"
exec "$SCRIPTS_DIR/run-tests.sh"
