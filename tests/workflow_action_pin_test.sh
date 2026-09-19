#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

while IFS= read -r action_reference; do
  action_ref="${action_reference##*@}"
  if [[ ! "$action_ref" =~ ^v[0-9]+([.][0-9]+){0,2}$ ]]; then
    echo "unpublished or mutable GitHub Action reference: $action_reference" >&2
    exit 1
  fi
done < <(grep -RhoE 'uses: [^[:space:]#]+' "$project_root/.github/workflows" | awk '{print $2}')

echo "Workflow action release-tag checks passed"
