#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
bootstrap_script="$project_root/bin/bootstrap-github-oidc"
backend_root="$project_root/backend"

assert_contains() {
  local pattern="$1"
  local file="$2"
  rg -q --fixed-strings -- "$pattern" "$file" || {
    echo "missing contract: $pattern ($file)" >&2
    exit 1
  }
}

assert_absent() {
  local pattern="$1"
  local file="$2"
  if rg -q --fixed-strings -- "$pattern" "$file"; then
    echo "forbidden contract found: $pattern ($file)" >&2
    exit 1
  fi
}

assert_absent '"Action": "ec2:*"' "$bootstrap_script"
assert_contains '"ec2:RunInstances"' "$bootstrap_script"
assert_contains '"ec2:TerminateInstances"' "$bootstrap_script"
assert_contains '--route53-zone-id is required unless --create-hosted-zone is used' "$bootstrap_script"
assert_contains 'resource "terraform_data" "production_destroy_guard"' "$backend_root/main.tf"
assert_contains 'prevent_destroy = var.environment == "production"' "$backend_root/main.tf"
assert_contains 'expiration {' "$backend_root/modules/deployment-artifacts/main.tf"
assert_contains 'default     = 30' "$backend_root/modules/deployment-artifacts/variables.tf"
assert_contains 'resource "aws_backup_plan" "data"' "$backend_root/main.tf"
assert_contains 'rule_name         = "daily"' "$backend_root/main.tf"
assert_contains 'delete_after = 7' "$backend_root/main.tf"
assert_contains 'rule_name         = "weekly"' "$backend_root/main.tf"
assert_contains 'delete_after = 28' "$backend_root/main.tf"
assert_contains 'resources = [module.compute.data_volume_arn]' "$backend_root/main.tf"
assert_contains 'printf '\''SecureString'\''' "$project_root/bin/bootstrap-backend-parameters"
assert_contains '--non-secret' "$project_root/bin/bootstrap-backend-parameters"
assert_contains 'backend/modules/compute' "$project_root/bin/quality"

echo "Policy contract checks passed"
