#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
bootstrap_script="$project_root/bin/bootstrap-github-oidc"
backend_root="$project_root/backend"

assert_contains() {
  local pattern="$1"
  local file="$2"
  grep -Fq -- "$pattern" "$file" || {
    echo "missing contract: $pattern ($file)" >&2
    exit 1
  }
}

assert_absent() {
  local pattern="$1"
  local file="$2"
  if grep -Fq -- "$pattern" "$file"; then
    echo "forbidden contract found: $pattern ($file)" >&2
    exit 1
  fi
}

assert_absent '"Action": "ec2:*"' "$bootstrap_script"
assert_contains '"ec2:RunInstances"' "$bootstrap_script"
assert_contains '"ec2:TerminateInstances"' "$bootstrap_script"
assert_contains '"ec2:ResourceTag/Application": "${application_name}"' "$bootstrap_script"
assert_contains '"aws:RequestTag/Application": "${application_name}"' "$bootstrap_script"
assert_contains '"Sid": "PassEnvironmentBackendRole"' "$bootstrap_script"
assert_contains '"Action": "iam:PassRole"' "$bootstrap_script"
assert_contains '"Resource": "${backend_role_arn}"' "$bootstrap_script"
assert_contains '--route53-zone-id is required unless --create-hosted-zone is used' "$bootstrap_script"
assert_contains 'route53_resource="arn:aws:route53:::hostedzone/${route53_zone_id}"' "$bootstrap_script"
assert_contains 'resource "terraform_data" "production_destroy_guard"' "$backend_root/main.tf"
assert_contains 'prevent_destroy = var.environment == "production"' "$backend_root/main.tf"
assert_contains 'resource "terraform_data" "production_destroy_guard"' "$backend_root/modules/compute/main.tf"
assert_contains 'resource "terraform_data" "production_destroy_guard"' "$backend_root/modules/networking/main.tf"
assert_contains 'resource "terraform_data" "production_destroy_guard"' "$backend_root/modules/deployment-artifacts/main.tf"
assert_contains 'resource "terraform_data" "production_destroy_guard"' "$backend_root/modules/dns-tls/main.tf"
assert_contains 'expiration {' "$backend_root/modules/deployment-artifacts/main.tf"
assert_contains 'default     = 30' "$backend_root/modules/deployment-artifacts/variables.tf"
assert_contains 'docs/recovery.md' "$project_root/backend/README.md"
assert_contains 'Recovery point objective (RPO): 24 hours.' "$project_root/docs/recovery.md"
assert_contains 'Recovery time objective (RTO): 4 hours.' "$project_root/docs/recovery.md"
assert_contains 'Restore rehearsal: quarterly for production.' "$project_root/docs/recovery.md"
assert_contains 'Docker named-volume state, including Caddy certificate state' "$project_root/docs/recovery.md"
assert_contains 'resource "aws_backup_plan" "data"' "$backend_root/main.tf"
assert_contains 'rule_name         = "daily"' "$backend_root/main.tf"
assert_contains 'delete_after = 7' "$backend_root/main.tf"
assert_contains 'rule_name         = "weekly"' "$backend_root/main.tf"
assert_contains 'delete_after = 28' "$backend_root/main.tf"
assert_contains 'resources = [module.compute.data_volume_arn]' "$backend_root/main.tf"
assert_contains 'Production must keep data-volume backups enabled.' "$backend_root/variables.tf"
assert_contains 'printf '\''SecureString'\''' "$project_root/bin/bootstrap-backend-parameters"
assert_contains '--non-secret' "$project_root/bin/bootstrap-backend-parameters"
assert_contains 'backend/modules/compute' "$project_root/bin/quality"

echo "Policy contract checks passed"
