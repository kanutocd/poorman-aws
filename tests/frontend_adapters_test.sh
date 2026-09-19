#!/usr/bin/env bash
set -euo pipefail

project_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
wrapper="$project_root/bin/poorman-aws"
temporary_directory=$(mktemp -d)
trap 'rm -rf "$temporary_directory"' EXIT

mkdir -p "$temporary_directory/consumer/backend" "$temporary_directory/consumer/frontend"
touch "$temporary_directory/consumer/backend/compose.production.yaml"
touch "$temporary_directory/consumer/backend/Caddyfile"
touch "$temporary_directory/consumer/backend/Dockerfile"
cat >"$temporary_directory/consumer/.poorman-aws.yml" <<'YAML'
version: 1
application_name: frontend-fixture
deployment_shape: backend-and-frontend
infrastructure_ref: v1.5.4
aws:
  region: us-east-2
  availability_zone: us-east-2a
  route53_zone_name: example.test
  state_bucket: frontend-fixture-state
backend:
  ssm_parameter_path: /frontend-fixture/staging
frontend:
  directory: frontend
  build_command: pnpm build
  deploy_command: bash poorman-aws/bin/frontend-adapter deploy
  remove_command: bash poorman-aws/bin/frontend-adapter remove
  output_entrypoint: dist/index.html
  frontend_url: https://app.example.test
  api_url: https://api.example.test
  frontend_origin: https://app.example.test
  api_base_url: https://api.example.test
  frontend_hostname: app.example.test
  frontend_certificate_arn: arn:aws:acm:us-east-1:000000000000:certificate/example
  aws_role_secret: AWS_FRONTEND_ROLE_ARN
YAML

export XDG_STATE_HOME="$temporary_directory/state"
pushd "$temporary_directory/consumer" >/dev/null
config_output="$($wrapper config show)"
grep -Fq 'frontend.directory' <<<"$config_output"
grep -Fq 'frontend-fixture' <<<"$config_output"
override="$($wrapper --frontend-url https://override.example.test config show)"
grep -Fq 'https://override.example.test (source: cli)' <<<"$override"

deploy_output="$($wrapper --dry-run frontend deploy --environment staging --apply --confirm FRONTEND-DEPLOY-STAGING)"
grep -Fq 'poorman-aws-frontend-deploy.yml' <<<"$deploy_output"
rollback_output="$($wrapper --dry-run frontend rollback --environment staging --consumer-ref abc1234 --apply --confirm FRONTEND-ROLLBACK-STAGING)"
grep -Fq 'poorman-aws-frontend-rollback.yml' <<<"$rollback_output"

lifecycle_output="$($wrapper --dry-run frontend lifecycle --action NUKE --consumer-ref abc1234 --apply --confirm FRONTEND-NUKE-STAGING)"
grep -Fq 'poorman-aws-frontend-lifecycle.yml' <<<"$lifecycle_output"

if $wrapper --dry-run frontend lifecycle --environment production --action NUKE --consumer-ref abc1234 >/dev/null 2>&1; then
  echo 'production frontend lifecycle unexpectedly succeeded' >&2
  exit 1
fi
popd >/dev/null

mkdir -p "$temporary_directory/onboard/backend" "$temporary_directory/onboard/frontend"
touch "$temporary_directory/onboard/backend/compose.production.yaml"
touch "$temporary_directory/onboard/backend/Caddyfile"
touch "$temporary_directory/onboard/backend/Dockerfile"
(
  cd "$temporary_directory/onboard"
  "$wrapper" --consumer-path . --non-interactive onboard \
    --application-name onboard-frontend \
    --deployment-shape backend-and-frontend \
    --ami-subnet-id subnet-0123456789abcdef0 \
    --availability-zone us-east-2a \
    --route53-zone-name example.test \
    --state-bucket onboard-frontend-state \
    --aws-region us-east-2 \
    --frontend-url https://app.example.test \
    --api-url https://api.example.test \
    --frontend-origin https://app.example.test \
    --frontend-hostname app.example.test
  test -f .github/workflows/poorman-aws-frontend-deploy.yml
  test -f .github/workflows/poorman-aws-frontend-rollback.yml
  test -f .github/workflows/poorman-aws-frontend-lifecycle.yml
  grep -Fq 'uses: kanutocd/poorman-aws/.github/workflows/deploy-frontend.yml@v0.1.0' .github/workflows/poorman-aws-frontend-deploy.yml
  grep -Fq 'deploy_command: bash poorman-aws/bin/frontend-adapter deploy' .github/workflows/poorman-aws-frontend-deploy.yml
  ! grep -Fq 'pnpm exec sst' .github/workflows/poorman-aws-frontend-deploy.yml
  grep -Fq 'frontend_hostname:' .github/workflows/poorman-aws-frontend-lifecycle.yml
  ! grep -R -E 'AWS_SECRET_ACCESS_KEY=|API_KEY=|TOKEN=' .github/workflows/poorman-aws-frontend-*.yml
)

echo 'frontend adapter checks passed'
