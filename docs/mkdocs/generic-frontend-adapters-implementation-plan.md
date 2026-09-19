# Generic frontend adapters implementation plan

Date: 2026-09-18

Status: implementation complete locally. The wrapper, configuration contract,
frontend workflow adapters, onboarding generation, safety checks, tests, and
documentation are implemented. A real consumer deployment, rollback, smoke
run, or lifecycle rehearsal remains an environment-specific operational gate.

## Objective

Extend the `bin/poorman-aws` consumer wrapper so a consumer can operate its
frontend runbook through the same pinned, configuration-aware interface used
for backend infrastructure and releases.

The adapters must remain frontend-hosting neutral. `poorman-aws` owns the
workflow orchestration, safety guards, smoke checks, and AWS role boundary;
the consumer owns its frontend source, build/deploy/remove commands, hosting
configuration, domains, and protected environment values.

The adapters must work when the consumer:

- clones poorman-aws and runs `bin/poorman-aws` locally;
- downloads `bin/poorman-aws` from an immutable release and pipes arguments to
  Bash; or
- invokes the same operations from CI with `--non-interactive`.

## Desired command surface

Add these wrapper commands without changing existing backend command behavior:

```text
frontend deploy
frontend rollback
frontend lifecycle
frontend smoke
```

The commands may also support aliases where they improve discoverability, but
the canonical names must remain stable for documentation and CI.

### `frontend deploy`

Dispatch the generic reusable frontend deployment workflow with:

- application name;
- environment;
- immutable infrastructure repository and ref;
- AWS region;
- consumer frontend directory;
- build command;
- deploy command;
- optional output entrypoint for artifact scanning;
- frontend URL, API URL, and frontend origin for acceptance checks;
- optional non-secret API base URL and certificate ARN;
- protected frontend AWS role secret reference.

The command must support dry-run preview and explicit `--apply` plus an
environment-specific confirmation phrase before dispatching a mutating
workflow.

### `frontend rollback`

Dispatch the generic reusable frontend rollback workflow with:

- the same frontend contract as deploy;
- an immutable consumer ref identifying the known-good revision;
- optional smoke-check values and frontend role configuration.

Rollback must require a known-good consumer ref and an explicit confirmation.
It must not silently fall back to the current branch or default branch.

### `frontend lifecycle`

Dispatch the published generic non-production frontend lifecycle workflow with:

- environment;
- `DESTROY` or `NUKE` action;
- exact action/environment confirmation;
- dry-run or apply mode;
- frontend hostname;
- frontend directory;
- consumer-approved removal command for `NUKE`;
- immutable consumer ref;
- frontend-only AWS role secret reference.

The adapter must reject production before dispatch and must preserve the
separate frontend/backend IAM boundary. `STOP` remains a backend lifecycle
operation unless a separate generic frontend stop contract is introduced.

### `frontend smoke`

Run the poorman-aws frontend smoke implementation against already deployed
URLs. This command is non-mutating and should work locally and in CI.

It must support:

- frontend URL;
- API URL;
- frontend origin;
- optional API bearer token from the environment, never a CLI argument;
- optional CORS and WebSocket path overrides;
- bounded HTTP and WebSocket timeouts;
- text and JSON result modes where practical.

The smoke adapter must not require AWS credentials.

## Configuration contract

Add a `frontend` section to the effective wrapper configuration. Proposed
fields:

```yaml
frontend:
  directory: frontend
  build_command: pnpm build
  deploy_command: SST_TELEMETRY_DISABLED=1 pnpm exec sst deploy --stage "$ENVIRONMENT"
  remove_command: SST_TELEMETRY_DISABLED=1 pnpm exec sst remove --stage "$ENVIRONMENT"
  output_entrypoint: dist/index.html
  frontend_url: https://app.example.test
  api_url: https://api.example.test
  frontend_origin: https://app.example.test
  api_base_url: https://api.example.test
  frontend_hostname: app.example.test
  frontend_certificate_arn: ""
  aws_role_secret: AWS_FRONTEND_ROLE_ARN
```

Rules:

- built-in defaults are lowest precedence;
- discovered or explicitly supplied YAML overrides defaults;
- command-line options always override YAML;
- secrets and secret values are never accepted in YAML, CLI arguments, or
  generated artifacts;
- command strings are consumer-owned inputs and must be displayed in dry-run
  output before dispatch;
- environment-specific URLs and certificate values may be supplied through
  protected GitHub environment variables rather than committed YAML;
- an explicit config path must be honored even when it is outside the current
  working directory, subject to readable-file validation.

Validate required fields by command. For example, `frontend smoke` does not
need AWS role or infrastructure values, while `frontend deploy` requires the
complete deployment contract and an immutable infrastructure ref.

## Workflow and script ownership

### Reusable workflows

Keep these consumer-neutral reusable workflows in poorman-aws:

- `deploy-frontend.yml`;
- `rollback-frontend.yml`;
- `kill-frontend-non-production.yml`.

Each workflow must:

- require an immutable infrastructure ref for production and lifecycle use;
- check out the requested immutable consumer ref where applicable;
- use pinned third-party actions;
- keep frontend OIDC credentials separate from backend credentials;
- execute consumer-provided commands only in the configured frontend directory;
- preserve output/artifact scanning and smoke behavior;
- fail closed on missing required inputs.

### Smoke implementation

Use `bin/frontend-live-smoke` as the single implementation. The wrapper
adapter should invoke it directly for local smoke checks, while reusable
deployment and rollback workflows invoke their checked-out poorman-aws copy.
Do not recreate smoke logic in the wrapper or consumer repository.

