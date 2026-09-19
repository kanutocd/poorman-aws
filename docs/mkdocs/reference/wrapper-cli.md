# Wrapper CLI reference

`bin/poorman-aws` is the consumer-facing entry point for configuration checks,
onboarding, backend operations, and frontend workflow adapters. It keeps the
infrastructure implementation in `poorman-aws` while generating or dispatching
only consumer-specific values and thin workflow callers.

## Invocation

Run the wrapper from the consumer repository in either of two equivalent ways.

### From a clone

Clone an immutable release when you want to inspect the reusable workflows,
scripts, and examples locally:

```bash
git clone --branch v0.1.0 --depth 1 \
  https://github.com/kanutocd/poorman-aws.git .poorman-aws

.poorman-aws/bin/poorman-aws doctor --offline
```

### From a pinned raw URL

Download the wrapper and pipe it to Bash when you do not need a local checkout:

```bash
curl -fsSL \
  https://raw.githubusercontent.com/kanutocd/poorman-aws/refs/tags/v0.1.0/bin/poorman-aws \
  | bash -s -- doctor --offline
```

Use a full commit SHA instead of `v0.1.0` when testing an unreleased change.
Do not use a floating `main` URL for production operations. The piped form
executes in the current directory, reads the consumer configuration, and can
write generated consumer files there; it does not leave a wrapper file or
infrastructure checkout behind.

## Global options

Global options may be supplied before or after the command. The wrapper accepts:

| Option | Purpose |
| --- | --- |
| `--config PATH` | Load an explicit consumer YAML configuration file. |
| `--consumer-path PATH` | Select the consumer repository when invocation is outside its checkout. |
| `--non-interactive` | Refuse prompts; required for unattended use. |
| `--json` | Request machine-readable output where the command supports it. |
| `--dry-run` | Preview without writing files or dispatching mutating operations. |
| `--overwrite` | Allow replacing generated files after conflict checks. |
| `--offline` | Skip AWS/GitHub checks and network-backed onboarding inference; missing values are prompted for or must come from configuration. |
| `--aws` | Check AWS CLI identity and region. |
| `--docker` | Check Docker Compose and the consumer Compose file. |
| `--infra` | Check OpenTofu and infrastructure prerequisites. |
| `--ami` | Check Packer and AMI-build prerequisites. |
| `--github` | Check GitHub CLI authentication. |

Run `bin/poorman-aws --help` for the complete option list, including command
options such as `--environment`, `--apply`, `--confirm`, `--action`,
`--release-id`, `--consumer-ref`, and frontend URL or command options.

## Configuration

The wrapper resolves values in this order:

```text
built-in defaults < YAML configuration < command-line options
```

An explicit command-line option always wins over the YAML file. An explicit
configuration path is honored even when it is outside the current directory.
The wrapper does not require invocation from the consumer repository root: it
uses the enclosing Git root when available, accepts `--consumer-path` for an
explicit checkout, and resolves generated files and consumer-relative paths
against that root.
Consumer paths may use `~`, `~/...`, or `~user/...`; the wrapper expands them
before checking that the directory exists.

For `install` and `onboard`, an inferred path is shown as an editable prompt.
If no consumer checkout can be inferred, the wrapper asks for the absolute
path and refuses to continue when the answer is empty:

```text
Consumer repository path [/home/example/villago-app]:
```
The configuration may contain non-secret commands, paths, identifiers, URLs,
and sizing values, but it must not contain secret values or credentials.

Inspect the effective configuration without exposing secret values:

```bash
bin/poorman-aws config validate --config .poorman-aws.yml
bin/poorman-aws config show --config .poorman-aws.yml
```

The `frontend` section can define `directory`, `build_command`,
`deploy_command`, `remove_command`, `output_entrypoint`, `frontend_url`,
`api_url`, `frontend_origin`, `api_base_url`, `frontend_hostname`,
`frontend_certificate_arn`, and `aws_role_secret`. Use protected GitHub
environment secrets or command-specific environment variables for sensitive
values instead of adding them to YAML or command arguments.

## Command overview

