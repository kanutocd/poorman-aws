# application backend infrastructure

This OpenTofu root provisions the cost-optimized backend foundation for one
application environment. It is intentionally independent from frontend state
and from any developer checkout of the consuming application.

The current OpenTofu root provisions:

- one VPC, public subnet, route table, and Internet Gateway;
- one small EC2 backend host with an OpenTofu-managed Elastic IP;
- one encrypted data EBS volume mounted separately from the disposable root;
- public ingress only on ports `80` and `443`;
- AWS Systems Manager Session Manager access with no public SSH ingress;
- an S3 gateway endpoint for AWS artifact access;
- a private, encrypted, versioned S3 release bucket;
- an instance role limited to the environment's artifact prefix and SSM path,
  plus the AWS-managed Session Manager policy;
- an environment-specific API Route 53 record.

Frontend infrastructure is deliberately outside this root. A frontend stack
owns its S3 bucket, CloudFront distribution, `app.<domain>` alias, and
us-east-1 ACM certificate. This backend root consumes no frontend state and can
be applied before or after a static frontend deployment.

### Existing state migration

If an older backend state managed frontend ACM or CloudFront DNS resources,
do not apply this backend configuration immediately. First import or adopt
those resources in the frontend stack, verify that frontend deployment is
healthy, then inspect the backend state:

```bash
tofu state list | grep 'module.dns_tls.*frontend'
```

After ownership is confirmed in the frontend stack, remove only the obsolete
frontend addresses from the backend state with `tofu state rm`, then run
`tofu plan` and confirm that the backend plan manages only the API record. The
shared Route 53 hosted zone must not be removed. Never use a backend destroy
plan as the migration mechanism.

The OpenTofu-managed EIP remains allocated and associated while the EC2
environment exists, including when the instance is stopped and during normal
instance replacement. Set `retain_eip = true` to preserve that same address
when a guarded non-production `DESTROY` terminates the environment. Set it to
`false` when a non-production teardown may release the address; the EIP is
still retained during `STOP` and ordinary applies, then released only by the
guarded destructive path. Production plans reject `retain_eip = false`.

The root EBS volume is always encrypted, defaults to `10 GiB`, and is deleted
when its EC2 instance is terminated. Set `root_volume_size_gib` to customize
its size. The separate encrypted data EBS volume defaults to `20 GiB`; set
`data_volume_size_gib` to customize it. Set `retain_data_volume = true` to
preserve the data volume across host termination and replacement. Set it to
`false` for a disposable data volume. Retention is independent of `retain_eip`: a
non-production environment can retain its data volume across destructive
teardown while releasing its EIP, or release both. Production plans reject
`retain_data_volume = false`.

The reviewed Packer AMI also uses a `10 GiB` root volume. Changing this size
does not shrink an existing root volume; rebuild the AMI and apply the updated
`ami_id` to replace the host with the smaller root volume.

The retained data volume is protected from accidental OpenTofu destruction and
is attached to the replacement host by the compute module. The volume is
mounted at `/srv/application-data` and Docker state is stored beneath that mount.
Production enables AWS Backup by default: daily snapshots are retained for 7
days and weekly snapshots for 28 days. Set `backup_kms_key_arn` to use an
approved customer-managed key; otherwise the AWS Backup vault uses its default
AWS Backup encryption. Backup restore rehearsals remain required before
claiming a recovery objective.

Verify the allocation after planning or applying with:

```bash
tofu output api_eip_allocation_id
tofu output data_volume_id
```

The consuming repository supplies the Compose and Caddy runtime artifacts for
each immutable S3 release. The activation contract is a release-specific
`compose.yaml`, `Caddyfile`, release-tagged application image archive, and
`manifest.json`. The host refuses to activate a release missing any of these
artifacts.

The application container, any consumer-defined dependencies, and the Caddy
reverse proxy run as Docker Compose services on the host. Dependent services
must not be individually exposed by the consumer's Compose file. Caddy owns
public ports `80` and `443`, obtains the API certificate through ACME/Let's
Encrypt, and persists its certificate state in the environment's Compose
volume. That named volume survives Compose container and release restarts, but
currently resides on the root EBS volume. It is not automatically restored
onto a replacement host; use durable backups or the retained data EBS volume
if that state becomes important.

