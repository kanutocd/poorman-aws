#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
temporary_dir="$(mktemp -d)"
fake_bin="${temporary_dir}/bin"
policy_dir="${temporary_dir}/policies"
mkdir -p "$fake_bin" "$policy_dir"
trap 'rm -rf "$temporary_dir"' EXIT

cat >"${fake_bin}/aws" <<'AWS'
#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "sts" && "${2:-}" == "get-caller-identity" ]]; then
  printf '123456789012\n'
  exit 0
fi

printf 'unexpected fake AWS call: %s\n' "$*" >&2
exit 1
AWS
chmod +x "${fake_bin}/aws"

PATH="${fake_bin}:${PATH}" "$project_root/bin/bootstrap-github-oidc" \
  --repo example/project \
  --state-bucket example-state \
  --route53-zone-id Z0123456789ABC \
  --route53-zone-name example.test \
  --region us-east-1 \
  --application-name example \
  --policy-output-dir "$policy_dir" >/dev/null

python3 - "$policy_dir" <<'PY'
import json
import pathlib
import sys

policy_dir = pathlib.Path(sys.argv[1])

for environment in ("staging", "production"):
    policy_path = policy_dir / f"{environment}-permissions.json"
    policy = json.loads(policy_path.read_text())
    statements = policy["Statement"]

    assert all(statement.get("Action") != "ec2:*" for statement in statements)
    dns = next(statement for statement in statements if statement["Sid"] == "ManageEnvironmentDns")
    assert dns["Resource"] == "arn:aws:route53:::hostedzone/Z0123456789ABC"
    assert dns["Resource"] != "*"

    destroy = next(statement for statement in statements if statement["Sid"] == "DestroyTaggedEnvironmentCompute")
    assert destroy["Condition"]["StringEquals"]["ec2:ResourceTag/Application"] == "example"
    assert destroy["Condition"]["StringEquals"]["ec2:ResourceTag/Environment"] == environment

    pass_role = next(statement for statement in statements if statement["Sid"] == "PassEnvironmentBackendRole")
    assert pass_role["Action"] == "iam:PassRole"
    assert pass_role["Resource"] == f"arn:aws:iam::123456789012:role/example-{environment}-backend-*"

print("Rendered deployment policy checks passed")
PY