## Implementation phases

### Phase 0 — Contract and configuration

1. Add frontend schema/defaults to the wrapper configuration parser.
2. Add redacted config rendering and validation for the frontend section.
3. Add command-line options and precedence tests.
4. Add help text and examples for all four commands.
5. Define the minimum required values and confirmation phrases.

Exit evidence: `config validate`, `config show`, explicit YAML, and CLI
override tests pass without exposing secret values.

### Phase 1 — Frontend smoke adapter

1. Add `frontend smoke` dispatch-free local execution.
2. Forward supported URL, origin, token-environment, timeout, CORS, and
   WebSocket options to `bin/frontend-live-smoke`.
3. Support non-interactive and JSON result modes.
4. Test success, missing inputs, invalid URL schemes, HTTP failures, CORS
   failures, and WebSocket failures with deterministic fixtures.

Exit evidence: smoke can be run against a deployed consumer without AWS or
GitHub credentials, and no token appears in arguments or output.

### Phase 2 — Deploy and rollback adapters

1. Add `frontend deploy` and `frontend rollback` dispatch adapters.
2. Generate or target thin caller workflows with the immutable poorman-aws
   ref and consumer-specific frontend inputs.
3. Require `--apply` and exact confirmation for dispatch.
4. Require an immutable rollback consumer ref.
5. Preserve protected environment selection and frontend-only AWS role usage.
6. Add dry-run payload tests that redact secrets and display command inputs.
7. Add dispatch tests for missing `gh`, unauthenticated `gh`, invalid refs,
   production confirmation, and successful payload construction.

Exit evidence: a consumer can deploy and roll back its frontend without local
workflow logic or a copied poorman-aws checkout.

### Phase 3 — Lifecycle adapter

1. Add `frontend lifecycle` dispatch support for `DESTROY` and `NUKE`.
2. Enforce staging/non-production restrictions before GitHub dispatch.
3. Require the exact action/environment confirmation phrase for apply mode.
4. Pass the immutable consumer ref and frontend-only role secret reference.
5. Keep consumer removal commands out of logs when they contain sensitive
   values; reject obvious secret-bearing command arguments where practical.
6. Add dry-run, production-refusal, confirmation, and dispatch tests.

Exit evidence: the wrapper can safely request a frontend lifecycle rehearsal
without exposing backend credentials or permitting production destruction.

### Phase 4 — Onboarding and runbook integration

1. Extend onboarding to generate thin frontend deploy, rollback, lifecycle,
   and optional smoke caller workflows when frontend configuration is present.
2. Make generated workflows use the same immutable infrastructure ref and
   explicit consumer ref inputs.
3. Preserve existing consumer-owned frontend workflow files through conflict
   detection and unified-diff review.
4. Add frontend values to doctor inspection and remediation hints without
   assuming a Compose service topology.
5. Add README examples for cloned and curl-based invocation.

Exit evidence: a new consumer can onboard the frontend runbook without
manually copying workflow logic.

### Phase 5 — Compatibility, quality, and release

1. Run shell syntax checks, ShellCheck, wrapper tests, workflow contract tests,
   actionlint, and release parity tests.
2. Verify cloned and piped wrapper execution produce equivalent frontend
   command behavior.
3. Verify config-file values are overridden by CLI values in both modes.
4. Verify generated workflows contain immutable refs and no secret values.
5. Update the changelog, README, quality documentation, and consumer contract.
6. Publish the capability in the next immutable release and record the release
   ref for dogfooding.

Exit evidence: a tagged release supports all four frontend commands and the
generated consumer workflows pass the same contract checks as backend callers.

## Safety and failure boundaries

- Never accept provider/API credentials as normal command-line options.
- Never print bearer tokens, secret values, or protected secret names with
  values.
- Never permit frontend lifecycle actions against production.
- Never use a floating infrastructure ref for production, rollback, or
  lifecycle operations.
- Require explicit apply and exact confirmation for every mutating adapter.
- Keep dry-run output useful but redacted.
- Treat consumer commands as reviewed configuration and execute them with
  `bash -euo pipefail` in the declared directory.
- Keep the frontend AWS role separate from backend infrastructure and release
  roles.
- Make smoke checks bounded, non-mutating, and retry-aware only at the
  workflow layer.
- Preserve backward compatibility for all existing backend commands and
  configuration files.

## Validation matrix

| Area | Required checks |
| --- | --- |
| Configuration | YAML parsing, defaults, explicit config path, CLI precedence, redaction |
| Wrapper | help, dry-run, non-interactive, cloned/piped parity |
| Smoke | HTTP, headers, SPA fallback, assets, API health, CORS, WebSocket, timeout |
| Deploy | immutable ref, required inputs, confirmation, redacted dispatch payload |
| Rollback | immutable consumer ref, confirmation, known-good checkout |
| Lifecycle | non-production guard, DESTROY/NUKE confirmation, dry-run, separate role |
| Workflows | actionlint, reusable input contract, pinned actions and refs |
| Release | tagged wrapper artifact, checksum, release parity, README examples |

## Consumer migration closeout

After the release is published:

1. Pin Villago to the release or full commit SHA.
2. Replace any remaining manual frontend dispatch instructions with wrapper
   commands.
3. Run frontend deploy, smoke, rollback, and lifecycle dry-run against
   staging.
4. Run approved staging lifecycle rehearsal.
5. Record evidence and update the consumer changelog.
6. Keep production frontend lifecycle disabled unless a separately approved
   production recovery/runbook contract is introduced.
