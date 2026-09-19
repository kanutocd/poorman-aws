# Changelog

All notable changes to this project are documented in this file.

## [Unreleased]

- Added a guarded pre-plan repair for tainted retained EIPs. The reusable
  infrastructure workflow now verifies the live allocation and ownership tags
  before untainting only the matching OpenTofu state entry from the raw state,
  preventing a transient AWS read failure from attempting to replace a
  retained EIP.
- Fixed the deployment-role IAM contract for staging and production applies by
  allowing managed SSM policy attachment, EIP attribute reads, and the
  untagged-first network resource creation pattern used by OpenTofu.

- Bounded generated deployment-artifact bucket prefixes to AWS's 37-character
  limit while retaining a readable application prefix and deterministic hash,
  and aligned the IAM artifact resource pattern with the new names.
- Added the missing `route53:ListHostedZones` permission required by the
  backend DNS data source alongside the existing name-based discovery action.
- Normalized blank Route 53 zone IDs to `null` before DNS data-source
  selection, preventing generated empty workflow fallbacks from becoming
  ambiguous hosted-zone lookups.
- Changed AMI metadata persistence to use an application-scoped SSM Parameter
  Store record as the durable AWS-side source, while retaining the canonical
  GitHub artifact and reusable-workflow outputs. Generated callers may
  optionally mirror the outputs to consumer environment variables through
  `POORMAN_ENVIRONMENT_ADMIN_TOKEN`; the reusable AMI workflow no longer
  requires that GitHub-management token.
- Fixed nested AMI OIDC credential resolution by using the protected
  `ami-build` environment's `AWS_ROLE_ARN`; environment-scoped secrets are not
  passed through the caller workflow boundary.
- Added the temporary EC2 key-pair create/delete permissions required by the
  Packer AMI builder to the narrowly scoped AMI-build role policy.
- Added the temporary EC2 instance lifecycle permissions Packer needs to stop
  and resume the builder while creating the AMI.
- Extended failure cleanup to terminate tagged temporary builder instances and
  delete tagged temporary Packer key pairs, not only temporary security groups.
- Added the AMI attribute and deregistration permissions required for Packer to
  finalize an image and roll it back safely when finalization fails.

- Improved generated consumer workflow names with descriptive title-style
  labels, including the `poorman-aws` product name and the operation being
  performed.
- Added caller-level `id-token: write` permission to generated AMI workflows
  so nested OIDC credential configuration and cleanup jobs are authorized by
  GitHub Actions.

- Made onboarding and installation next-step guidance reuse the exact wrapper
  executable path used for the current invocation, including absolute paths,
  and include the resolved consumer repository path, so copy-pasteable GitHub
  synchronization and prerequisite commands work from outside both the
  consumer and infrastructure repositories.

- Changed AMI builder network scoping to determine the executing runner or
  local build machine's public egress CIDR at runtime. Consumer onboarding no
  longer persists an operator IP or asks for `ami_ssh_cidr`; generated callers
  provide the subnet and name prefix while the shared build adapter passes the
  resolved CIDR only to Packer. The CIDR is excluded from AMI fingerprinting,
  and the adapter plus an always-run workflow cleanup pass remove tagged
  temporary security groups. The tags also make interrupted-run resources
  identifiable for manual cleanup; a scheduled orphan-resource janitor is not
  included yet. An explicit workflow override remains available for exceptional
  self-hosted networking.

## 0.1.0 - 2026-9-19

- Extended the consumer wrapper's first-run and resume flow with explicit
  consumer-path resolution, persistent POSIX state, profile and region
  discovery, AWS setup-privilege checks, automatic state-bucket bootstrapping,
  deployment-shape selection, version-aware workflow generation, and offline
  onboarding support.
- Added idempotent AMI orchestration around the reusable workflows: AMI
  fingerprints are validated against canonical artifacts, GitHub environment
  variables, and live AWS images; backend infrastructure receives the AMI as a
  reusable-workflow output; and Packer is isolated behind a single guarded
  build job.
- Added generic frontend adapter ownership to the infrastructure repository,
  including the deploy/remove adapter, frontend workflow inputs, consumer
  frontend configuration, and contract coverage that prevents generated
  callers from embedding consumer-specific SST commands.
- Refreshed onboarding, wrapper, workflow-reference, AMI, and prerequisites
  documentation to match the current generated integration contract, and
  expanded policy, wrapper, release, and frontend adapter tests accordingly.
- Added `bin/docs lint` to the main `bin/quality` verification harness and its
  policy contract, making Vale, Markdownlint, and offline Lychee part of the
  required local quality gate.