| Command | Mutates state? | Main use |
| --- | --- | --- |
| `install` | No by default | Check local tools and guide AWS/GitHub authentication. |
| `bootstrap state-bucket` | Yes with confirmation | Create or verify encrypted remote OpenTofu state storage. |
| `config validate` | No | Validate the effective configuration. |
| `config show` | No | Print the effective redacted configuration. |
| `doctor` | No | Check tools and the consumer repository contract. |
| `onboard` | Yes, after review | Generate consumer configuration and thin workflows. |
| `plan` / `apply` | `apply` dispatches a mutation | Plan or apply backend infrastructure through GitHub Actions. |
| `release` / `rollback` | Dispatches an operation | Publish or activate a backend release. |
| `lifecycle` | May mutate | Stop, destroy, or nuke a guarded non-production backend. |
| `parameters` | May mutate with `--apply` | Preview or write runtime parameters. |
| `ami build` | Dispatches a build | Request a reviewed host AMI build. |
| `frontend deploy` | Dispatches a deployment | Build and deploy consumer-owned frontend hosting. |
| `frontend rollback` | Dispatches a deployment | Redeploy a known-good consumer revision. |
| `frontend lifecycle` | May mutate | Destroy or nuke non-production frontend resources. |
| `frontend smoke` | No | Check deployed frontend, API, CORS, and WebSocket behavior. |
| `github sync` | Yes with confirmation | Create consumer environments and set AWS role secrets. |

## Inspection and onboarding commands

### `install`

Run the installer-style preflight from the consumer repository. It checks the
local Bash, `curl`, `jq`, Git, YAML parser, consumer files, and—unless
`--offline` is used—AWS and GitHub CLI authentication:

```bash
bin/poorman-aws install --offline
bin/poorman-aws install --setup-auth --docker --infra --ami
```

The command does not install operating-system packages, write credentials, or
create GitHub resources. When the AWS setup authorization check passes, it may
create the explicitly confirmed remote state bucket described below. If
authentication is missing, it prints the remediation command. Add `--setup-auth` in an interactive terminal to offer
the standard provider-owned flows:

```bash
bin/poorman-aws install --setup-auth
```

That may offer `aws configure sso` and `gh auth login`; each requires explicit
interactive confirmation. `--non-interactive` never prompts and instead fails
with the remediation needed by automation. After the checks pass, continue
with `onboard`, review its generated diff, and then use `doctor` for the
operation-specific checks.

When the state bucket is not configured, the installer infers that AWS setup
is incomplete and performs a read-only IAM policy simulation for the minimum
OIDC, state-bucket, and Route 53 setup actions. Each action is reported as
allowed or missing. If policy simulation itself is unavailable, the installer
fails closed and asks for a profile that can inspect its effective setup
permissions; it never probes these permissions by creating or changing a
resource.

Before checking AWS identity, `install` selects the profile to use. An
explicit `AWS_PROFILE` wins. Otherwise it suggests a profile named
`administrator` or `admin` (case-insensitive), then the first profile returned
by `aws configure list-profiles`. Interactive runs can choose another listed
profile; non-interactive runs use the suggestion.

The installer then reads the selected profile's configured region with
`aws configure get region`. If it is missing, interactive mode asks for a
region (or uses the displayed default); non-interactive mode requires
`aws.region` in YAML or `--aws-region`. The selected value is verified against
AWS's available-region list, written back to the selected profile with
`aws configure --profile PROFILE set region REGION`, and persisted in the
non-secret installer checkpoint.
The checkpoint also records the aggregate setup-authorization result as
`passed`, `failed`, `unknown`, or `not_checked`, independently of whether a
later prerequisite such as the state bucket is still missing.
When the saved result is `passed`, normal installer reruns reuse it rather
than repeating IAM simulation. Pass `--update` when you want to refresh the
authorization check.

During onboarding, when no Availability Zone is configured, the wrapper makes
a read-only `describe-availability-zones` query in the selected region and
offers the first available standard Availability Zone as an editable default.
The value can still be replaced at the prompt or supplied in YAML.

When the account has exactly one public Route 53 hosted zone, onboarding also
uses that zone name as an editable default. If there are multiple public zones,
the wrapper leaves the value blank rather than risk selecting the wrong DNS
domain; choose the intended zone at the prompt or configure it in YAML.
If AWS returns no public hosted zones, onboarding also leaves the value blank
and explains that a public zone must be created or supplied explicitly.
When the value is blank, the prompt shows an application-derived example such
as `villago.com`; this is guidance only and is never selected automatically.

If that authorization check passes, `install` automatically starts the guided
state-bucket bootstrap. It suggests a globally unique full S3 bucket name in
the form `<application>-tofu-state-<account-id>`, asks you to confirm or edit
the name, and requires the exact confirmation text `CREATE-STATE-BUCKET`
before creating anything. The bucket is then hardened and recorded in the
installer checkpoint, so a separate bootstrap command is not needed during a
normal first install. In non-interactive mode, provide the equivalent
explicit mutation approval: `--apply --confirm CREATE-STATE-BUCKET`.

