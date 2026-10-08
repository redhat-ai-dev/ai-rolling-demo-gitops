#!/bin/bash
set -euo pipefail

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

export PLAYWRIGHT_EXTRA_ARGS="--max-failures=1"
# When Kind CI installed KServe + fixtures, ungate the cluster-fixture describe.
if [[ "${INSTALL_KSERVE_KIND:-true}" == "true" ]]; then
  export KSERVE_E2E="${KSERVE_E2E:-true}"
fi
exec "$SCRIPTS_DIR/run-tests.sh"
