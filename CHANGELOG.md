# Changelog

All notable changes to this project are documented in this file.

## [Unreleased]

### Documentation

- Added a public MkDocs-compatible documentation site with task-oriented
  onboarding, deployment, security, cost, recovery, and contribution guidance.
- Added a complete reusable-workflow reference covering backend infrastructure,
  backend releases and rollbacks, frontend delivery and lifecycle, AMI builds,
  runtime parameters, and GitHub environment synchronization.
- Documented the two supported wrapper consumption modes: invoking a cloned
  `bin/poorman-aws` checkout and piping a pinned raw wrapper release to Bash.
- Added a shared `bin/docs` build, serve, and clean entry point with pinned
  documentation dependencies, Vale, Markdownlint, and offline Lychee checks.
- Updated the GitHub Pages workflow to use the shared strict build, cached
  Python setup, immutable action references, and a separate least-privilege
  Pages deployment job.

### Frontend lifecycle

- Added the generic `bin/frontend-lifecycle` guard for non-production
  CloudFront-backed frontends, supporting dry-run, guarded `DESTROY`/`NUKE`,
  exact action/environment confirmations, production refusal, unique hostname
  matching, CloudFront disable-and-wait ordering, and an optional consumer
  removal command.
- Added the reusable `kill-frontend-non-production` workflow with separate
  frontend OIDC role input, immutable infrastructure and consumer refs, and
  consumer-neutral hostname, directory, and removal-command inputs.
- Added focused lifecycle contract tests covering dry-run, confirmation,
  production refusal, missing and already-disabled distributions, CloudFront
  disablement ordering, and removal-command failure propagation.

### Consumer wrapper

- Documented the implementation plan for generic frontend deploy, rollback,
  smoke, and guarded lifecycle adapters, including configuration precedence,
  safety boundaries, onboarding, validation, and release gates.
- Implemented the generic frontend wrapper adapters for deploy, rollback,
  smoke, and guarded non-production lifecycle operations. Frontend settings
  now participate in YAML/CLI precedence, onboarding generates thin frontend
  callers when configured, and frontend adapter contract tests cover dry-run,
  confirmation, immutable refs, production refusal, dispatch payloads, and
  generated workflow safety.
- Corrected the reusable-workflow inventory to include the frontend lifecycle
  workflow and removed an empty duplicate README heading.
- Documented `v0.1.0` as the baseline release reference and full commit SHAs
  as the required dogfooding/testing reference.
- Hardened every reusable workflow and environment synchronizer against
  floating `main`/`master` refs; infrastructure refs are required and
  production/lifecycle dispatches fail closed on floating refs.
- Onboarding now renders a unified diff of generated files before interactive
  confirmation, while preserving idempotency and conflict protection.
- Added reproducible versioned wrapper packaging with SHA-256 checksums,
  release notes, a tag-triggered GitHub release workflow, and cloned-versus-
  piped execution parity tests.
- Added release-hardening guidance for downloading, verifying, reviewing, and
  executing wrapper artifacts without relying on `curl | bash`.
- Added operational adapters for protected infrastructure plan/apply,
  backend release, rollback, AMI build, runtime parameter, and staging-only
  lifecycle workflow dispatches. Mutating operations require explicit
  confirmation phrases and all adapters support dry-run previews.
- Exposed availability zone, Route 53, volume retention, release retention,
  production backup, and backup KMS settings through the wrapper configuration
  and reusable workflow inputs. Production data-volume retention and backup
  safeguards remain enforced by OpenTofu.
- Added a reusable secure-by-default backend parameter workflow and generic
  supplemental release-artifact support with path validation, checksummed
  manifests, and verified host activation.
- Added onboarding with interactive confirmation, non-interactive
  required-value enforcement, consumer path detection, and useful defaults.
- Added generation of non-secret `.poorman-aws.yml` configuration and thin
  reusable-workflow callers for backend infrastructure, deployment, rollback,
  and AMI workflows. Generated integration is self-contained and never copies
  OpenTofu modules or infrastructure scripts into the consumer repository.
- Added idempotent generation, explicit conflict detection, `--overwrite`,
  `--dry-run`, and fixture coverage for repeated onboarding, protected local
  edits, non-secret output, and interactive prompts.
- Expanded `poorman-aws doctor` with non-mutating prerequisite checks,
  selectable AWS/GitHub/Docker/OpenTofu/Packer checks, consumer file
  inspection, actionable remediation hints, and offline mode. The inspection
  is topology-neutral and does not assume SearXNG or any other Compose
  service.
- Added a generic Caddy reverse-proxy example that consumers can adapt to
  their own application service name and port. Documented its value as an
  optional HTTPS boundary with automatic ACME certificate management, TLS
  termination, and private HTTP proxying to the application.
- Added consumer fixture coverage for repository layout inspection and
  offline doctor behavior.
- Added the `bin/poorman-aws` contract wrapper with strict Bash
  argument handling, YAML configuration discovery, explicit `--config`
  support, command-line-over-configuration precedence, redacted effective
  configuration output, prerequisite checks, and reserved operational
  commands that fail closed until their adapters are implemented.
