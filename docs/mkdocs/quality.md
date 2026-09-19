# Quality checks

Run repository quality checks from the repository root:

```bash
bash bin/quality
actionlint .github/workflows/*.yml
```

The quality command performs backend-disabled OpenTofu initialization,
validation, plan-only module tests, policy and secret-handling tests, Docker
Compose validation, Packer formatting/validation, Bash syntax checks,
ShellCheck, repository hygiene checks, and `bin/docs lint`. It never runs a
real OpenTofu apply, destroy, or cloud-backed integration test.

Workflow action references are required to use published release tags such as
`actions/checkout@v7`; branch names, local workflow paths, and commit SHAs do
not satisfy the repository's action-reference contract. Reusable `poorman-aws`
workflow callers use the published infrastructure release tag as well.

The GitHub Pages workflow runs the same documentation build command used
locally: `bin/docs build --strict`. It does not need AWS credentials.

## Local prerequisites

Install these tools before running the local command:

- OpenTofu;
- Packer;
- Docker with the Compose plugin;
- Bash, ShellCheck, and the documentation lint tools used by `bin/docs lint`;
- actionlint for workflow validation.

Use native OpenTofu and Packer installations or the same tool setup used by
CI. Snap-constrained OpenTofu installations may fail when invoked from nested
quality scripts even when a direct command succeeds; use a native installation
or run the OpenTofu job in GitHub Actions if that confinement cannot be
changed. Packer plugin initialization also requires registry/network access.

The OpenTofu module tests use mocked providers and `command = plan`; they must
not be changed to create AWS resources in pull-request quality checks.

## Documentation site

Install the pinned documentation dependencies from the repository root, then
build or preview the site through the shared entry point:

```bash
python3 -m venv .venv-docs
.venv-docs/bin/python -m pip install --requirement requirements-docs.txt
bin/docs build --strict
bin/docs serve
```

`bin/docs build` writes generated output to `site/`. Do not commit that
directory. The GitHub Pages workflow invokes the same `bin/docs build --strict`
command and publishes the resulting directory.

When the optional documentation linters are installed, run them from the
repository root:

```bash
bin/docs lint
```

`bin/docs lint` runs Vale, Markdownlint, and offline Lychee against the public
documentation sources. It prefers cached tools under `.docs-tools/` and falls
back to tools installed on the local `PATH`. The offline Lychee mode checks
local links without making external network requests. A documentation build
can still succeed while a network-backed link is unavailable; treat that as a
link-check result, not an infrastructure failure.
