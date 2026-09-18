#!/usr/bin/env bash
set -euo pipefail

script_directory=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
temporary_directory=$(mktemp -d)
trap 'rm -rf "$temporary_directory"' EXIT

fake_bin="$temporary_directory/bin"
mkdir -p "$fake_bin" "$temporary_directory/frontend"
log_file="$temporary_directory/aws.log"
marker_file="$temporary_directory/removed"

cat >"$fake_bin/aws" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >>"${FAKE_AWS_LOG:?}"
case "$*" in
  "cloudfront list-distributions --output json")
    if [[ -n "${FAKE_DISTRIBUTIONS:-}" ]]; then
      printf '%s\n' "$FAKE_DISTRIBUTIONS"
    else
      printf '%s\n' '{"DistributionList":{"Items":[]}}'
    fi
    ;;
  "cloudfront get-distribution-config"*)
    printf '%s\n' "{\"DistributionConfig\":{\"Enabled\":${FAKE_ENABLED:-true}},\"ETag\":\"etag-1\"}"
    ;;
  "cloudfront update-distribution"*)
    ;;
  "cloudfront wait distribution-deployed"*)
    ;;
  *)
    echo "unexpected fake aws call: $*" >&2
    exit 1
    ;;
esac
EOF
chmod +x "$fake_bin/aws"

run_script() {
  PATH="$fake_bin:$PATH" \
  FAKE_AWS_LOG="$log_file" \
  FRONTEND_HOSTNAME=app.staging.example.test \
  FRONTEND_LIFECYCLE_ENVIRONMENT=staging \
  FRONTEND_LIFECYCLE_ACTION="$1" \
  FRONTEND_LIFECYCLE_CONFIRMATION="${2:-not-applied}" \
  FRONTEND_LIFECYCLE_APPLY="${3:-false}" \
  FRONTEND_DIRECTORY="$temporary_directory/frontend" \
  FRONTEND_REMOVE_COMMAND="printf removed > \"$marker_file\"" \
  bash "$script_directory/bin/frontend-lifecycle"
}

FAKE_DISTRIBUTIONS='{"DistributionList":{"Items":[{"Id":"E123","Aliases":{"Items":["app.staging.example.test"]}}]}}' \
  run_script DESTROY '' false >/dev/null
grep -q 'cloudfront list-distributions' "$log_file"
! grep -q 'update-distribution' "$log_file"

if run_script DESTROY wrong true >/dev/null 2>&1; then
  echo 'wrong confirmation unexpectedly succeeded' >&2
  exit 1
fi

if FRONTEND_LIFECYCLE_ENVIRONMENT=production \
  FRONTEND_LIFECYCLE_ACTION=DESTROY \
  FRONTEND_LIFECYCLE_CONFIRMATION=DESTROY-PRODUCTION \
  FRONTEND_LIFECYCLE_APPLY=false \
  FRONTEND_HOSTNAME=app.example.test \
  FRONTEND_LIFECYCLE_ENVIRONMENT=production \
  PATH="$fake_bin:$PATH" FAKE_AWS_LOG="$log_file" \
  bash "$script_directory/bin/frontend-lifecycle" >/dev/null 2>&1; then
  echo 'production lifecycle unexpectedly succeeded' >&2
  exit 1
fi

: >"$log_file"
FAKE_DISTRIBUTIONS='{"DistributionList":{"Items":[{"Id":"E123","Aliases":{"Items":["app.staging.example.test"]}}]}}' \
  FAKE_ENABLED=true run_script NUKE NUKE-STAGING true >/dev/null
grep -q 'cloudfront update-distribution' "$log_file"
grep -q 'cloudfront wait distribution-deployed' "$log_file"
test -f "$marker_file"

: >"$log_file"
FAKE_DISTRIBUTIONS='{"DistributionList":{"Items":[]}}' \
  FAKE_ENABLED=false run_script DESTROY DESTROY-STAGING true >/dev/null
! grep -q 'update-distribution' "$log_file"

: >"$log_file"
FAKE_DISTRIBUTIONS='{"DistributionList":{"Items":[{"Id":"E123","Aliases":{"Items":["app.staging.example.test"]}}]}}' \
  FAKE_ENABLED=false run_script DESTROY DESTROY-STAGING true >/dev/null
! grep -q 'update-distribution' "$log_file"
! grep -q 'cloudfront wait distribution-deployed' "$log_file"

if FRONTEND_LIFECYCLE_ACTION=NUKE \
  FRONTEND_LIFECYCLE_CONFIRMATION=NUKE-STAGING \
  FRONTEND_LIFECYCLE_APPLY=true \
  FRONTEND_LIFECYCLE_ENVIRONMENT=staging \
  FRONTEND_HOSTNAME=app.staging.example.test \
  FRONTEND_DIRECTORY="$temporary_directory/frontend" \
  FRONTEND_REMOVE_COMMAND=false \
  PATH="$fake_bin:$PATH" FAKE_AWS_LOG="$log_file" \
  bash "$script_directory/bin/frontend-lifecycle" >/dev/null 2>&1; then
  echo 'failed frontend removal command unexpectedly succeeded' >&2
  exit 1
fi

echo 'frontend lifecycle checks passed'