- Changed third-party GitHub Actions to use their published major release tags
  (`actions/checkout@v7`, AWS credentials `@v6`, and the corresponding current
  major tags for setup, cache, artifact, and Pages actions). The workflow
  contract now rejects commit-SHA, branch, and local-path action references;
  the reusable AMI caller is pinned to the published `poorman-aws@v0.1.0`
  release tag.

- Made the wrapper invocation location-independent. It now resolves the
  consumer Git root, supports an explicit `--consumer-path`, and performs
  configuration loading, state identity, contract checks, relative path
  resolution, and onboarding writes against that consumer root.
- Installer and onboarding now refuse to treat an arbitrary directory as a
  consumer. They prompt for the absolute consumer path when it cannot be
  inferred and refuse to continue when no path is supplied.
- Consumer paths entered interactively or supplied with `--consumer-path` now
  support the conventional `~`, `~/...`, and `~user/...` home-directory forms.
- Offline onboarding now skips all network-backed inference, including AWS
  Availability Zone, Route 53 zone, subnet, and public-IP lookups.
- Onboarding prompts now identify the generated files as GitHub Actions
  workflow integrations and print complete copy-pasteable commands for GitHub
  environment synchronization and prerequisite verification.
- Added configurable `defaults.target_environment` (default `staging`) to the
  generated consumer configuration; generated deployment workflow defaults now
  use that value while guarded lifecycle workflows remain staging-only.
- Renamed the consumer configuration key `backend.parameter_path` to
  `backend.ssm_parameters_path` so its AWS Systems Manager Parameter Store
  purpose is explicit. The legacy `--parameter-path` option remains accepted,
  alongside the clearer `--ssm-parameters-path` alias.
- Existing consumer state/configuration checkpoints using
  `backend.parameter_path` are now accepted and normalized to the new key
  during loading.
- Generated caller workflows now include documented, disabled examples for
  `push`, `pull_request`, `workflow_run`, and `schedule` triggers. Dispatch-only
  inputs also fall back to wrapper-generated literals so future non-dispatch
  triggers can coexist safely.
- Added AMI-build idempotency guardrails. The reusable AMI workflow computes a
  build fingerprint, validates canonical-artifact and environment candidates
  against AWS image state and fingerprint tags, and skips Packer when a matching
  live AMI exists.
- Refactored the reusable AMI workflow into guard, conditional-build, and
  publish jobs. The guard now owns the single reuse decision, Packer setup and
  execution occur only in the build job when needed, and the publish job
  exposes the same AMI outputs for both reused and newly built images.
- Backend infrastructure planning now depends on the idempotent AMI workflow
  and receives its AMI output directly. The environment synchronizer provisions
  the separate `AWS_AMI_ROLE_ARN` secret needed for that nested build-or-reuse
  job; non-production teardown remains resolve-only.
- The nested infrastructure-to-AMI workflow call now uses GitHub's
  self-repository reference (`$/.github/workflows/build-backend-ami.yml`) so it
  resolves from the same running `poorman-aws` commit without relying on the
  caller workspace checkout.
- Added a narrow actionlint compatibility ignore for the new self-repository
  workflow reference; all unrelated workflow diagnostics remain enforced.
- Added bounded retries with backoff to AMI artifact/environment discovery and
  AWS image validation, including pending-image polling. Packer is never
  blindly retried, while fingerprint mismatches and terminal invalid states
  remain non-retryable.
- Refactored the AMI workflow into guard, conditional build, and publish jobs,
  removing repeated step-level Packer conditions while preserving canonical
  artifact and environment publication for both reused and newly built AMIs.

- Replaced manual `AMI_ID` secret wiring with a canonical AMI artifact and
  environment-variable fallback. The AMI workflow publishes `ami-id.txt`,
  updates only the explicitly selected target environment's `AMI_ID` variable, and the
  infrastructure and lifecycle workflows fail fast when neither source is
  available.

- Added `github sync` to create the standard consumer environments and
  synchronize backend `AWS_ROLE_ARN` and, when applicable, frontend
  `AWS_FRONTEND_ROLE_ARN` secrets through the authenticated GitHub CLI. The
  operation requires explicit `SYNC-GITHUB-ENVIRONMENTS` confirmation.

- Added onboarding-persisted AMI build inputs for the public subnet, temporary
  builder SSH CIDR, and application-derived AMI name prefix. Generated AMI
  callers now expose all three as editable workflow defaults instead of
  requiring them to be re-entered on every dispatch.

- Made onboarding-generated caller workflows pin both their `uses` reference
  and `infrastructure_ref` to the wrapper's immutable release tag (`v0.1.0`)
  instead of inheriting a consumer-selected or floating `main` ref. Versioned
  wrapper artifacts rewrite this owned default to their release tag.

