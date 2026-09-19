# From zero to staging

This is the shortest complete path for a small application that needs a
cost-conscious AWS deployment. It separates one-time account and repository
setup from the repeatable commands used to plan, release, roll back, and tear
down a staging environment.

The wrapper can be used from a pinned clone or downloaded from a pinned raw
URL. Replace `v0.1.0` with the full commit SHA being dogfooded.

## 1. One-time AWS administrator setup

An AWS administrator prepares the account boundary before the application
repository can deploy. This setup creates the GitHub OIDC provider and
environment-scoped IAM roles. It does not create the GitHub environments or
upload their secrets.

Create or identify these prerequisites first:

- an AWS account and deployment region;
- an encrypted S3 bucket for OpenTofu state;
- a public Route 53 hosted zone; and
- a reviewed ARM64 AMI, or a plan to build one.

Run the bootstrap utility in dry-run mode, review the generated policies, and
then apply it with an administrator profile:

```bash
AWS_PROFILE=administrator \
.poorman-aws/bin/bootstrap-github-oidc \
  --repo OWNER/REPOSITORY \
  --state-bucket STATE_BUCKET \
  --route53-zone-id ZONE_ID

AWS_PROFILE=administrator \
.poorman-aws/bin/bootstrap-github-oidc \
  --repo OWNER/REPOSITORY \
  --state-bucket STATE_BUCKET \
  --route53-zone-id ZONE_ID \
  --apply
```

The bootstrap script can also be fetched without cloning the repository. Keep
the raw URL pinned to a release tag or full commit SHA:

```bash
curl -fsSL \
  https://raw.githubusercontent.com/kanutocd/poorman-aws/refs/tags/v0.1.0/bin/bootstrap-github-oidc \
  | AWS_PROFILE=administrator bash -s -- \
      --repo OWNER/REPOSITORY \
      --state-bucket STATE_BUCKET \
      --route53-zone-id ZONE_ID
```

Add `--apply` only after reviewing the dry-run output. The same command-line
options work when the script is run from a clone.

The bootstrap command is intentionally an explicit administrator operation.
It changes account-level IAM and is not run automatically by ordinary
consumer deployment commands.

See [Configure GitHub environments](../how-to/configure-github-environments.md)
and the [backend bootstrap documentation](https://github.com/kanutocd/poorman-aws/blob/main/backend/README.md#github-actions-oidc-bootstrap)
for policy and role details.

## 2. One-time consumer repository setup

Choose either consumption mode.

### Clone mode

```bash
git clone --branch v0.1.0 --depth 1 \
  https://github.com/kanutocd/poorman-aws.git .poorman-aws

.poorman-aws/bin/poorman-aws install --offline
```

### Piped wrapper mode

```bash
curl -fsSL \
  https://raw.githubusercontent.com/kanutocd/poorman-aws/refs/tags/v0.1.0/bin/poorman-aws \
  | bash -s -- install --offline
```

From the consumer repository, configure the non-secret application values in
`.poorman-aws.yml`, then validate and preview onboarding:

```bash
.poorman-aws/bin/poorman-aws config validate --config .poorman-aws.yml
.poorman-aws/bin/poorman-aws onboard --dry-run
```

Review the generated caller workflows and accept them only after confirming
that the application paths, environment names, and deployment commands are
correct. The wrapper pins the generated callers to its own immutable release
tag (`v0.1.0` for the baseline release), including their
`infrastructure_ref`:

```bash
.poorman-aws/bin/poorman-aws onboard
```

Configure the consumer's GitHub `staging` environment with the variables and
secrets printed by the environment setup guidance. The `AWS_ROLE_ARN` secret
must contain the staging role created by the AWS administrator bootstrap.

The environment synchronizer can be run from a clone:

```bash
.poorman-aws/bin/sync-github-environment \
  --repo OWNER/REPOSITORY \
  --environment staging \
  --variables-file /tmp/staging.variables.env \
  --secrets-file /tmp/staging.secrets.env \
  --apply
```

Or fetched directly as a pinned raw script:

```bash
curl -fsSL \
  https://raw.githubusercontent.com/kanutocd/poorman-aws/refs/tags/v0.1.0/bin/sync-github-environment \
  | bash -s -- \
      --repo OWNER/REPOSITORY \
      --environment staging \
      --variables-file /tmp/staging.variables.env \
      --secrets-file /tmp/staging.secrets.env \
      --apply
```

The synchronizer reads secret values from the private file and sends them to
the GitHub CLI over standard input; it does not print those values. Run it
without `--apply` first to review the target repository, environment, and
variable/secret names.

If no suitable AMI exists, follow [Build an AMI](../how-to/build-an-ami.md)
before planning infrastructure.

## 3. Repeatable staging deployment

Run the wrapper doctor with the checks relevant to the deployment:

```bash
.poorman-aws/bin/poorman-aws doctor \
  --aws --docker --infra --github
```

Create and review the protected OpenTofu plan:

```bash
.poorman-aws/bin/poorman-aws plan --environment staging
```

Apply only the reviewed plan:

```bash
.poorman-aws/bin/poorman-aws apply \
  --environment staging \
  --apply \
  --confirm APPLY-STAGING
```

The backend workflow provisions the small single-host foundation, including
the EC2 host, EBS volumes, Elastic IP, artifact bucket, SSM access, and API DNS
record. It does not assume the application's Compose service names or
topology. The consumer supplies its Compose file, Caddyfile, Dockerfile, and
release inputs.

## 4. Repeatable release, rollback, and teardown

Publish an immutable backend release:

```bash
.poorman-aws/bin/poorman-aws release \
  --environment staging \
  --apply \
  --confirm RELEASE-STAGING
```

Rollback to a known-good release when required:

```bash
.poorman-aws/bin/poorman-aws rollback \
  --environment staging \
  --release-id KNOWN_GOOD_RELEASE_ID \
  --apply \
  --confirm ROLLBACK-STAGING
```

Verify the deployed application with the non-mutating smoke adapter:

```bash
.poorman-aws/bin/poorman-aws frontend smoke \
  --frontend-url https://app.staging.example.com \
  --api-url https://api.staging.example.com \
  --frontend-origin https://app.staging.example.com
```

When staging is no longer needed, stop it for a reversible pause or destroy
it to reduce ongoing costs:

```bash
.poorman-aws/bin/poorman-aws lifecycle \
  --action STOP \
  --environment staging

.poorman-aws/bin/poorman-aws lifecycle \
  --action DESTROY \
  --environment staging \
  --apply \
  --confirm DESTROY-STAGING
```

Production uses separate state, protected approvals, retained data volume and
Elastic IP settings, and the recovery policy. Do not use staging teardown
commands for production.

## What remains outside the repeatable wrapper path

The current wrapper does not yet expose direct subcommands for the one-time
AWS OIDC bootstrap or GitHub environment synchronization. Those operations are
already independently consumable from a clone or a pinned raw script through
`bin/bootstrap-github-oidc` and `bin/sync-github-environment`; the future
wrapper adapters are convenience commands, not a prerequisite for dogfooding.

Their future wrapper adapters are recorded in the [deferred wrapper work](../roadmap.md).
