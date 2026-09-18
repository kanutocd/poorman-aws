#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
temporary_dir="$(mktemp -d)"
fake_bin="${temporary_dir}/bin"
aws_log="${temporary_dir}/aws-types.log"
trap 'rm -rf "$temporary_dir"' EXIT
mkdir -p "$fake_bin"

cat >"${fake_bin}/aws" <<'AWS'
#!/usr/bin/env bash
set -euo pipefail

name=''
type=''
if [[ "${1:-}" == "ssm" && "${2:-}" == "get-parameter" ]]; then
  printf '%s\n' "${FAKE_EXISTING_TYPE:-}"
  exit 0
fi

while (($# > 0)); do
  case "$1" in
    --name) name="$2"; shift 2 ;;
    --type) type="$2"; shift 2 ;;
    --value) shift 2 ;;
    *) shift ;;
  esac
done
printf '%s=%s\n' "$name" "$type" >>"${AWS_TYPE_LOG:?}"
AWS
chmod +x "${fake_bin}/aws"

environment_file="${temporary_dir}/runtime.env"
cat >"$environment_file" <<'ENV'
APPLICATION_API_TOKEN=super-secret-token
APPLICATION_API_HOSTNAME=api.example.test
ENV

dry_run_output="${temporary_dir}/dry-run.out"
AWS_REGION=us-east-1 "$project_root/bin/bootstrap-backend-parameters" \
  --environment staging \
  --from-env-file "$environment_file" \
  >"$dry_run_output"

grep -Fq '/application/staging/APPLICATION_API_TOKEN (SecureString)' "$dry_run_output"
grep -Fq '/application/staging/APPLICATION_API_HOSTNAME (SecureString)' "$dry_run_output"
! grep -Fq 'super-secret-token' "$dry_run_output"

non_secret_output="${temporary_dir}/non-secret.out"
AWS_REGION=us-east-1 "$project_root/bin/bootstrap-backend-parameters" \
  --environment staging \
  --from-env-file "$environment_file" \
  --non-secret APPLICATION_API_HOSTNAME \
  >"$non_secret_output"

grep -Fq '/application/staging/APPLICATION_API_HOSTNAME (String)' "$non_secret_output"
grep -Fq '/application/staging/APPLICATION_API_TOKEN (SecureString)' "$non_secret_output"
! grep -Fq 'super-secret-token' "$non_secret_output"

AWS_TYPE_LOG="$aws_log" PATH="${fake_bin}:${PATH}" AWS_REGION=us-east-1 \
  "$project_root/bin/bootstrap-backend-parameters" \
  --environment staging \
  --from-env-file "$environment_file" \
  --non-secret APPLICATION_API_HOSTNAME \
  --apply >/dev/null

grep -Fq '/application/staging/APPLICATION_API_TOKEN=SecureString' "$aws_log"
grep -Fq '/application/staging/APPLICATION_API_HOSTNAME=String' "$aws_log"

if FAKE_EXISTING_TYPE=SecureString AWS_TYPE_LOG="$aws_log" PATH="${fake_bin}:${PATH}" AWS_REGION=us-east-1 \
  "$project_root/bin/bootstrap-backend-parameters" \
  --environment staging \
  --from-env-file "$environment_file" \
  --non-secret APPLICATION_API_HOSTNAME \
  --apply >/dev/null 2>&1; then
  echo "parameter type migration was not blocked" >&2
  exit 1
fi

FAKE_EXISTING_TYPE=SecureString AWS_TYPE_LOG="$aws_log" PATH="${fake_bin}:${PATH}" AWS_REGION=us-east-1 \
  "$project_root/bin/bootstrap-backend-parameters" \
  --environment staging \
  --from-env-file "$environment_file" \
  --non-secret APPLICATION_API_HOSTNAME \
  --allow-type-change \
  --apply >/dev/null

duplicate_file="${temporary_dir}/duplicate.env"
printf 'DUPLICATE=value\nDUPLICATE=other\n' >"$duplicate_file"
if AWS_REGION=us-east-1 "$project_root/bin/bootstrap-backend-parameters" \
  --environment staging --from-env-file "$duplicate_file" >/dev/null 2>&1; then
  echo "duplicate parameter was accepted" >&2
  exit 1
fi

empty_file="${temporary_dir}/empty.env"
printf 'EMPTY_VALUE=\n' >"$empty_file"
if AWS_REGION=us-east-1 "$project_root/bin/bootstrap-backend-parameters" \
  --environment staging --from-env-file "$empty_file" >/dev/null 2>&1; then
  echo "empty parameter was accepted" >&2
  exit 1
fi

newline_file="${temporary_dir}/newline.env"
printf 'MULTILINE=value\r\n' >"$newline_file"
if AWS_REGION=us-east-1 "$project_root/bin/bootstrap-backend-parameters" \
  --environment staging --from-env-file "$newline_file" >/dev/null 2>&1; then
  echo "newline parameter was accepted" >&2
  exit 1
fi

if AWS_REGION=us-east-1 "$project_root/bin/bootstrap-backend-parameters" \
  --environment staging --from-env-file "$environment_file" \
  --non-secret NOT_PRESENT >/dev/null 2>&1; then
  echo "undeclared non-secret parameter was accepted" >&2
  exit 1
fi

echo "Backend parameter handling checks passed"
