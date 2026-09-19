# poorman-aws

Cost-conscious AWS infrastructure building blocks for small production
deployments.

This repository is the extracted home for cost-conscious AWS infrastructure
used by reference applications. It preserves the working OpenTofu, Packer, and
operational shell implementations while keeping application identity and
runtime values configurable.

## Project purpose

`poorman-aws` provides small, cost-conscious AWS infrastructure primitives for
projects that need a simple public application host without managed NAT or
load-balancer costs. Application-specific runtime assets and deployment
contracts belong to the consuming repository.

## Consumer shapes

This repository supports three deployment shapes. Choose the smallest shape
that matches the application rather than provisioning unused resources:

- **Backend and frontend:** use the backend OpenTofu stack for the public API,
  then call the reusable frontend workflows for the consumer-owned SPA,
  CloudFront distribution, S3 assets, certificate, and frontend DNS alias.
  The frontend may receive `API_BASE_URL` when it calls the deployed API.
- **Backend only:** use the backend stack, Packer profile, backend release
  workflows, and lifecycle scripts without configuring any frontend workflow or
  frontend hosting resources.
- **Frontend only:** use the reusable frontend deployment and rollback
  workflows for a static site without creating the backend stack. `API_BASE_URL`
  is optional; omit it when the frontend has no API dependency or points to an
  API managed elsewhere.

The consuming repository owns application code, caller workflows, runtime
configuration, and any frontend resources created by its deployment command.
The backend and frontend paths are independent, so a frontend-only deployment
does not require backend state, credentials, or DNS records.

## Current layout

- `backend/` contains the single-public-EC2-host OpenTofu stack, deployment
  artifact storage, DNS/TLS integration, host bootstrap, and Packer profile.
- There is no `frontend/` application or concrete frontend stack directory in
  this repository. For full-stack and frontend-only consumers, frontend
  hosting IaC is delivered as reusable
  `.github/workflows/deploy-frontend.yml` and
  `.github/workflows/rollback-frontend.yml` workflows; the consumer supplies
  its frontend code, hosting configuration, and deployment commands.
- `bin/` contains local operational utilities for parameter bootstrapping,
  GitHub OIDC setup, backend release delivery, live smoke checks, and
  non-production lifecycle actions. `bin/sync-github-environment` uses the
  GitHub CLI to apply the same environment variables and secrets locally or
  from GitHub Actions.
- `.github/workflows/` contains repository quality checks and reusable
  infrastructure-delivery workflows that consumers can call without cloning
  this repository.

## Extraction boundary

The OpenTofu implementation is application-neutral at the reusable boundary.
Project names, environment names, resource tags, hostnames, SSM paths, IAM
policy scopes, and deployment artifact conventions are supplied by the
consuming environment rather than embedded as product identity.

The repository remains a set of reusable infrastructure building blocks, not a
single application deployment. Consumer-specific values belong in ignored
variable files, GitHub environment configuration, or the consuming repository.

Do not commit generated state, plans, local variable files, Packer manifests,
or populated environment files. Use the example files as templates only.

## Repository prerequisites

Quality-tool prerequisites and the local/CI execution boundary are documented
in [`docs/mkdocs/quality.md`](docs/mkdocs/quality.md). Infrastructure change review
requirements are documented in
[`docs/mkdocs/change-management.md`](docs/mkdocs/change-management.md).

These prerequisites apply only when contributing to or running quality checks
from a local clone of this `poorman-aws` repository. A consumer using the
versioned OpenTofu modules, scripts, or reusable workflows does not need to
clone this repository or install every tool listed here; install only the
tools required by the integration path you use.

Install the tools required for the local checks or operations you intend to
run:

- OpenTofu `1.8+`
- Bash, ShellCheck, and actionlint
- Packer `1.11+` when building an AMI
- AWS CLI v2 for AWS operations
- GitHub CLI (`gh`) for GitHub environment synchronization

Verify the required sessions and tooling before running the checks:

```bash
tofu version
# Required only for AWS operations:
aws sts get-caller-identity
# Required only for local GitHub environment synchronization:
gh auth status
```

Then run:

## Quality checks

```bash
bash bin/quality
```

The command checks OpenTofu formatting, validation, and plan-only mocked module
tests; Docker Compose configuration; Packer formatting and validation; Bash
syntax; ShellCheck warnings; generated-artifact hygiene; and common credential
patterns. CI runs the same checks in separate jobs through
`.github/workflows/quality.yml`.

OpenTofu tests use mocked providers and `command = plan`; they must not create
real AWS resources in CI.

## GitHub environment configuration

