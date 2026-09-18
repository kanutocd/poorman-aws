# Operational workflows

These workflows cover host-image creation, runtime parameter management,
non-production lifecycle actions, and GitHub environment synchronization.

## Host AMI build

Workflow: `.github/workflows/build-backend-ami.yml`

The workflow builds an ARM64 application-host AMI with Packer and uploads a
redacted manifest as a workflow artifact. Required inputs are:

- `infrastructure_repository` and immutable `infrastructure_ref`;
- `application_name`;
- `aws_region`;
- `subnet_id` for the temporary public builder; and
- `ssh_cidr`, restricted to the operator's temporary builder access range.

`ami_name_prefix` is also required. The `aws_role_arn` secret must be a
temporary, narrowly scoped AMI-build role. The workflow runs in the protected
`ami-build` environment and does not build an application image.

The wrapper equivalent is:

```bash
bin/poorman-aws --dry-run ami build \
  --subnet-id SUBNET_ID \
  --ssh-cidr BUILDER_CIDR
```

Review the dispatch inputs and then remove `--dry-run` to start the build.

## Runtime parameters

Workflow: `.github/workflows/bootstrap-backend-parameters.yml`

Use this workflow to preview or write application runtime parameters to SSM
Parameter Store. Required inputs are `infrastructure_repository`, immutable
`infrastructure_ref`, `application_name`, `environment`, `aws_region`, and
`parameter_path`. Set `apply: true` only after reviewing the parameter names
and target environment.

The required `aws_role_arn` secret must be allowed to manage the selected SSM
path. The optional `environment_parameters` secret contains newline-delimited
`NAME=VALUE` entries. List names that should be stored as non-secret String
parameters in `non_secret_parameters`; all other values use the protected
parameter path and the script's secret-handling rules. `clear_parameter` can
remove one explicitly named uppercase parameter.

The wrapper's `parameters` command can preview or dispatch this workflow. A
local `--from-env-file` operation requires a cloned wrapper because the local
parameter script is not available to a piped wrapper.

## Backend lifecycle

Workflow: `.github/workflows/kill-non-production.yml`

This workflow supports `STOP`, `DESTROY`, and `NUKE` for staging only. Required
inputs include `infrastructure_repository`, immutable `infrastructure_ref`,
`application_name`, `environment`, `action`, `confirmation`, `aws_region`,
`state_bucket`, `availability_zone`, `ssm_parameter_path`, and
`route53_zone_name`. The `aws_role_arn` and `ami_id` secrets are required.

The workflow accepts the same host and retention inputs as infrastructure
deployment, including defaults of `t4g.micro`, 10 GiB root, 20 GiB data, EIP
retention, data-volume retention, 30-day release retention, and enabled backup
configuration. Production is rejected. `NUKE` is the most destructive action
and requires the exact action-specific confirmation.

Use the wrapper's `lifecycle` command to preview and confirm the dispatch.

## Frontend lifecycle

Workflow: `.github/workflows/kill-frontend-non-production.yml`

This workflow supports `DESTROY` and `NUKE` for non-production frontend
resources. Required inputs are `infrastructure_repository`, immutable
`infrastructure_ref`, `application_name`, `environment`, `action`,
`confirmation`, `aws_region`, `frontend_hostname`, and immutable `consumer_ref`.
The optional `frontend_directory` defaults to `frontend`; the consumer removal
command is used only by applied `NUKE`. The required `aws_role_arn` secret must
be frontend-only.

Production is rejected before dispatch. Use `frontend lifecycle` in the wrapper
to enforce the same guard and confirmation contract locally.

## GitHub environment synchronization

Workflow: `.github/workflows/sync-github-environment.yml`

This workflow creates or updates a consumer repository environment. It is
called with:

| Input or secret | Required | Meaning |
| --- | --- | --- |
| `source_repository` | Yes | Repository containing the synchronizer. |
| `source_ref` | Yes | Immutable synchronizer tag or SHA. |
| `environment` | Yes | Target consumer environment. |
| `variables_dotenv` | No | Newline-delimited non-sensitive `KEY=VALUE` values. |
| `environment_admin_token` | No | Token allowed to manage environment values. |
| `environment_secrets` | No | Protected newline-delimited secret entries. |

The workflow rejects `main` and `master` as `source_ref`. The reserved secret
name `github_token` must not be used; pass `environment_admin_token` when the
default workflow token does not have the required repository permissions.

This workflow is separate from the `bin/poorman-aws` wrapper. Use
`bin/sync-github-environment` locally or call this reusable workflow directly;
`onboard` generates callers that consume environment values but does not create
the GitHub environment itself.
