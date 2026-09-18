# Prerequisites

Install only the tools required by the path you will use. Run commands from
the repository root unless a section says otherwise.

## AWS operations

Install AWS CLI v2 and authenticate through the approved operator path. GitHub
Actions uses OIDC instead of a long-lived repository credential. Verify the
active identity before an AWS operation:

```bash
aws sts get-caller-identity
```

Do not place AWS credentials in repository files, examples, workflow inputs, or
documentation.

## GitHub environment synchronization

Install GitHub CLI and authenticate with the required repository permissions:

```bash
gh auth status
```

Keep environment variables and secrets in separate files. Send secret values
through standard input using the repository synchronization utility.

## Repository quality checks

These tools are required when contributing to the infrastructure repository,
not for every consumer operation. Install OpenTofu, Bash, ShellCheck,
actionlint, and Docker with the Compose plugin. Install Packer only when
building an AMI.

Run the aggregate check from the repository root:

```bash
bash bin/quality
```

The check does not run a real OpenTofu apply, destroy, or cloud-backed
integration test.

## Documentation site

This section is for contributors who edit the public documentation. Create the
local documentation environment and build the site:

```bash
python3 -m venv .venv-docs
.venv-docs/bin/python -m pip install --requirement requirements-docs.txt
bin/docs build --strict
```

The build is local and offline with respect to AWS. It writes only generated
files beneath `site/`.