Configure a consumer repository environment through any of these supported
paths:

In the examples below, `CONSUMER_OWNER/CONSUMER_REPOSITORY` means the GitHub
repository that consumes `poorman-aws`. Replace it with that repository's
actual owner and name; it is not the `poorman-aws` repository unless you are
configuring this project itself.

1. Use `bin/sync-github-environment` locally to avoid putting secret values on
   a command line or in logs. Keep non-sensitive variables and sensitive values
   in separate private files:

```bash
cp backend/github-environment.variables.env.example /tmp/project-staging.variables.env
cp backend/github-environment.secrets.env.example /tmp/project-staging.secrets.env

bin/sync-github-environment \
  --repo CONSUMER_OWNER/CONSUMER_REPOSITORY \
  --environment staging \
  --variables-file /tmp/project-staging.variables.env \
  --secrets-file /tmp/project-staging.secrets.env \
  --apply
```

The command is a dry run unless `--apply` is provided. It creates the
environment, then uses `gh variable set` and `gh secret set` with standard
input. Locally, authenticate with `gh auth login`; in GitHub Actions, provide
`GH_TOKEN` or `GITHUB_TOKEN` and grant the job the repository permissions needed
to manage environments, variables, and secrets. The same command and inputs
are used in both contexts.

Never put credentials in the variables file. The parser does not source files
as shell code, rejects empty values and duplicate keys, and prints names only.

2. Configure an environment manually in GitHub: open
`CONSUMER_OWNER/CONSUMER_REPOSITORY` → **Settings** → **Secrets and variables**
→ **Actions**,
select the target environment, and add non-sensitive values under **Variables**
and credentials under **Secrets**. Use the same names as the example files.
Manual entry is equivalent to `bin/sync-github-environment`; keep secret values
out of command arguments, logs, and frontend assets.

Frontend consumers may also synchronize the optional non-sensitive
`API_BASE_URL` variable:

```bash
bin/sync-github-environment \
  --repo CONSUMER_OWNER/CONSUMER_REPOSITORY \
  --environment staging \
  --variables-file examples/frontend-environment.variables.env.example \
  --apply
```

`API_BASE_URL` configures where an SPA sends API requests; it does not create a
backend dependency. A frontend can still be deployed as a static site when
the variable is omitted or the backend is unavailable.

3. Consumers that do not clone this repository can call the reusable
   `.github/workflows/sync-github-environment.yml` workflow:

```yaml
jobs:
  configure-environment:
    uses: kanutocd/poorman-aws/.github/workflows/sync-github-environment.yml@v0.1.0
    with:
      source_repository: kanutocd/poorman-aws
      source_ref: v0.1.0
      environment: staging
      variables_dotenv: |
        AWS_REGION=ap-southeast-1
        API_BASE_URL=https://api.example.test
    secrets:
      environment_admin_token: ${{ secrets.ENVIRONMENT_ADMIN_TOKEN }}
      environment_secrets: ${{ secrets.STAGING_ENVIRONMENT_SECRETS }}
```

The caller must provide `environment_admin_token` or grant the called workflow's
`GITHUB_TOKEN` the ability to manage repository environments, variables, and
secrets. Keep `environment_secrets` as a protected multiline secret; never
pass secret values through `with` inputs.

## Consumer wrapper

The consumer wrapper provides a common contract for cloned and remote
consumption. It validates prerequisites and can onboard a consumer by writing
only non-secret configuration plus thin caller workflows; the reusable
workflows, OpenTofu modules, and operational scripts remain owned by
`poorman-aws`.

From a clone:

```bash
./bin/poorman-aws doctor
./bin/poorman-aws config validate --config .poorman-aws.yml
./bin/poorman-aws onboard
```

Use `doctor --offline` for local-only checks. Add `--aws`, `--docker`,
`--infra`, `--ami`, or `--github` to check the corresponding external or
toolchain prerequisites. The doctor inspects the consumer-owned Compose file,
Caddyfile, Dockerfile, and build context without assuming service names or
topology. It prints remediation hints without mutating AWS or repository
files. A generic reverse-proxy starting point is available at
[`examples/Caddyfile.example`](examples/Caddyfile.example); consumers can
adapt its hostname, upstream service name, and port. It is suggested because
Caddy provides a useful working HTTPS boundary: it obtains and renews ACME
certificates, terminates public TLS, and proxies HTTP to the consumer's
private application service, so the application does not need to implement
public certificate management itself.

From an immutable release reference:

