# Configure GitHub environments

`bin/poorman-aws` does not currently provide a direct environment-sync command.
Use its `onboard` command to generate thin consumer workflows, then use the
repository synchronizer or GitHub's settings UI to create and update the
environment values. The GitHub token must be allowed to manage the target
repository's environment variables and secrets.

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

Onboarding does not create GitHub environments or upload their values. It
generates workflows that read protected GitHub variables and secrets after you
configure them.
