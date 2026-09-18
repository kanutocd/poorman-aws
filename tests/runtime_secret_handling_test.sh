#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
temporary_dir="$(mktemp -d)"
fake_bin="${temporary_dir}/bin"
trap 'rm -rf "$temporary_dir"' EXIT
mkdir -p "$fake_bin"

cat >"${fake_bin}/aws" <<'AWS'
#!/usr/bin/env bash
set -euo pipefail

if [[ "${FAKE_NEWLINE:-false}" == true ]]; then
  jq -cn '{Parameters:[{Name:"/application/staging/API_TOKEN",Value:"bad\nvalue"}]}'
else
  printf '%s\n' '{"Parameters":[{"Name":"/application/staging/API_TOKEN","Value":"super-secret-token"}]}'
fi
AWS
chmod +x "${fake_bin}/aws"

output_path="${temporary_dir}/nested/runtime.env"
command_output="${temporary_dir}/command.out"
PATH="${fake_bin}:${PATH}" "$project_root/backend/scripts/render-runtime-env" \
  /application/staging "$output_path" >"$command_output" 2>&1

[[ "$(stat -c '%a' "$output_path")" == 600 ]]
grep -Fq 'API_TOKEN=super-secret-token' "$output_path"
! grep -Fq 'super-secret-token' "$command_output"

newline_output="${temporary_dir}/newline/runtime.env"
if FAKE_NEWLINE=true PATH="${fake_bin}:${PATH}" \
  "$project_root/backend/scripts/render-runtime-env" \
  /application/staging "$newline_output" >/dev/null 2>&1; then
  echo "newline parameter was accepted" >&2
  exit 1
fi
[[ ! -e "$newline_output" ]]

echo "Runtime secret handling checks passed"
