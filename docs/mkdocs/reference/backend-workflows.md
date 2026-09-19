# Backend workflows

These workflows provision the single-host backend, deploy immutable releases,
and roll back a known-good release. They run in the consumer repository and
check out the requested `poorman-aws` reference into `poorman-aws/`.

## Backend infrastructure

Workflow: `.github/workflows/deploy-backend-infra.yml`

Use this workflow to validate and plan the backend OpenTofu stack. Set
`apply: true` only when the reviewed plan and protected environment approval
are ready. The job validates the configuration first, initializes the selected
remote state, writes a plan, and applies that exact plan when requested.

Required inputs:

| Input | Meaning |
| --- | --- |
| `infrastructure_repository` | Repository containing `poorman-aws`. |
| `infrastructure_ref` | Immutable infrastructure tag or SHA. |
| `application_name` | Consumer application identity for state and tags. |
| `environment` | `staging` or `production`. |
| `aws_region` | AWS deployment region. |
| `state_bucket` | Encrypted S3 bucket for OpenTofu state. |
| `availability_zone` | Single Availability Zone for the host. |
| `ssm_parameter_path` | Runtime parameter path. |
| `route53_zone_name` | Existing public Route 53 hosted zone. |
| `ami_subnet_id` | Public subnet used by the idempotent AMI build-or-reuse prerequisite. |
| `ami_name_prefix` | AMI name prefix used for the build fingerprint and image metadata. |

Required secret:

| Secret | Meaning |
| --- | --- |
| `aws_role_arn` | IAM role allowed to manage the selected environment. |
| `ami_build_role_arn` | Dedicated `ami-build` IAM role used only when no matching live AMI exists. |

Before planning, the workflow calls `build-backend-ami.yml`. That reusable
workflow checks the canonical artifact, SSM Parameter Store, and selected
environment variables, validates the AMI and build fingerprint with AWS, and
runs Packer only when no matching live AMI exists. The plan receives the
resulting `ami_id` directly and fails closed if the prerequisite produces no
valid ID.
Because both workflows are published by `poorman-aws`, the infrastructure
workflow uses the release reference
`kanutocd/poorman-aws/.github/workflows/build-backend-ami.yml@v0.1.0`.
Consumers should update this release tag deliberately with the rest of their
generated integration files.

Optional infrastructure inputs include `instance_type` (`t4g.micro`),
`root_volume_size_gib` (`10`), `data_volume_size_gib` (`20`), `retain_eip`
(`true`), `retain_data_volume` (`true`), `release_retention_days` (`30`),
`enable_data_volume_backups` (`true`), customer-managed KMS key ARNs, an
optional hosted-zone ID, and JSON resource tags. Production must retain the
data volume and uses the production backup policy.

```yaml
jobs:
  infrastructure:
    uses: kanutocd/poorman-aws/.github/workflows/deploy-backend-infra.yml@v0.1.0
    with:
      infrastructure_repository: kanutocd/poorman-aws
      infrastructure_ref: v0.1.0
      application_name: example-app
      environment: staging
      aws_region: ap-southeast-1
      state_bucket: example-app-tofu-state
      availability_zone: ap-southeast-1a
      ssm_parameter_path: /example-app/staging
      route53_zone_name: example.test
      ami_subnet_id: subnet-0123456789abcdef0
      ami_name_prefix: example-app-backend
      apply: false
    secrets:
      aws_role_arn: ${{ secrets.AWS_BACKEND_ROLE_ARN }}
      ami_build_role_arn: ${{ secrets.AWS_AMI_ROLE_ARN }}
```

## Backend deployment

Workflow: `.github/workflows/deploy-backend.yml`

Use this workflow to build the consumer backend image, create a checksummed
immutable release, upload its artifacts, activate it through SSM, and run API,
CORS, and WebSocket verification.

Required inputs are `infrastructure_repository`, `infrastructure_ref`,
`application_name`, `environment`, `aws_region`, `state_bucket`, `api_url`,
`compose_file`, and `caddy_file`. Optional inputs include `build_context`
(`.`), `dockerfile` (`Dockerfile`), `frontend_url`, `frontend_origin`,
`instance_id`, and comma-separated `supplemental_files` in `DEST=PATH` form.

Required secret: `aws_role_arn`. The optional `application_api_token` secret is
used only for authenticated API verification.

## Backend rollback

Workflow: `.github/workflows/rollback-backend.yml`

Use this workflow to activate a release already stored in the private artifact
bucket. Required inputs are the backend deployment inputs plus `consumer_ref`
and `release_id`. `consumer_ref` is the consumer commit containing compatible
Compose and Caddy files; `release_id` must identify a known-good release.

The workflow checks out both repositories, resolves the deployment bucket from
OpenTofu state, activates the selected release, and verifies health. It does
not alter the retained data volume or backup schedule.

Required secrets are `aws_role_arn` and, optionally, `application_api_token` for
authenticated verification. Production still requires an immutable
`infrastructure_ref`.

## Backend safety rules

- Review the infrastructure plan before applying it.
- Use protected GitHub environments for production.
- Keep `aws_role_arn` scoped to backend infrastructure or backend release work.
- Never put API tokens, AWS credentials, state, plans, or populated runtime
  parameter files in workflow inputs or the consumer repository.
- Use the wrapper's `plan`, `apply`, `release`, and `rollback` commands when the
  consumer wants a local safety contract around these dispatches.
