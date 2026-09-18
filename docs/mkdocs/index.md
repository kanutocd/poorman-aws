# poorman-aws

Provision and operate a small production backend from a consumer repository
without copying infrastructure code into the application repository.

The default backend architecture uses one public ARM64 EC2 host in one
Availability Zone, Caddy for public HTTP/HTTPS termination, SSM Session Manager
for administration, private S3 release artifacts, and a Route 53 API record.

The baseline deployment is deliberately small: one public ARM64 EC2 host in
one Availability Zone, Caddy at the HTTP/HTTPS edge, Session Manager for
administration, private S3 release artifacts, and a Route 53 API record. It is
not a multi-AZ platform or a complete application runtime.

## Start here

- [Choose how to consume the wrapper](getting-started/first-deployment.md#choose-a-consumption-mode)
- [Choose a deployment shape](getting-started/choose-a-deployment-shape.md)
- [Review prerequisites](getting-started/prerequisites.md)
- [Follow the zero-to-staging path](getting-started/from-zero-to-staging.md)
- [Complete a first deployment](getting-started/first-deployment.md)
- [Read the architecture](architecture.md)
- [Run quality checks](quality.md)

## Safety boundaries

- Only TCP ports 80 and 443 are public ingress.
- SSH is not the administration path; use Session Manager.
- Runtime secrets belong in SSM `SecureString` parameters and must not enter
  Git, plans, logs, or frontend assets.
- Production retains its Elastic IP and data volume.
- Pull-request OpenTofu tests use mocked providers and `command = plan`.

Frontend hosting is consumer-owned. The reusable frontend workflows provide
the orchestration and safety boundary; the consumer supplies its frontend
application, hosting configuration, deployment commands, and protected
environment values.

## Two ways to consume `poorman-aws`

Use either mode from the consumer repository. Both modes run the same
`bin/poorman-aws` wrapper and accept the same configuration and command-line
options.

### Clone and invoke locally

Clone a release tag when you want the wrapper and reusable repository files
available for inspection:

```bash
git clone --branch v0.1.0 --depth 1 \
  https://github.com/kanutocd/poorman-aws.git .poorman-aws

.poorman-aws/bin/poorman-aws doctor --offline
.poorman-aws/bin/poorman-aws onboard --dry-run
```

Use a full commit SHA instead of `v0.1.0` when testing an unreleased change.

### Download and pipe to Bash

Use the raw wrapper when you do not want to clone the infrastructure
repository. Pin the URL to a release tag or full commit SHA; do not use
`main` for an operational or production command:

```bash
curl -fsSL \
  https://raw.githubusercontent.com/kanutocd/poorman-aws/refs/tags/v0.1.0/bin/poorman-aws \
  | bash -s -- doctor --offline

curl -fsSL \
  https://raw.githubusercontent.com/kanutocd/poorman-aws/refs/tags/v0.1.0/bin/poorman-aws \
  | bash -s -- onboard --dry-run
```

Run the command from the consumer repository. The wrapper reads the consumer's
configuration and writes generated files there; it does not copy the
`poorman-aws` source tree into the consumer repository.