## Prerequisites

- OpenTofu `1.8+`;
- an AWS account, target region, and AWS credentials with permission to
  manage the resources in this root;
- a reviewed AMI with Docker and Docker Compose installed;
- an existing encrypted S3 bucket for OpenTofu remote state;
- a public Route 53 hosted zone for `application.app` (or the configured
  `route53_zone_name`);
- a DNS A record resolving the environment API hostname to the host before
  the first Compose activation; and
- the AWS CLI Session Manager plugin on the operator workstation.

The default `t4g.micro` instance requires an ARM64-compatible AMI. Override
`instance_type` when the reviewed image uses another architecture. The
`instance_type`, `root_volume_size_gib`, and `data_volume_size_gib` values can
also be supplied as inputs to the reusable infrastructure workflow for each
environment.

To build the reviewed host AMI instead of using an existing one, also install
Packer `1.11+` using the instructions in
[`packer/README.md`](packer/README.md#install-packer), configure AWS
credentials, select a public build subnet, and provide a narrow `ssh_cidr`.
OpenTofu consumes the resulting AMI ID; application releases do not require
rebuilding this image.

### GitHub Actions OIDC bootstrap

The workflows use short-lived AWS credentials through GitHub Actions OIDC;
they do not create the AWS identity provider or IAM roles. An AWS administrator
must configure these once, outside this root:

- the GitHub OIDC identity provider for `token.actions.githubusercontent.com`
  with the `sts.amazonaws.com` audience;
- separate IAM roles for the `staging`, `production`, and `ami-build` GitHub
  environments, with trust conditions restricted to this repository and the
  intended environment/ref claims;
- permissions for each role constrained to its environment's state, artifact,
  DNS, and deployment region, or to the temporary Packer AMI build resources;
- the corresponding role ARN stored as the `AWS_ROLE_ARN` secret in each
  GitHub environment.

The infrastructure workflow also requires its environment variables for the
AWS region, Availability Zone, state bucket, and Route 53 zone. Configure
production reviewers on the GitHub environment rather than placing long-lived
AWS access keys in repository secrets.

Use the local bootstrap utility with an AWS administrator profile. It is a
dry run unless `--apply` is supplied:

```bash
cd /path/to/application-infrastructure
AWS_PROFILE=administrator bin/bootstrap-github-oidc \
  --repo CONSUMER_OWNER/CONSUMER_REPOSITORY \
  --state-bucket EXISTING_STATE_BUCKET \
  --route53-zone-id ZONE_ID

AWS_PROFILE=administrator bin/bootstrap-github-oidc \
  --repo CONSUMER_OWNER/CONSUMER_REPOSITORY \
  --state-bucket EXISTING_STATE_BUCKET \
  --route53-zone-id ZONE_ID \
  --apply
```

The utility is idempotent and creates or updates the account-level OIDC
provider, the `staging`, `production`, and `ami-build` IAM roles, and their
inline workflow policies. Add `--create-hosted-zone --route53-zone-name
application.app` to create or reuse the public zone during the same local
bootstrap:

```bash
AWS_PROFILE=administrator bin/bootstrap-github-oidc \
  --repo CONSUMER_OWNER/CONSUMER_REPOSITORY \
  --state-bucket EXISTING_STATE_BUCKET \
  --route53-zone-name application.app \
  --create-hosted-zone \
  --apply
```

The command prints the name servers that must be delegated at the registrar.
It prints each backend role ARN for the matching GitHub environment's
`AWS_ROLE_ARN` secret. It does not call the GitHub API or create GitHub
environments. Review the generated permissions before production use; custom
artifact bucket names require corresponding policy updates.

If the consuming repository has a separate frontend deployment, it may create
frontend roles during the shared AWS OIDC bootstrap. Include them explicitly:

```bash
AWS_PROFILE=administrator bin/bootstrap-github-oidc \
  --repo CONSUMER_OWNER/CONSUMER_REPOSITORY \
  --state-bucket EXISTING_STATE_BUCKET \
  --route53-zone-id ZONE_ID \
  --include-frontend-roles \
  --apply
```

This creates or updates `<role-prefix>-frontend-staging` and
`<role-prefix>-frontend-production` (with the default prefix, these are
`application-github-frontend-staging` and
`application-github-frontend-production`). The frontend policies cover frontend
deployment state, frontend asset buckets, CloudFront distributions and
supporting resources,
read-only ACM certificate lookup, and the configured frontend parameter path.
The default frontend bucket prefixes are derived from `application_name`; the
state and asset prefixes and parameter path can be overridden with
`--frontend-state-prefix`, `--frontend-assets-prefix`, and
`--frontend-bucket-prefix`, and `--frontend-parameter-path`.
These frontend roles do not grant EC2, SSM, Route 53, ACM certificate
mutation, or backend artifact permissions. The frontend stack must provision or
receive its certificate and
DNS handoff through its own explicitly configured deployment path. The trust
policy also restricts assumption to the matching
GitHub environment and the repository's `main` branch. It accepts both the
legacy GitHub subject format and the newer immutable owner/repository-ID
subject format.

Store each printed frontend role ARN as the `AWS_FRONTEND_ROLE_ARN` secret in
the matching GitHub `staging` or `production` environment. Keep the existing
backend `AWS_ROLE_ARN` secret unchanged; the backend and frontend workflows
intentionally use different role secrets. Frontend deployment variables such
as `AWS_REGION`, `API_BASE_URL`, and `FRONTEND_CERTIFICATE_ARN` remain separate
from this backend state; this utility does not create GitHub variables or
secrets.

## Plan or apply an environment

Copy the environment examples into ignored local files:

```bash
cd backend
cp environments/staging/backend.hcl.example environments/staging/backend.hcl
cp environments/staging/terraform.tfvars.example environments/staging/terraform.tfvars
```

Replace the state bucket, AMI ID, and Availability Zone. Then initialize and
validate the selected environment:

```bash
tofu init -backend-config=environments/staging/backend.hcl
tofu fmt -check -recursive .
tofu validate
tofu plan -var-file=environments/staging/terraform.tfvars
```

Apply only an explicitly reviewed plan. Use a separate working directory or
state configuration for production:

```bash
tofu init -reconfigure -backend-config=environments/production/backend.hcl
tofu plan -var-file=environments/production/terraform.tfvars -out=production.tfplan
tofu apply production.tfplan
```

Do not commit `backend.hcl`, `terraform.tfvars`, plans, state, or provider
credentials.

For a short-lived staging environment, keep `retain_eip = false` and
`retain_data_volume = false`. `STOP` remains reversible and retains the EIP;
use the guarded `DESTROY` action when verification is complete to release the
EC2 instance, EIP, and disposable data volume. Do not merely stop the
instance when the goal is cost reduction: stopped-instance storage and the
allocated EIP remain billable.

## Non-production kill switch

Use `bin/kill-non-production` for a reversible `STOP`, a cost-focused
`DESTROY`, or a full `NUKE` of the staging environment. It discovers the single
active staging backend by its `Application=application`, `Environment=staging`, and
`Role=backend` tags. All actions are dry runs unless `--apply` and the exact
action-specific confirmation phrase are provided.

```bash
AWS_PROFILE=administrator AWS_REGION=ap-southeast-1 \
  bin/kill-non-production \
  --environment staging \
  --action STOP

AWS_PROFILE=administrator AWS_REGION=ap-southeast-1 \
  bin/kill-non-production \
  --environment staging \
  --action STOP \
  --apply \
  --confirm STOP-STAGING
```

`STOP` preserves the EC2 instance, its stopped root and data EBS volumes, and
the OpenTofu-managed EIP regardless of `retain_eip`. `STOP` does not modify
OpenTofu state, so the address and API DNS record remain stable for a later
start. The operation is idempotent: an already
stopped host is reported and left unchanged, and multiple matching hosts cause
the command to fail closed. Use `--instance-id` when a specific tagged host
must be selected. The optional `--no-wait` flag returns after AWS accepts the
stop request rather than waiting for the `stopped` state.

If staging will be stopped and restarted repeatedly, either value is safe for
the address during that stopped period. Use `retain_eip = true` when the same
EIP must also survive a guarded destructive teardown and later recreation.

Use `DESTROY` when staging will not be reused soon. It first disables the
staging backend's cost-bearing resources, then creates an explicit OpenTofu
destroy plan for the EC2 instance, EIP, root/data EBS volumes, backend artifact
bucket, and API DNS record. It preserves the shared VPC and Route 53 hosted
zone. The frontend stack is not touched. The destructive mode
enables `allow_destructive_destroy` only for non-production state, which
allows deletion of retained staging data and versioned release artifacts.

```bash
AWS_PROFILE=administrator AWS_REGION=ap-southeast-1 \
  bin/kill-non-production \
  --environment staging \
  --action DESTROY \
  --state-bucket application-tofu-state-ACCOUNT_ID

AWS_PROFILE=administrator AWS_REGION=ap-southeast-1 \
  bin/kill-non-production \
  --environment staging \
  --action DESTROY \
  --state-bucket application-tofu-state-ACCOUNT_ID \
  --apply \
  --confirm DESTROY-STAGING
```

The `DESTROY` path requires credentials that can manage the staging OpenTofu
state. It fails closed for production, requires the staging confirmation
phrase, and never targets production state. Frontend lifecycle operations must
be performed by the separate frontend workflow or frontend infrastructure
stack.

Use `NUKE` only when the staging environment must be recreated from scratch.
It requires `NUKE-STAGING` and applies an un-targeted OpenTofu `destroy`
against the staging backend state. This removes the backend VPC and host
resources, artifacts, EIP, EBS volumes, and API DNS record. It does not remove
frontend resources or the shared Route 53 hosted zone. `NUKE` is irreversible
and intentionally fails closed for production.

```bash
AWS_PROFILE=administrator AWS_REGION=ap-southeast-1 \
  bin/kill-non-production \
  --environment staging \
  --action NUKE \
  --state-bucket application-tofu-state-ACCOUNT_ID

AWS_PROFILE=administrator AWS_REGION=ap-southeast-1 \
  bin/kill-non-production \
  --environment staging \
  --action NUKE \
  --state-bucket application-tofu-state-ACCOUNT_ID \
  --apply \
  --confirm NUKE-STAGING
```

The same guarded operation is available through the manually dispatched
`Kill non-production environment` GitHub Actions workflow. Select `staging`,
choose `STOP`, `DESTROY`, or `NUKE`, enter the matching confirmation, and leave
`Actually execute the selected action` disabled for a preview or enable it to
execute the action. All backend lifecycle paths use the backend OIDC role and
GitHub environment protection; they do not need long-lived AWS credentials.
Frontend lifecycle changes belong to a separate frontend workflow.

Stopping is a reversible emergency/off switch, not a full teardown. EBS
volumes, the allocated Elastic IP, S3 artifacts, DNS, and other infrastructure
remain billable or managed. `DESTROY` is the cost-reduction teardown path for
backend resources; it releases the EIP only when `retain_eip=false`, while
shared networking and domain resources remain ready for a later staging
recreation.
`NUKE` is the separate full-environment reset and does not preserve those
resources.

## CI delivery

A consumer repository's infrastructure workflow should run formatting,
initialization, OpenTofu validation, and host-script syntax checks for pull
requests. Its manual dispatch can create or apply a plan for one selected
environment. The selected
GitHub environment supplies `AWS_ROLE_ARN` and `AMI_ID` as secrets and the
  region, Availability Zone, remote-state bucket, and hosted-zone values as
  environment variables.

The reusable workflow authenticates with AWS through GitHub OIDC. It uses separate
state keys and GitHub concurrency groups for `staging` and `production`.
Production should have required reviewers configured on its GitHub environment;
the workflow applies only the exact plan it just created after that approval.
The OIDC deployment role also needs permission to describe the default SSM KMS
key so OpenTofu can render the instance policy; rerun
`bin/bootstrap-github-oidc` after changing that bootstrap policy.
The staging or production application release is deployed separately through a
consumer-owned release workflow using `bin/deploy-backend`. Configure the
matching GitHub environment for that workflow. It resolves the artifact bucket
from the matching OpenTofu state before building the release, so no second
bucket variable is required. The backend deployment role must be
rebootstrapped after policy changes so it can upload releases and invoke SSM
commands.

Populate runtime parameters locally without printing their values:

Start with the versioned template at
`backend/deploy-environment.env.example`, copy it outside the repository,
replace its placeholders, and keep the populated file private.

```bash
AWS_PROFILE=administrator AWS_REGION=ap-southeast-1 \
  bin/bootstrap-backend-parameters \
  --environment staging \
  --from-env-file /path/to/private/application-staging.env

AWS_PROFILE=administrator AWS_REGION=ap-southeast-1 \
  bin/bootstrap-backend-parameters \
  --environment staging \
  --from-env-file /path/to/private/application-staging.env \
  --apply
```

The env file must contain the approved runtime variable names. Provider keys
and runtime values are written as `SecureString` by default. Explicitly pass
`--non-secret NAME` to classify a documented hostname, origin, image name,
model, or other non-secret setting as a `String` parameter.

For an anonymous deployment, remove any previously configured API token instead
of placing an empty value in SSM Parameter Store:

```bash
AWS_PROFILE=administrator AWS_REGION=ap-southeast-1 \
  bin/bootstrap-backend-parameters \
  --environment staging \
  --clear-parameter APPLICATION_API_TOKEN \
  --apply
```

Re-run the backend application deployment workflow after clearing the
parameter. Release activation re-renders the host's runtime environment, so a
token from an earlier release is not retained. Do not place a bearer token in
the public SPA; if `APPLICATION_API_TOKEN` is configured, browser requests must be
authenticated through a server-side user/session design.

The application workflow builds the ARM64 image, uploads the immutable release
to S3, activates it through SSM, and verifies the public API boundary. Frontend
availability is verified independently by the frontend deployment workflow so
backend releases do not depend on a deployed frontend DNS alias. Re-running
the workflow for the same commit safely reuses a complete immutable release;
partial uploads fail closed. Use
the consumer's rollback workflow with a previously published release ID to
perform an explicit rollback.

## Administrative access

The backend host uses AWS Systems Manager Session Manager. Its instance role
includes `AmazonSSMManagedInstanceCore`, the reviewed AMI enables
`amazon-ssm-agent`, and the public security group has no inbound rule for port
`22`; the host bootstrap also masks the `sshd` service. The host uses its
public subnet and Internet Gateway for outbound SSM
connections; no NAT Gateway or long-lived SSH key is required.

After the instance is healthy and registered with Systems Manager, open a shell
with:

```bash
aws ssm start-session \
  --profile administrator \
  --region ap-southeast-1 \
  --target "$(tofu output -raw instance_id)"
```

The `ssm_start_session_command` OpenTofu output prints the equivalent command.
If the instance does not appear in Systems Manager, verify that the AMI has a
running SSM Agent, the instance role is attached, and outbound HTTPS/DNS
access is available. Do not open port `22` to recover the host.

If Session Manager preferences use customer-managed KMS encryption, set
`ssm_session_kms_key_arn` to that key ARN in each environment and configure
the matching `SSM_SESSION_KMS_KEY_ARN` GitHub environment variable. OpenTofu
grants the instance role only `kms:Decrypt` on that exact key. The KMS key
policy must also permit the environment instance role to use the key.

## Current boundary

Runtime SSM parameter provisioning, S3 release upload orchestration, and the
application image deployment workflow are now implemented. The host includes
release activation and runtime parameter rendering scripts installed by
cloud-init. The production Compose release now includes the
Caddy reverse proxy and ACME certificate lifecycle; the first activation must
therefore provide `CADDY_IMAGE`, `ACME_EMAIL`, and `APPLICATION_API_HOSTNAME` as
runtime parameters, and the API DNS record must already resolve to the host.
The frontend certificate and `app.<domain>` alias are owned and provisioned by
the separate frontend stack.

The public subnet is deliberate: the backend must reach configured external
services without a NAT Gateway. Keep Docker, dependent services, and the
backend application's internal listener private to the host; expose only the
Caddy reverse proxy on public ports `80` and `443`.
