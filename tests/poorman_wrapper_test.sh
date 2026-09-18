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

mkdir -p "$temporary_dir/backend"
touch "$temporary_dir/backend/Dockerfile" "$temporary_dir/backend/Caddyfile"
cat >"$temporary_dir/backend/compose.production.yaml" <<'YAML'
services:
  backend:
    build: .
  worker:
    image: example/worker:check
YAML

pushd "$temporary_dir" >/dev/null
output="$("$wrapper" config show)"
grep -Fq 'application_name                     fixture-app (source: config:.poorman-aws.yml)' <<<"$output"
grep -Fq 'aws.region                           us-east-2 (source: config:.poorman-aws.yml)' <<<"$output"
grep -Fq 'defaults.data_volume_size_gib        20 (source: default)' <<<"$output"

doctor_output="$("$wrapper" --offline doctor)"
grep -Fq 'ok: Compose file' <<<"$doctor_output"
grep -Fq 'info: offline mode skips AWS and GitHub checks' <<<"$doctor_output"

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

mkdir -p "$temporary_dir/detected/deployment/backend" "$temporary_dir/detected/backend"
touch "$temporary_dir/detected/deployment/backend/compose.production.yaml"
touch "$temporary_dir/detected/deployment/backend/Caddyfile"
touch "$temporary_dir/detected/backend/Dockerfile"
cat >"$temporary_dir/detected/.poorman-aws.yml" <<'YAML'
version: 1
aws:
  state_bucket: detected-state
YAML
detected_stderr="$temporary_dir/detected.stderr"
(cd "$temporary_dir/detected" && "$wrapper" --offline doctor >/dev/null 2>"$detected_stderr")
grep -Fq 'detected Compose file' "$detected_stderr"
grep -Fq 'detected Caddyfile' "$detected_stderr"

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

mkdir -p "$temporary_dir/onboard/backend"
touch "$temporary_dir/onboard/backend/compose.production.yaml"
touch "$temporary_dir/onboard/backend/Caddyfile"
touch "$temporary_dir/onboard/backend/Dockerfile"
(
  cd "$temporary_dir/onboard"
  "$wrapper" --non-interactive onboard \
    --application-name onboard-app \
    --infrastructure-ref v1.5.4 \
    --state-bucket onboard-state \
    --aws-region us-east-2
  "$wrapper" --non-interactive onboard \
    --application-name onboard-app \
    --infrastructure-ref v1.5.4 \
    --state-bucket onboard-state \
    --aws-region us-east-2 >/dev/null
  grep -Fq 'uses: kanutocd/poorman-aws/.github/workflows/deploy-backend.yml@v1.5.4' \
    .github/workflows/poorman-aws-backend-deploy.yml
  grep -Fq 'state_bucket: onboard-state' .poorman-aws.yml
  ! grep -R -Eq '(^|/)(infra|scripts)/|\.tf$|AWS_SECRET|API_KEY=' .github .poorman-aws.yml
  printf '\n# consumer-owned change\n' >> .github/workflows/poorman-aws-backend-deploy.yml
  if "$wrapper" --non-interactive onboard \
    --application-name onboard-app \
    --infrastructure-ref v1.5.4 \
    --state-bucket onboard-state \
    --aws-region us-east-2 >/dev/null 2>&1; then
    echo 'conflicting generated workflow was overwritten without --overwrite' >&2
    exit 1
  fi
  grep -Fq '# consumer-owned change' .github/workflows/poorman-aws-backend-deploy.yml
)

mkdir -p "$temporary_dir/interactive/backend"
touch "$temporary_dir/interactive/backend/compose.production.yaml"
touch "$temporary_dir/interactive/backend/Caddyfile"
touch "$temporary_dir/interactive/backend/Dockerfile"
(
  cd "$temporary_dir/interactive"
  printf 'interactive-app\nv1.5.4\ninteractive-state\ny\n' |
    "$wrapper" onboard >/dev/null
  grep -Fq 'application_name: interactive-app' .poorman-aws.yml
  grep -Fq 'state_bucket: interactive-state' .poorman-aws.yml
)

echo 'poorman-aws wrapper checks passed'
