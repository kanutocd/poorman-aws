# Changelog

All notable changes to this project are documented in this file.

## [Unreleased]

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