After each install attempt, the wrapper records a small non-secret checkpoint
in `${XDG_STATE_HOME:-$HOME/.local/state}/poorman-aws/`. The file is named for
the consumer directory and records the detected account, caller ARN, profile,
region, and last install result. Consumer configuration and generated GitHub
workflows remain in the consumer repository; credentials and runtime secrets
are never written to this state file. After onboarding, the effective
non-secret `.poorman-aws.yml` is also mirrored as a per-consumer configuration
checkpoint in that same directory. The repository copy remains authoritative
when present; the checkpoint is a resumability fallback for a later invocation.

Onboarding asks you to confirm a deployment shape instead of inferring it from
repository directories. The default is `backend-and-frontend`:

```text
Deployment shape (backend-and-frontend, backend-only, or frontend-only) [backend-and-frontend]:
```

The selected shape controls which backend and frontend workflow families are
generated. Use `--deployment-shape` for scripted onboarding.

For a backend shape, onboarding also records the AMI build inputs under the
`ami` configuration section. It infers a public subnet in the selected
Availability Zone and the current operator public IP as a `/32` SSH CIDR when
AWS and network access allow; both remain editable prompts. The application
name supplies the default `ami.name_prefix` (`<application>-backend`). These
values become defaults in the generated AMI workflow, so a normal manual run
does not require re-entering them.

### `bootstrap state-bucket`

The normal `install` flow runs this operation automatically after the AWS
authorization check. Use the explicit command when you want to preview or
repeat the operation independently:

```bash
bin/poorman-aws --state-bucket application-tofu-state-ACCOUNT_ID \
  --dry-run bootstrap state-bucket
```

The command suggests a bucket name when one is not supplied. It creates the
bucket only with explicit confirmation, then enables public-access blocking,
versioning, and server-side encryption before verifying all three settings:

```bash
bin/poorman-aws --state-bucket application-tofu-state-ACCOUNT_ID \
  bootstrap state-bucket \
  --apply --confirm CREATE-STATE-BUCKET
```

The verified bucket name is written to the local XDG checkpoint and to a
minimal `.poorman-aws.yml` when the consumer has no configuration file. An
existing consumer configuration is never overwritten; add the bucket there or
use the explicit `--state-bucket` option for subsequent commands.

When `install` completes successfully in an interactive terminal, it offers to
continue directly to `onboard`. Accepting generates the consumer integration
files after showing their diff; declining pauses cleanly and prints the exact
resume command. Non-interactive runs always stop after the completed install
checkpoint and print the next command. A later invocation reuses the saved
profile, region, authorization result, and state bucket rather than restarting
the setup conversation.

### `doctor`

Run the doctor before onboarding or operating from a new consumer checkout:

```bash
bin/poorman-aws doctor --offline
bin/poorman-aws doctor --aws --docker --infra --github
```

The doctor checks Bash, `curl`, `jq`, Git, a YAML parser, and the consumer-owned
Compose file, Caddyfile, Dockerfile, and build context. Optional flags add AWS,
Docker, OpenTofu, Packer, or GitHub CLI checks. It reports remediation hints
without changing AWS or repository files. A missing consumer-owned file is a
contract failure, not an instruction to assume a service name or Compose
topology.

### `onboard`

Onboarding generates `.poorman-aws.yml` and thin caller workflows after
validating the consumer contract. Review the proposed diff before accepting it:

```bash
bin/poorman-aws --config .poorman-aws.yml onboard
```

Use `--dry-run` to preview without writing and `--overwrite` only when replacing
an existing generated file is intentional. Onboarding owns the generated
infrastructure pin and preserves conflicting consumer files until the diff has
been reviewed.

Generated callers are pinned to the immutable release tag of the wrapper that
generated them. The baseline wrapper uses `v0.1.0` for both the caller's
`uses` reference and its `infrastructure_ref`; it does not inherit a floating
`main` ref from consumer configuration. Versioned wrapper artifacts update
this owned default to their own release tag. An explicit consumer override can
be added in a future wrapper contract.

## Backend command contracts

Backend commands dispatch reusable workflows; they do not run `tofu apply` or
`tofu destroy` directly from the local wrapper.

### Plan and apply

Use `plan` to review backend infrastructure changes. Use `apply` only after the
reviewed plan has passed and the protected GitHub environment is ready:

```bash
bin/poorman-aws plan --environment staging
bin/poorman-aws apply --environment staging --apply \
  --confirm APPLY-STAGING
```

The exact required configuration includes the immutable infrastructure
repository and ref, application name, AWS region, state bucket, Availability
Zone, SSM parameter path, Route 53 zone, reviewed AMI, and deployment role.
`defaults.target_environment` defaults to `staging` and controls the default
environment emitted into generated workflow dispatchers and automatic paths.
`instance_type`, root EBS size, and data EBS size default to the baseline
values but can be overridden through configuration or command-line options.

