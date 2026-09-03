# Changelog

All notable changes to this project are documented in this file.

## [Unreleased]

### Added

- Extracted application-neutral AWS infrastructure building blocks for a
  cost-conscious single-host deployment model.
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
