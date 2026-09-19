# Configure GitHub environments

`bin/poorman-aws` generates the thin consumer workflows and can synchronize the
AWS role secrets required by those workflows. The GitHub CLI token must be
allowed to manage the target repository's environments and secrets.

Run the synchronizer from a checkout of `poorman-aws` or from a consumer
checkout that contains `bin/sync-github-environment`.

1. Copy the example files to private, ignored paths.
2. Replace the example values with the consumer repository's values.
3. Confirm that the target environment is the intended environment; production
   changes require the repository's normal approval.
4. Run the utility without `--apply` to review the dry-run output.
5. Run it with `--apply` after reviewing the names and target environment.

```bash
bin/sync-github-environment \
  --repo CONSUMER_OWNER/CONSUMER_REPOSITORY \
  --environment staging \
  --variables-file /tmp/project-staging.variables.env \
  --secrets-file /tmp/project-staging.secrets.env \
  --apply
```

The utility prints names rather than secret values. Keep variables and secrets
in separate files and never commit either populated file. The reusable workflow
uses the same utility; callers provide the optional
`environment_admin_token` secret rather than the reserved name `github_token`.

To generate consumer-owned workflow callers before configuring the environment,
run:

```bash
bin/poorman-aws --config .poorman-aws.yml onboard
```

Then preview and explicitly apply the standard AWS role synchronization:

```bash
bin/poorman-aws --dry-run --apply \
  --confirm SYNC-GITHUB-ENVIRONMENTS github sync

bin/poorman-aws --apply \
  --confirm SYNC-GITHUB-ENVIRONMENTS github sync
```

The wrapper creates `staging`, `production`, and `ami-build`, then sets the
corresponding `AWS_ROLE_ARN` secrets. For a frontend deployment shape it also
sets `AWS_FRONTEND_ROLE_ARN` in `staging` and `production`. Role names follow
the bootstrap default `<application>-github-<environment>`. It also sets the
dedicated `AWS_AMI_ROLE_ARN` secret in `staging` and `production`, pointing to
the `<application>-github-ami-build` role used by infrastructure's idempotent
AMI prerequisite. The command never prints secret values.

The generated AMI and backend-infrastructure callers also require the consumer
repository secret `POORMAN_ENVIRONMENT_ADMIN_TOKEN`. Set it to a protected
fine-grained token or GitHub App credential that can manage variables in the
consumer environments. This is separate from the AWS role secrets and is used
only after an AMI has been built or reused, when the workflow publishes
`AMI_ID` and `AMI_BUILD_FINGERPRINT`.