### Release and rollback

`release` dispatches the consumer backend deployment workflow after the
consumer build and artifact preparation. `rollback` requires a known-good
release ID; it never silently falls back to the current branch:

```bash
bin/poorman-aws release --environment staging \
  --apply --confirm RELEASE-STAGING
bin/poorman-aws rollback --environment staging \
  --release-id KNOWN_GOOD_RELEASE_ID \
  --apply --confirm ROLLBACK-STAGING
```

The release workflow verifies checksums and health before making the release
current. A rollback changes application code, not the retained production data
volume or its backup policy.

### Backend lifecycle

Backend lifecycle operations support the guarded `STOP`, `DESTROY`, and `NUKE`
actions. Apply mode requires both `--apply` and the action-specific
confirmation phrase. Production destruction is rejected by the project
contract:

```bash
bin/poorman-aws lifecycle --action STOP --environment staging
bin/poorman-aws lifecycle --action DESTROY --environment staging \
  --apply --confirm DESTROY-STAGING
```

Use the dry-run output to review the target environment and retention values
before applying. The production data volume is retained by default and its
deletion is outside the project’s automated scope.

## Frontend command contracts

Frontend hosting remains consumer-owned. The wrapper supplies workflow
orchestration and safety checks; the consumer supplies its build and deploy
commands, hosting resources, URLs, and frontend-only IAM role.

### Deploy

`frontend deploy` requires an immutable infrastructure ref, environment,
region, frontend directory, build command, deploy command, and frontend role.
URLs and an output entrypoint enable post-deploy checks:

```bash
bin/poorman-aws frontend deploy --environment staging --dry-run
```

Review the displayed commands and dispatch inputs, then repeat without
`--dry-run` when the protected environment is ready. The current adapter
requires `--apply` and the exact confirmation phrase even for a dry-run payload
preview; `--dry-run` is what prevents the GitHub dispatch.

### Rollback

`frontend rollback` uses the same frontend contract and additionally requires
an immutable, known-good consumer ref:

```bash
bin/poorman-aws frontend rollback \
  --environment staging \
  --consumer-ref KNOWN_GOOD_CONSUMER_SHA \
  --dry-run
```

The workflow checks out that consumer revision, rebuilds it, and redeploys it.

### Frontend lifecycle

`frontend lifecycle` supports `DESTROY` and `NUKE` for non-production only. It
requires the frontend hostname, an immutable consumer ref, and the exact
action/environment confirmation when applied:

```bash
bin/poorman-aws frontend lifecycle \
  --environment staging \
  --action DESTROY \
  --dry-run
```

Production is rejected before dispatch. Frontend lifecycle operations use a
frontend-only AWS role and do not operate on backend state.

### Smoke

`frontend smoke` is local and non-mutating. It does not require AWS or GitHub
credentials:

```bash
bin/poorman-aws frontend smoke \
  --frontend-url https://app.example.test \
  --api-url https://api.example.test \
  --frontend-origin https://app.example.test \
  --json
```

Provide a bearer token through the command’s documented environment variable,
never as a command-line argument. The smoke adapter performs bounded checks for
the frontend, API health, CORS, and WebSocket behavior.

## CI and non-interactive use

Use `--non-interactive` in automation. Combine it with `--dry-run` for a safe
payload preview. Mutating commands also require `--apply` and an exact
`--confirm` value; for adapters that require confirmation before constructing
their payload, include those flags in the dry-run too:

```bash
bin/poorman-aws --non-interactive --dry-run frontend deploy \
  --environment staging \
  --apply --confirm FRONTEND-DEPLOY-STAGING
```

Generated caller workflows pin the reusable infrastructure reference to the
wrapper release that generated them and keep consumer-specific values in
GitHub variables and secrets. Do not put secret values in workflow `with`
inputs, YAML configuration, logs, generated files, or frontend assets.

## Exit behavior and troubleshooting

- Exit status `0` indicates that the requested validation, preview, or
  dispatch completed successfully.
- Exit status `2` indicates invalid usage, missing required input, a rejected
  safety condition, or an unavailable prerequisite.
- A failed `doctor` run identifies the missing item and prints a remediation
  hint; install or configure that item before repeating the command.
- A mutating command that refuses to run is normally missing `--apply`, the
  exact confirmation phrase, an immutable ref, or a required protected value.
- If a remote invocation fails before the wrapper starts, verify the raw URL,
  release tag or SHA, `curl`, and Bash version.

For the complete command and option list, run:

```bash
bin/poorman-aws --help
```