- Added wrapper fixture coverage for defaults, YAML discovery, explicit
  configuration failures, CLI precedence, JSON output, ambiguous config files,
  and reserved-command safety.

### Added

- Extracted application-neutral AWS infrastructure building blocks for a
  cost-conscious single-host deployment model.
- Added production-only AWS Backup coverage for the retained data EBS volume,
  with daily snapshots retained for 7 days, weekly snapshots retained for 28
  days, optional customer-managed KMS encryption, a 24-hour RPO, and a
  4-hour RTO.
- Added an offline policy contract test covering production destruction
  protection, EC2 action boundaries, Route 53 scoping, release retention,
  backup configuration, and secure runtime-parameter defaults.
- Added reusable `workflow_call` entry points for AMI builds, backend
  infrastructure, backend releases and rollbacks, frontend deployments and
  rollbacks, environment synchronization, and non-production lifecycle
  operations.
- Added support for three consumer shapes: backend and frontend, backend only,
  and frontend only.
- Added configurable OpenTofu networking, compute, encrypted data-volume,
  private artifact-storage, DNS, and IAM boundaries.
- Added SSM-based administration and release activation without requiring
  inbound SSH access.
- Added local and GitHub Actions-compatible utilities for OIDC bootstrap,
  runtime-parameter provisioning, release delivery, smoke checks, environment
  synchronization, and non-production teardown.
- Added architecture, extraction-boundary, Packer, and consumer-integration
  documentation.
- Added the MIT license.

### Changed

- Genericized application names, hostnames, resource names, SSM paths, tags,
  artifact prefixes, and deployment commands so consumers provide their own
  values.
- Added a production-only OpenTofu destroy sentinel so ordinary production
  destroy plans fail closed before resource mutation.
- Made production data-volume backups mandatory in OpenTofu; emergency volume
  removal remains an out-of-band AWS CLI/console operation.
- Added a 30-day default expiration for current immutable release objects;
  noncurrent versions continue to expire after 30 days and incomplete
  multipart uploads after one day.
- Added a production recovery runbook covering the 24-hour RPO, 4-hour RTO,
  retained data-volume restore, Docker/Caddy state coverage, release rollback,
  and quarterly restore rehearsals.
- Pinned all GitHub Actions to immutable commit SHAs or digests and added the
  `workflow_action_pin_test.sh` check to local and CI quality enforcement.
- Added quality-tooling and infrastructure change-management documentation,
  including local OpenTofu/Packer limitations and review requirements for IAM,
  lifecycle, retention, recovery, and workflow changes.
- Added plan-only artifact lifecycle assertions for the 30-day current and
  noncurrent release retention windows, and clarified that Docker/Caddy state
  is recovered from the durable data EBS volume.
- Changed runtime parameter provisioning to use `SecureString` by default;
  non-secret values now require an explicit repeated `--non-secret NAME`
  declaration.
- Replaced the GitHub deployment policy's wildcard `ec2:*` action with an
  explicit EC2 operation allowlist, tag-scoped destructive operations, and
  separate IAM `PassRole` scope; require a Route 53 hosted-zone ID unless the
  bootstrap command is explicitly creating the hosted zone.
- Added production destroy sentinels to each backend child module so targeted
  module destroy plans cannot bypass the root production guard.
- Threaded the environment safety contract through networking, compute,
  deployment-artifact, and DNS/TLS module boundaries, with staging fixtures
  updated for the new required module input.
- Expanded compute plan-only coverage for retained and disposable data-volume
  selection, attachment to the current instance, EBS encryption, root-volume
  deletion, IMDSv2 requirements, and production retention preconditions.
- Added `--policy-output-dir` dry-run support for inspecting generated
  deployment IAM policy JSON, with offline parsing tests synchronized between
  local `bin/quality` and GitHub Actions.
- Hardened runtime parameter handling with secure-by-default SSM types,
  explicit non-secret declarations, duplicate/empty/multiline input rejection,
  and deliberate opt-in for existing parameter type changes.
- Added protected runtime-secret rendering with mode `0600`, robust multiline
  rejection, and tests ensuring secret values do not appear in command output.
- Extended local and CI quality coverage to include the compute module,
  policy-contract checks, and ShellCheck/Bash checks for repository test
  scripts.
- Decoupled frontend delivery from backend infrastructure. Frontend consumers
  own their application assets, S3/CloudFront resources, certificate, and
  frontend DNS alias; `API_BASE_URL` is an optional handoff.
- Kept repository quality automation local to this repository while making
  deployment and operational workflows reusable by consumer repositories.
- Made reusable workflows check out the requested infrastructure repository and
  ref, so consumers do not need a local clone.

### Nuances

- Reusable workflows are `workflow_call` entry points, not standalone
  dispatch interfaces. Consumer repositories provide their own trigger and
  protected-environment mapping.
- The backend stack intentionally uses one public EC2 host and an Internet
  Gateway; it does not provision managed NAT or a load balancer.
- Production retention and destructive-operation guardrails remain explicit;
  the root volume is disposable while EIP and data-volume retention are
  environment-controlled with production protections.
- The frontend-only shape does not require backend state, backend credentials,
  API DNS records, or backend resources.