```bash
curl -fsSL \
  https://raw.githubusercontent.com/kanutocd/poorman-aws/refs/tags/v0.1.0/bin/poorman-aws \
  | bash -s -- doctor
```

Onboarding can be run from a pinned release in the same way. Use
`--non-interactive` with required values supplied by CLI options or an explicit
`--config`; command-line values always override YAML values:

```bash
curl -fsSL \
  https://raw.githubusercontent.com/kanutocd/poorman-aws/refs/tags/v0.1.0/bin/poorman-aws \
  | bash -s -- --non-interactive onboard \
      --application-name my-app \
      --infrastructure-ref v0.1.0 \
      --state-bucket my-app-tofu-state
```

Onboarding is idempotent when generated files are unchanged. Differing
consumer-owned files cause a conflict and are never overwritten unless
`--overwrite` is explicitly supplied after review. `--dry-run` previews the
files without writing them.

After onboarding, operational adapters dispatch the generated consumer callers
through GitHub CLI. Plans are non-mutating; applies, releases, rollbacks,
parameter writes, and lifecycle actions require explicit `--apply` and the
action-specific `--confirm` phrase. Production data-volume retention and
backup inputs default on and are enforced by the reusable OpenTofu workflow;
the lifecycle adapter is restricted to staging.

Examples:

```bash
./bin/poorman-aws plan --environment staging
./bin/poorman-aws release --environment staging --apply \
  --confirm RELEASE-STAGING
./bin/poorman-aws rollback --environment staging --release-id abc1234 \
  --apply --confirm ROLLBACK-STAGING
./bin/poorman-aws lifecycle --action STOP
./bin/poorman-aws frontend smoke
./bin/poorman-aws frontend deploy --environment staging \
  --apply --confirm FRONTEND-DEPLOY-STAGING
./bin/poorman-aws frontend rollback --environment staging \
  --consumer-ref 0123456789abcdef0123456789abcdef01234567 \
  --apply --confirm FRONTEND-ROLLBACK-STAGING
./bin/poorman-aws frontend lifecycle --action DESTROY \
  --consumer-ref 0123456789abcdef0123456789abcdef01234567 \
  --apply --confirm FRONTEND-DESTROY-STAGING
```

Frontend adapters use the consumer's configured build, deploy, and removal
commands while keeping workflow orchestration, smoke checks, immutable ref
guards, and frontend-only AWS role boundaries in `poorman-aws`. `frontend
smoke` is non-mutating and does not require AWS or GitHub credentials. Deploy,
rollback, and lifecycle commands require an immutable infrastructure ref;
rollback and lifecycle also require an immutable consumer ref.

When frontend settings are present in `.poorman-aws.yml`, onboarding generates
thin frontend deploy, rollback, and guarded lifecycle callers alongside the
backend callers. The wrapper's configuration precedence remains built-in
defaults, YAML configuration, then command-line options.

Supplemental consumer release files can be configured as comma-separated
`DEST=PATH` entries under `backend.supplemental_files`, or supplied with
`--release-file DEST=PATH`. They are checksummed in the immutable release
manifest and downloaded only after manifest validation; paths cannot escape the
release directory or replace reserved artifacts.

The wrapper discovers `.poorman-aws.yml` or `.poorman-aws.yaml`, or accepts an
explicit `--config PATH`. Precedence is built-in defaults, discovered or
explicit YAML, then command-line options. Configuration is restricted to
non-secret consumer and infrastructure settings; secrets must come from
protected environments or runtime credentials. Production usage should pin a
release and verify its checksum instead of piping a floating branch to Bash.

For production, prefer downloading and reviewing the versioned wrapper artifact
before executing it:

```bash
release=v0.1.0
base="https://github.com/kanutocd/poorman-aws/releases/download/$release"
curl -fL -o "poorman-aws-$release" "$base/poorman-aws-$release"
curl -fL -o "poorman-aws-$release.sha256" "$base/poorman-aws-$release.sha256"
sha256sum -c "poorman-aws-$release.sha256"
bash "poorman-aws-$release" doctor --offline
```

The release workflow creates the wrapper, checksum, and release notes from the
tagged source. Cloning the exact tag and invoking `bin/poorman-aws` is an
equivalent alternative. `curl | bash` remains useful for exploratory work,
but it should be limited to reviewed immutable references and is less
auditable than checksum verification.

## Reusable workflows

The repository publishes these consumer-facing `workflow_call` entry points:

