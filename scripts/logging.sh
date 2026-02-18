#!/bin/bash

# Shared logging utilities for all scripts.
# Source this file to use: source "$(dirname "${BASH_SOURCE[0]}")/logging.sh"

BLUE='\033[34m'
LIGHT_BLUE='\033[94m'
RED='\033[31m'
RESET='\033[0m'

log() {
  echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${RESET} ${LIGHT_BLUE}INFO${RESET} $*"
}

log_fail() {
  echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${RESET} ${RED}FAIL${RESET} $*"
}
