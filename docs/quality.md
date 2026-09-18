# Quality checks

Run repository quality checks from the project root:

```bash
bash bin/quality
actionlint .github/workflows/*.yml
```

The quality command performs backend-disabled OpenTofu initialization,
validation, plan-only module tests, policy and secret-handling tests, Docker
Compose validation, Packer formatting/validation, Bash syntax checks,
ShellCheck, and repository hygiene checks. It never runs a real OpenTofu
apply, destroy, or cloud-backed integration test.

## Local prerequisites

Install these tools before running the local command:

- OpenTofu;
- Packer;
- Docker with the Compose plugin;
- Bash and ShellCheck;
- actionlint for workflow validation.

Use native OpenTofu and Packer installations or the same tool setup used by
CI. Snap-constrained OpenTofu installations may fail when invoked from nested
quality scripts even when a direct command succeeds; use a native installation
or run the OpenTofu job in GitHub Actions if that confinement cannot be
changed. Packer plugin initialization also requires registry/network access.

The OpenTofu module tests use mocked providers and `command = plan`; they must
not be changed to create AWS resources in pull-request quality checks.
