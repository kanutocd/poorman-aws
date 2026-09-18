# Complete a first deployment

Use a consumer repository for application code and runtime configuration. Keep
the infrastructure repository reusable and application-neutral.

## Choose a consumption mode

Use one of these modes before continuing with the deployment steps. Both run
the same wrapper contract. Replace `v0.1.0` with a full commit SHA when you
need to test an unreleased `poorman-aws` change.

### Clone the repository

Use a clone when you want to inspect the reusable workflows, scripts, and
examples locally:

```bash
git clone --branch v0.1.0 --depth 1 \
  https://github.com/kanutocd/poorman-aws.git .poorman-aws

.poorman-aws/bin/poorman-aws doctor --offline
.poorman-aws/bin/poorman-aws config validate --config .poorman-aws.yml
.poorman-aws/bin/poorman-aws onboard --dry-run
```

### Download the wrapper with `curl`

Use the raw wrapper when the consumer does not need a local infrastructure
checkout:

```bash
curl -fsSL \
  https://raw.githubusercontent.com/kanutocd/poorman-aws/refs/tags/v0.1.0/bin/poorman-aws \
  | bash -s -- doctor --offline

curl -fsSL \
  https://raw.githubusercontent.com/kanutocd/poorman-aws/refs/tags/v0.1.0/bin/poorman-aws \
  | bash -s -- config validate --config .poorman-aws.yml
```

The piped form executes in the current consumer directory. It can read an
explicit configuration path and generate consumer-owned files, but it does not
leave a wrapper file or infrastructure checkout behind. Pin the URL to a tag
or full SHA; avoid floating `main` URLs for production operations.

1. Choose a deployment shape.
2. Pin the `poorman-aws` reference to a release tag or full commit SHA. Use a
   full SHA when testing an unreleased change.
3. Clone `poorman-aws` or invoke its wrapper from an immutable release, then
   inspect the available commands:

   ```bash
   bin/poorman-aws --help
   ```

4. Configure the consumer's non-secret variables and protected secrets in its
   GitHub environment. Keep secret values out of YAML, command arguments, and
   generated files.
5. Bootstrap AWS OIDC and the required state, artifact, DNS, and runtime
   parameter boundaries.
6. Run a staging OpenTofu plan and review the network, IAM, lifecycle, and cost
   changes before applying it.
7. Apply only the reviewed staging plan through the protected workflow.
8. Publish an immutable release and verify the API health, CORS, and WebSocket
   checks supplied by the consumer.

Start with the repository's [backend README](https://github.com/kanutocd/poorman-aws/blob/main/backend/README.md)
for the environment-specific configuration examples. Do not copy populated
variable files, state, plans, or credentials into Git.

Production requires separate state, protected environment approval, retained
data-volume and Elastic IP settings, and the [production recovery
policy](../recovery.md). Do not use the non-production lifecycle workflow for
production.
