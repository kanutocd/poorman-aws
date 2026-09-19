#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
wrapper="$project_root/bin/poorman-aws"
temporary_dir="$(mktemp -d)"
prompt_home="$(mktemp -d)"
trap 'rm -rf "$temporary_dir" "$prompt_home"' EXIT

orphan_directory="$temporary_dir/../poorman-wrapper-orphan"
mkdir -p "$orphan_directory"
if (cd "$orphan_directory" && "$wrapper" --offline --non-interactive install >/dev/null 2>&1); then
  echo 'install proceeded without an inferable consumer repository path' >&2
  exit 1
fi
rmdir "$orphan_directory"

cat >"$temporary_dir/.poorman-aws.yml" <<'YAML'
version: 1
application_name: fixture-app
infrastructure_ref: v1.5.4
aws:
  region: us-east-2
  state_bucket: fixture-state
backend:
  ssm_parameters_path: /fixture/staging
defaults:
  instance_type: t4g.small
  root_volume_size_gib: 16
YAML

git -C "$temporary_dir" init -q
mkdir -p "$temporary_dir/backend"
tilde_home="$prompt_home/tilde-home"
mkdir -p "$tilde_home"
tilde_output="$(HOME="$tilde_home" XDG_STATE_HOME="$temporary_dir/tilde-state" \
  "$wrapper" --consumer-path '~' --offline --non-interactive config show)"
grep -Fq 'application_name                     application (source: default)' <<<"$tilde_output"

prompt_consumer="$tilde_home/prompt-consumer"
mkdir -p "$prompt_consumer"
prompt_path="$(printf '%c' '~')/prompt-consumer"
prompt_output="$(
  cd "$tilde_home"
  printf '%s\n\n' "$prompt_path" | \
    HOME="$tilde_home" PATH=/usr/bin:/bin \
    XDG_STATE_HOME="$temporary_dir/prompt-state" \
    "$wrapper" --offline install 2>&1 || true
)"
grep -Fq 'Application name [prompt-consumer]:' <<<"$prompt_output"

current_user_home="$(getent passwd "$(id -un)" | cut -d: -f6)"
named_home_output="$(HOME="$tilde_home" XDG_STATE_HOME="$temporary_dir/named-home-state" \
  "$wrapper" --consumer-path "~$(id -un)" --offline --non-interactive config show)"
grep -Fq 'application_name                     application (source: default)' <<<"$named_home_output"
[[ -d "$current_user_home" ]]

touch "$temporary_dir/backend/Dockerfile" "$temporary_dir/backend/Caddyfile"
cat >"$temporary_dir/backend/compose.production.yaml" <<'YAML'
services:
  backend:
    build: .
  worker:
    image: example/worker:check
YAML

pushd "$temporary_dir" >/dev/null
export XDG_STATE_HOME="$temporary_dir/state"
output="$("$wrapper" config show)"
grep -Fq 'application_name                     fixture-app (source: config:.poorman-aws.yml)' <<<"$output"
grep -Fq 'aws.region                           us-east-2 (source: config:.poorman-aws.yml)' <<<"$output"
grep -Fq 'defaults.data_volume_size_gib        20 (source: default)' <<<"$output"

mkdir -p nested/working-directory
nested_output="$(cd nested/working-directory && "$wrapper" config show)"
grep -Fq 'application_name                     fixture-app (source: config:.poorman-aws.yml)' <<<"$nested_output"

doctor_output="$("$wrapper" --offline doctor)"
grep -Fq 'ok: Compose file' <<<"$doctor_output"
grep -Fq 'info: offline mode skips AWS and GitHub checks' <<<"$doctor_output"