- `.github/workflows/build-backend-ami.yml`
- `.github/workflows/deploy-backend-infra.yml`
- `.github/workflows/deploy-backend.yml`
- `.github/workflows/rollback-backend.yml`
- `.github/workflows/deploy-frontend.yml`
- `.github/workflows/rollback-frontend.yml`
- `.github/workflows/kill-frontend-non-production.yml`
- `.github/workflows/kill-non-production.yml`
- `.github/workflows/bootstrap-backend-parameters.yml`
- `.github/workflows/sync-github-environment.yml`

`.github/workflows/quality.yml` is repository-local quality automation. It is
not a reusable consumer deployment workflow; consumers should run equivalent
quality checks in their own repositories or invoke the documented commands
locally.

These workflows do not contain application-specific domains, paths, package
managers, or deployment frameworks. A caller passes the consumer repository's
application name, environment, URLs, state configuration, and AWS role secret.
Backend workflows use the reusable OpenTofu and release scripts checked out at
the requested `infrastructure_repository` and `infrastructure_ref`. Frontend
workflows receive explicit consumer-owned build and deploy commands, so a
consumer may use its own static hosting tool without coupling this repository
to a particular framework.

The workflows are reusable entry points, not standalone `workflow_dispatch`
interfaces. A consuming repository should provide its own thin dispatch or
push-triggered caller workflow and map protected environment values to the
declared `with` inputs and `secrets`:

```yaml
jobs:
  deploy-backend:
    uses: kanutocd/poorman-aws/.github/workflows/deploy-backend.yml@v0.1.0
    with:
      infrastructure_repository: kanutocd/poorman-aws
      infrastructure_ref: v0.1.0
      application_name: application
      environment: staging
      aws_region: ap-southeast-1
      state_bucket: application-tofu-state-example
      api_url: https://api.staging.example.test
      compose_file: backend/compose.production.yaml
      caddy_file: backend/Caddyfile
      build_context: backend
      dockerfile: backend/Dockerfile
    secrets:
      aws_role_arn: ${{ secrets.AWS_ROLE_ARN }}
```

The consumer remains responsible for exposing the caller trigger, selecting
the correct protected environment, and providing environment-specific secret
mappings. The reusable workflow never receives secrets through normal `with`
inputs. All reusable infrastructure/source refs are required explicitly;
production and lifecycle workflows reject `main` and `master`.

## Versioning reusable workflows

Reusable workflows are versioned with the repository because their workflow
files, scripts, OpenTofu modules, and input contracts must remain compatible.
Consumers should call a release tag rather than `main`:

```yaml
uses: kanutocd/poorman-aws/.github/workflows/deploy-backend.yml@v0.1.0
```

Here, `kanutocd/poorman-aws` is the publisher's repository. It is
different from `CONSUMER_OWNER/CONSUMER_REPOSITORY`, which identifies the
repository calling the reusable workflow.

Use the following policy when publishing and consuming releases:

- Publish an immutable annotated tag for every release, following SemVer.
- Treat input removals, renamed inputs, changed secret names, changed output
  meanings, and changed destructive-operation behavior as breaking changes.
- During the `0.x` series, treat minor-version releases as potentially
  breaking; reserve patch releases for compatible fixes and documentation.
- Consumers should pin an exact release tag in production and upgrade it
  deliberately after reviewing the changelog. Do not use `main`, a mutable
  floating tag, or an unreviewed commit for production deployment.
- During dogfooding or pre-release testing, use the full tested commit SHA in
  both the reusable-workflow `uses` ref and the `infrastructure_ref` input.
- Maintainers may provide a moving major compatibility tag such as `v1` only
  when its update process is documented and protected; an exact release tag
  remains the safer default for infrastructure.
- Use the published major release tag for each third-party action used inside
  these workflows, such as `actions/checkout@v7`. Keep the action reference
  aligned with the supported release documented by the action publisher.
- Keep workflow inputs application-neutral and add new optional inputs before
  requiring breaking contract changes. Document every contract change in
  `CHANGELOG.md`.

## Architecture

See [`docs/mkdocs/architecture.md`](docs/mkdocs/architecture.md) for the current system
context, AWS network topology, browser/API request flow, release activation
flow, secret flow, administrative access path, and lifecycle states.

## Available public interfaces

The reusable project provides:

- versioned OpenTofu modules for cost-conscious AWS hosting;
- quality, environment-synchronization, AMI, infrastructure, release, rollback,
  frontend, and lifecycle GitHub Actions workflows;
- reusable scripts for local and workflow-based operations;
- consumer-specific examples that keep application identity and secrets in the
  consuming repository.

## Status

The initial extraction is complete. Generic naming, configurable runtime
contracts, reusable workflows, and public-release documentation are part of the
OpenTofu boundary described above.
