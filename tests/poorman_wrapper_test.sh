#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
wrapper="$project_root/bin/poorman-aws"
temporary_dir="$(mktemp -d)"
trap 'rm -rf "$temporary_dir"' EXIT

cat >"$temporary_dir/.poorman-aws.yml" <<'YAML'
version: 1
application_name: fixture-app
infrastructure_ref: v1.5.4
aws:
  region: us-east-2
  state_bucket: fixture-state
backend:
  parameter_path: /fixture/staging
defaults:
  instance_type: t4g.small
  root_volume_size_gib: 16
YAML

pushd "$temporary_dir" >/dev/null
output="$("$wrapper" config show)"
grep -Fq 'application_name                     fixture-app (source: config:.poorman-aws.yml)' <<<"$output"
grep -Fq 'aws.region                           us-east-2 (source: config:.poorman-aws.yml)' <<<"$output"
grep -Fq 'defaults.data_volume_size_gib        20 (source: default)' <<<"$output"

override="$("$wrapper" --aws-region eu-west-1 --instance-type t4g.nano config show)"
grep -Fq 'aws.region                           eu-west-1 (source: cli)' <<<"$override"
grep -Fq 'defaults.instance_type' <<<"$override"
grep -Fq 't4g.nano (source: cli)' <<<"$override"

json_output="$("$wrapper" --json config show)"
grep -Fq '"key": "application_name"' <<<"$json_output"
grep -Fq '"source": "config:.poorman-aws.yml"' <<<"$json_output"

if "$wrapper" --config "$temporary_dir/missing.yml" config validate >/dev/null 2>&1; then
  echo 'missing explicit configuration was accepted' >&2
  exit 1
fi
popd >/dev/null

cat >"$temporary_dir/invalid.yml" <<'YAML'
version: 1
secrets:
  api_token: must-not-be-accepted
YAML
if "$wrapper" --config "$temporary_dir/invalid.yml" config validate >/dev/null 2>&1; then
  echo 'unsupported secret configuration was accepted' >&2
  exit 1
fi

mkdir -p "$temporary_dir/ambiguous"
touch "$temporary_dir/ambiguous/.poorman-aws.yml" "$temporary_dir/ambiguous/.poorman-aws.yaml"
if (cd "$temporary_dir/ambiguous" && "$wrapper" config validate >/dev/null 2>&1); then
  echo 'ambiguous auto-discovered configuration was accepted' >&2
  exit 1
fi

if "$wrapper" plan >/dev/null 2>&1; then
  echo 'reserved operational command unexpectedly succeeded' >&2
  exit 1
fi

echo 'poorman-aws wrapper checks passed'