install_output="$("$wrapper" --offline install)"
grep -Fq 'installation checks passed' <<<"$install_output"
grep -Fq 'next: run onboard' <<<"$install_output"
grep -Fq "  $wrapper --consumer-path $temporary_dir --apply --confirm SYNC-GITHUB-ENVIRONMENTS github sync" <<<"$install_output"
grep -Fq "  $wrapper --consumer-path $temporary_dir --aws --github --docker --infra doctor" <<<"$install_output"
grep -Fq "state: $temporary_dir/state/poorman-aws/consumer-" <<<"$install_output"
test "$(find "$temporary_dir/state/poorman-aws" -type f -name 'consumer-*.yml' ! -name '*.config.yml' | wc -l)" -eq 1
grep -Fq "application_name: 'fixture-app'" \
  "$(find "$temporary_dir/state/poorman-aws" -type f -name 'consumer-*.yml' ! -name '*.config.yml' | head -1)"

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
(cd "$temporary_dir/detected" && "$wrapper" --consumer-path . --offline doctor >/dev/null 2>"$detected_stderr")
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
if "$wrapper" --consumer-path "$temporary_dir/ambiguous" config validate >/dev/null 2>&1; then
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
  "$wrapper" --consumer-path . --non-interactive onboard \
    --application-name onboard-app \
    --deployment-shape backend-and-frontend \
    --ami-subnet-id subnet-0123456789abcdef0 \
    --availability-zone us-east-2a \
    --route53-zone-name example.test \
    --state-bucket onboard-state \
    --aws-region us-east-2
  "$wrapper" --consumer-path . --non-interactive onboard \
    --application-name onboard-app \
    --deployment-shape backend-and-frontend \
    --infrastructure-ref v1.5.4 \
    --ami-subnet-id subnet-0123456789abcdef0 \
    --availability-zone us-east-2a \
    --route53-zone-name example.test \
    --state-bucket onboard-state \
    --aws-region us-east-2 >/dev/null
  grep -Fq 'uses: kanutocd/poorman-aws/.github/workflows/deploy-backend.yml@v0.1.0' \
    .github/workflows/poorman-aws-backend-deploy.yml
  for workflow in \
    .github/workflows/poorman-aws-backend-infra.yml \
    .github/workflows/poorman-aws-backend-deploy.yml \
    .github/workflows/poorman-aws-backend-rollback.yml \
    .github/workflows/poorman-aws-backend-ami.yml \
    .github/workflows/poorman-aws-lifecycle.yml \
    .github/workflows/poorman-aws-backend-parameters.yml; do
    grep -Fq '@v0.1.0' "$workflow"
    grep -Fq 'infrastructure_ref: v0.1.0' "$workflow"
  done
  ! sed -n '/workflow_dispatch:/,/jobs:/p' .github/workflows/poorman-aws-*.yml |
    grep -q 'infrastructure_ref:'
  grep -Fq 'state_bucket: onboard-state' .poorman-aws.yml
  grep -Fq 'subnet_id: subnet-0123456789abcdef0' .poorman-aws.yml
  ! grep -Fq 'ssh_cidr:' .poorman-aws.yml
  grep -Fq 'default: subnet-0123456789abcdef0' .github/workflows/poorman-aws-backend-ami.yml
  grep -Fq 'name: Build `poorman-aws` backend AMI' .github/workflows/poorman-aws-backend-ami.yml
  grep -Fq '  id-token: write' .github/workflows/poorman-aws-backend-ami.yml
  ! grep -Fq 'ssh_cidr:' .github/workflows/poorman-aws-backend-ami.yml
  grep -Fq 'default: onboard-app-backend' .github/workflows/poorman-aws-backend-ami.yml
  grep -Fq 'default: staging' .github/workflows/poorman-aws-backend-ami.yml
  grep -Fq 'target_environment: ${{ inputs.environment ||' .github/workflows/poorman-aws-backend-ami.yml
  ! grep -Fq 'ami_id: ${{ secrets.AMI_ID }}' .github/workflows/poorman-aws-backend-infra.yml
  ! grep -Fq 'ami_id: ${{ secrets.AMI_ID }}' .github/workflows/poorman-aws-lifecycle.yml
  for workflow in \
    .github/workflows/poorman-aws-frontend-deploy.yml \
    .github/workflows/poorman-aws-frontend-rollback.yml \
    .github/workflows/poorman-aws-frontend-lifecycle.yml; do
    test -f "$workflow"
    grep -Fq '@v0.1.0' "$workflow"
  done
  ! grep -R -Eq '(^|/)(infra|scripts)/|\.tf$|AWS_SECRET|API_KEY=' .github .poorman-aws.yml
  printf '\n# consumer-owned change\n' >> .github/workflows/poorman-aws-backend-deploy.yml
  if "$wrapper" --consumer-path . --non-interactive onboard \
    --application-name onboard-app \
    --deployment-shape backend-and-frontend \
    --ami-subnet-id subnet-0123456789abcdef0 \
    --availability-zone us-east-2a \
    --route53-zone-name example.test \
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
  printf 'interactive-app\nbackend-and-frontend\nus-east-2a\nsubnet-0123456789abcdef0\nexample.test\ninteractive-state\ny\n' |
    "$wrapper" --consumer-path . onboard >/dev/null 2>"$temporary_dir/interactive-onboard.stderr"
  grep -Fq 'onboarding change: .poorman-aws.yml' "$temporary_dir/interactive-onboard.stderr"
  grep -Fq 'application_name: interactive-app' .poorman-aws.yml
  grep -Fq 'state_bucket: interactive-state' .poorman-aws.yml
)

mkdir -p "$temporary_dir/fake-bin" "$temporary_dir/dispatch"
cat >"$temporary_dir/fake-bin/gh" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"${FAKE_GH_LOG:?}"
EOF
chmod +x "$temporary_dir/fake-bin/gh"
cp "$temporary_dir/interactive/.poorman-aws.yml" "$temporary_dir/dispatch/.poorman-aws.yml"
(
  cd "$temporary_dir/dispatch"
  export PATH="$temporary_dir/fake-bin:$PATH"
  export GH_REPOSITORY=example/consumer
  export FAKE_GH_LOG="$temporary_dir/gh.log"
  "$wrapper" plan --environment staging >/dev/null
  grep -Fq 'workflow run poorman-aws-backend-infra.yml --repo example/consumer -f environment=staging -f apply=false' "$temporary_dir/gh.log"
  "$wrapper" --dry-run plan --environment staging >/dev/null
  "$wrapper" --dry-run release --environment staging --apply --confirm RELEASE-STAGING >/dev/null
  "$wrapper" --dry-run rollback --environment staging --release-id abc1234 \
    --apply --confirm ROLLBACK-STAGING >/dev/null
  "$wrapper" --dry-run lifecycle --action STOP >/dev/null
  if "$wrapper" --non-interactive apply --environment staging >/dev/null 2>&1; then
    echo 'apply without explicit confirmation unexpectedly succeeded' >&2
    exit 1
  fi
)

echo 'poorman-aws wrapper checks passed'
