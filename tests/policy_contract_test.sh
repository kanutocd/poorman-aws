#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
bootstrap_script="$project_root/bin/bootstrap-github-oidc"
backend_root="$project_root/backend"
ami_workflow="$project_root/.github/workflows/build-backend-ami.yml"

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
assert_contains 'docs/mkdocs/recovery.md' "$project_root/backend/README.md"
assert_contains 'Recovery point objective (RPO): 24 hours.' "$project_root/docs/mkdocs/recovery.md"
assert_contains 'Recovery time objective (RTO): 4 hours.' "$project_root/docs/mkdocs/recovery.md"
assert_contains 'Restore rehearsal: quarterly for production.' "$project_root/docs/mkdocs/recovery.md"
assert_contains 'Docker named-volume state, including Caddy certificate state' "$project_root/docs/mkdocs/recovery.md"
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
assert_contains 'docs/mkdocs/quality.md' "$project_root/README.md"
assert_contains 'docs/mkdocs/change-management.md' "$project_root/README.md"
assert_contains 'bash bin/docs lint' "$project_root/bin/quality"
assert_contains 'Reuse a matching live AMI when available' "$ami_workflow"
assert_contains 'poorman-aws-${APPLICATION_NAME}-ami' "$ami_workflow"
assert_contains 'AMI_BUILD_FINGERPRINT' "$ami_workflow"
assert_contains 'aws ec2 describe-images' "$ami_workflow"
assert_contains 'retry_delays=(2 5 10 15)' "$ami_workflow"
assert_contains '--retry-all-errors' "$ami_workflow"
assert_contains 'is still pending; retrying validation.' "$ami_workflow"
assert_contains 'if: needs.guard.outputs.reuse != '\''true'\''' "$ami_workflow"
assert_contains 'needs: [guard, build]' "$ami_workflow"
assert_contains 'value: ${{ jobs.publish.outputs.ami_id }}' "$ami_workflow"
assert_contains 'uses: hashicorp/setup-packer@ce93c3c08a6c2ff2275bf4b54ff0d9a75f6c9789' "$ami_workflow"
assert_contains 'build_fingerprint' "$project_root/backend/packer/application-backend.pkr.hcl"
assert_contains 'build_or_resolve_ami:' "$project_root/.github/workflows/deploy-backend-infra.yml"
assert_contains 'uses: $/.github/workflows/build-backend-ami.yml' "$project_root/.github/workflows/deploy-backend-infra.yml"
assert_contains 'ami_build_role_arn' "$project_root/.github/workflows/deploy-backend-infra.yml"
assert_contains 'needs.build_or_resolve_ami.outputs.ami_id' "$project_root/.github/workflows/deploy-backend-infra.yml"
assert_absent 'Resolve AMI ID from artifact or environment variable' "$project_root/.github/workflows/deploy-backend-infra.yml"
assert_absent 'build-backend-ami.yml' "$project_root/.github/workflows/kill-non-production.yml"

echo "Policy contract checks passed"
