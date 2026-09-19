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

### One-time OpenTofu state bucket

Before the first infrastructure deployment, an AWS administrator must create
the S3 bucket that stores the remote OpenTofu state. Choose a globally unique
bucket name and keep it in the same region used by the infrastructure.

```bash
export AWS_REGION=ap-southeast-1
export STATE_BUCKET=my-application-tofu-state

# us-east-1 does not accept a LocationConstraint.
if [[ "${AWS_REGION}" == "us-east-1" ]]; then
  aws s3api create-bucket \
    --bucket "${STATE_BUCKET}" \
    --region "${AWS_REGION}"
else
  aws s3api create-bucket \
    --bucket "${STATE_BUCKET}" \
    --region "${AWS_REGION}" \
    --create-bucket-configuration "LocationConstraint=${AWS_REGION}"
fi

aws s3api put-public-access-block \
  --bucket "${STATE_BUCKET}" \
  --public-access-block-configuration \
    BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

aws s3api put-bucket-versioning \
  --bucket "${STATE_BUCKET}" \
  --versioning-configuration Status=Enabled

aws s3api put-bucket-encryption \
  --bucket "${STATE_BUCKET}" \
  --server-side-encryption-configuration \
    '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
```

Verify the bucket configuration before supplying `STATE_BUCKET` to the
deployment workflow:

```bash
aws s3api get-bucket-location --bucket "${STATE_BUCKET}"
aws s3api get-bucket-versioning --bucket "${STATE_BUCKET}"
aws s3api get-public-access-block --bucket "${STATE_BUCKET}"
```

Do not delete this bucket while any environment uses it. Its state keys are
selected by application and environment, and bucket versioning provides a
recovery path for accidental state changes.

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
