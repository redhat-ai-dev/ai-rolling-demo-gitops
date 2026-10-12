#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
chart_dir="$repo_root/charts/rhdh"

# Chart.lock omits fields such as alias and condition, so compare the resolved
# dependency names, pinned versions, and repositories.
dependency_fields='map({name, version, repository: (.repository // "")}) | sort_by(.name, .version, .repository)'
declared="$(yq -o=json '.dependencies' "$chart_dir/Chart.yaml" | jq -cS "$dependency_fields")"
locked="$(yq -o=json '.dependencies' "$chart_dir/Chart.lock" | jq -cS "$dependency_fields")"

if [[ "$declared" != "$locked" ]]; then
  echo "Chart.yaml and Chart.lock dependencies differ" >&2
  printf 'Declared: %s\nLocked:   %s\n' "$declared" "$locked" >&2
  exit 1
fi

# Helm loads each vendored .tgz and checks the name and version in its embedded
# Chart.yaml against the parent chart's declared dependency. This checks package
# identity and version, not byte-for-byte equality with an upstream download.
# Do not build dependencies here: that would replace the committed archives
# and hide the mismatch this check is meant to detect.
dependency_list="$(helm dependency list "$chart_dir")"
printf '%s\n' "$dependency_list"

# Helm returns success even for statuses such as "wrong version" or "missing".
if ! printf '%s\n' "$dependency_list" | awk '
  NR > 1 && NF && $NF != "ok" { invalid = 1 }
  END { exit invalid }
'; then
  echo "Vendored chart dependencies do not match Chart.yaml" >&2
  exit 1
fi

echo "Chart.yaml, Chart.lock, and vendored chart dependencies are in sync"