### Documentation

- Added a canonical “From zero to staging” guide that separates one-time AWS
  administrator setup, one-time consumer repository setup, repeatable staging
  deployment, and repeatable release, rollback, and teardown.
- Documented direct pinned raw-script consumption for the AWS OIDC bootstrap
  and GitHub environment synchronizer, so both setup operations work without a
  full repository clone.
- Recorded the deferred wrapper adapters for AWS OIDC bootstrap and GitHub
  environment synchronization in the public roadmap, including their
  privilege, secret-handling, and immutable-ref requirements.
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

- Added the installer-style `poorman-aws install` preflight. It checks the
  local toolchain, consumer contract, AWS identity, and GitHub CLI session;
  optionally offers explicitly confirmed `aws configure sso` and `gh auth
  login` flows while keeping credential storage provider-owned and all cloud
  mutations outside the installer.
- Added a flat, per-consumer non-secret install checkpoint under the standard
  XDG state directory, while keeping consumer configuration and generated
  workflows in the consumer repository.
- Installer AWS checks now select and report the active profile, preferring an
  explicitly supplied `AWS_PROFILE`, then `administrator`/`admin`, and finally
  the first configured profile.
- Installer prompts now suggest the consumer directory basename as the
  application name, and refresh incomplete checkpoints after AWS identity
  detection so account and caller metadata are retained even when a later
  prerequisite is missing.
- Repeat installer runs now restore and display saved application/profile
  values without prompting; pass `--update` explicitly to revisit them.
- Installer region selection now prefers the selected profile's configured
  region, validates it against AWS, prompts when missing, writes the validated
  value back to the profile, and persists it in the installer checkpoint.
- When the state bucket is missing, installer preflight now performs a
  read-only IAM policy simulation for the minimum AWS OIDC, state-bucket, and
  Route 53 setup permissions and fails closed when authorization cannot be
  established.
- Installer checkpoints now persist the aggregate AWS setup-authorization
  result separately from the overall incomplete/complete install result.
- Added the guarded `bootstrap state-bucket` operation. It previews or creates
  the encrypted, versioned, public-access-blocked OpenTofu state bucket,
  verifies its settings, and persists the verified bucket name without
  overwriting an existing consumer configuration.
- Normal installer reruns now reuse a saved successful AWS authorization
  preflight; `--update` explicitly refreshes the IAM simulation.
- A successful installer authorization check now automatically enters the
  guided state-bucket bootstrap: it suggests an application/account-derived
  bucket name, requires the exact `CREATE-STATE-BUCKET` confirmation, applies
  the existing encryption/versioning/public-access protections, and persists
  the verified bucket before continuing onboarding. Non-interactive installs
  use the equivalent `--apply --confirm CREATE-STATE-BUCKET` approval.
- Completed interactive installs now offer to continue directly into onboarding;
  declining pauses with the exact resume command, while non-interactive runs
  stop after persisting the completed checkpoint.
- Onboarding now accurately labels the infrastructure reference as accepting a
  tag, branch, or commit SHA and permits the default `main` branch. Protected
  operational commands continue to require an immutable tag or commit SHA.
- Onboarding now restores the installer checkpoint and infers an available
  standard Availability Zone from the selected AWS region when none is
  configured, presenting it as an editable default.
- Onboarding now suggests the sole public Route 53 hosted zone when the AWS
  account has exactly one; multiple public zones remain an explicit user
  choice to avoid misdirecting DNS records.
- Onboarding now explains when no public Route 53 hosted zone is available
  instead of presenting an unexplained empty prompt.
- The Route 53 prompt now shows an application-derived domain example, such as
  `villago.com`, without treating that example as a default value.
- Onboarding now recognizes the minimal state-bucket configuration generated
  by `install` and safely upgrades it to the complete consumer configuration;
  genuinely existing consumer configuration still requires explicit review
  with `--overwrite`.
- The wrapper now mirrors the non-secret consumer configuration into the
  per-consumer XDG state directory while retaining `.poorman-aws.yml` in the
  repository as the authoritative and reviewable copy.
- Onboarding now requires an explicit deployment-shape choice, defaulting to
  `backend-and-frontend`, instead of inferring the shape from repository
  directories. It generates backend and/or frontend workflow families only
  for the confirmed shape.
- Added the poorman-owned frontend SST adapter and generic configuration. The
  reusable frontend workflows can now invoke `bin/frontend-adapter` for deploy and
  removal, keeping frontend infrastructure implementation out of consumer
  repositories while retaining consumer-owned source and build inputs.
- Updated the getting-started examples to make `install --offline` the first
  local wrapper invocation before onboarding.
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
