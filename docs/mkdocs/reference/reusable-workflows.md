# Reusable workflows

The reusable workflows are the primary integration surface of `poorman-aws`.
They let a consumer repository keep its application code and caller workflows
while `poorman-aws` owns the infrastructure implementation, safety checks, and
operational scripts.

Every workflow in this section is called with GitHub Actions `workflow_call`.
They are not standalone push-triggered workflows. Add a thin caller workflow
to the consumer repository, pin the `uses` reference to a release tag or full
commit SHA, and pass the consumer-specific values through `with` and `secrets`.

## Workflow map

| Consumer need | Reusable workflow | Reference |
| --- | --- | --- |
| Plan or apply backend infrastructure | `deploy-backend-infra.yml` | [Backend infrastructure](backend-workflows.md#backend-infrastructure) |
| Deploy a backend release | `deploy-backend.yml` | [Backend delivery](backend-workflows.md#backend-deployment) |
| Roll back a backend release | `rollback-backend.yml` | [Backend delivery](backend-workflows.md#backend-rollback) |
| Deploy a frontend | `deploy-frontend.yml` | [Frontend workflows](frontend-workflows.md#frontend-deployment) |
| Roll back a frontend | `rollback-frontend.yml` | [Frontend workflows](frontend-workflows.md#frontend-rollback) |
| Stop or destroy non-production backend | `kill-non-production.yml` | [Lifecycle workflows](operational-workflows.md#backend-lifecycle) |
| Destroy or nuke non-production frontend | `kill-frontend-non-production.yml` | [Lifecycle workflows](operational-workflows.md#frontend-lifecycle) |
| Build a host AMI | `build-backend-ami.yml` | [Operational workflows](operational-workflows.md#host-ami-build) |
| Bootstrap runtime parameters | `bootstrap-backend-parameters.yml` | [Operational workflows](operational-workflows.md#runtime-parameters) |
| Synchronize GitHub environment values | `sync-github-environment.yml` | [Operational workflows](operational-workflows.md#github-environment-synchronization) |

## Caller template

Create the caller in the consumer repository. The caller is responsible for
choosing its trigger and protected environment; the reusable workflow provides
the job implementation:

```yaml
name: Consumer backend infrastructure

on:
  workflow_dispatch:
    inputs:
      environment:
        required: true
        type: choice
        options: [staging, production]

jobs:
  infrastructure:
    uses: kanutocd/poorman-aws/.github/workflows/deploy-backend-infra.yml@v0.1.0
    with:
      infrastructure_repository: kanutocd/poorman-aws
      infrastructure_ref: v0.1.0
      application_name: example-app
      environment: ${{ inputs.environment }}
      aws_region: ap-southeast-1
      state_bucket: example-app-tofu-state
      availability_zone: ap-southeast-1a
      ssm_parameter_path: /example-app/${{ inputs.environment }}
      route53_zone_name: example.test
    secrets:
      aws_role_arn: ${{ secrets.AWS_BACKEND_ROLE_ARN }}
      ami_id: ${{ secrets.AMI_ID }}
```

Use `secrets: inherit` only when the caller and reusable workflow have an
intentional shared secret boundary. Explicit secret mappings make the role and
secret contract easier to review.

## Shared contract

### Immutable references

`infrastructure_ref` selects the `poorman-aws` source checked out by the
workflow. Use a release tag such as `v0.1.0` or a full commit SHA. Production
workflows reject `main` and `master`; pinning immutable refs for every
environment is recommended.

Rollback workflows also receive `consumer_ref`, which identifies the known-good
consumer revision to check out. Do not use the current branch as an implicit
rollback source.

### AWS authentication

AWS workflows request `id-token: write` and use
`aws-actions/configure-aws-credentials` with a consumer-provided role secret.
The backend and frontend roles should remain separate. Do not replace OIDC
with long-lived AWS keys in workflow inputs or repository variables.

### Environment protection

The reusable jobs select the environment named by the input. Configure required
reviewers, deployment branches, and environment secrets in the consumer
repository. A workflow input is not a substitute for GitHub environment
protection.

### Secrets and generated files

Pass secret values through named workflow secrets. Do not put them in `with`
inputs, committed YAML, release artifacts, frontend assets, logs, plans, or
workflow summaries. The workflows write temporary files under the runner's
temporary directory and run the repository scripts that enforce the relevant
parsing and redaction rules.

### Permissions and actions

The workflows declare least-privilege `contents` and OIDC permissions and pin
third-party actions to immutable revisions. Keep caller permissions and role
trust policies narrow enough for the selected repository, branch, and
environment.

## Calling from the wrapper

The `bin/poorman-aws` wrapper dispatches the generated or existing consumer
caller workflows for infrastructure, backend delivery, frontend delivery,
lifecycle, AMI, and parameter operations. Use the wrapper when you want a
consistent local or `curl | bash` command surface. Call the reusable workflow
directly when the consumer already maintains an explicit caller workflow.

Use [Backend workflows](backend-workflows.md), [Frontend workflows](frontend-workflows.md),
and [Operational workflows](operational-workflows.md) for the individual input
contracts.
