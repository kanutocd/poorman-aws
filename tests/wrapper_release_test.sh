#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
temporary_dir="$(mktemp -d)"
trap 'rm -rf "$temporary_dir"' EXIT

mkdir -p "$temporary_dir/consumer"
cat >"$temporary_dir/consumer/.poorman-aws.yml" <<'YAML'
version: 1
application_name: parity-app
infrastructure_ref: v1.5.4
aws:
  region: us-east-2
  state_bucket: parity-state
backend:
  ssm_parameter_path: /parity/staging
YAML

pushd "$temporary_dir/consumer" >/dev/null
cloned_output="$temporary_dir/cloned.txt"
remote_output="$temporary_dir/remote.txt"
"$project_root/bin/poorman-aws" config show >"$cloned_output"
bash -s -- config show <"$project_root/bin/poorman-aws" >"$remote_output"
cmp -s "$cloned_output" "$remote_output"
popd >/dev/null

"$project_root/bin/package-wrapper" --version v1.5.4 --output-dir "$temporary_dir/first" >/dev/null
"$project_root/bin/package-wrapper" --version v1.5.4 --output-dir "$temporary_dir/second" >/dev/null
cmp -s "$temporary_dir/first/poorman-aws-v1.5.4" "$temporary_dir/second/poorman-aws-v1.5.4"
cmp -s "$temporary_dir/first/poorman-aws-v1.5.4.sha256" "$temporary_dir/second/poorman-aws-v1.5.4.sha256"
(cd "$temporary_dir/first" && sha256sum -c poorman-aws-v1.5.4.sha256)
bash "$temporary_dir/first/poorman-aws-v1.5.4" --version | grep -Fq 'poorman-aws wrapper contract v1.5.4'
grep -Fq "wrapper_release_ref='v1.5.4'" "$temporary_dir/first/poorman-aws-v1.5.4"
grep -Fq '# poorman-aws v1.5.4' "$temporary_dir/first/release-notes.md"

echo 'wrapper release checks passed'
