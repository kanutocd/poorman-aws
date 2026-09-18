# Build an AMI

The Packer profile builds a reusable host base, not an application image. Use
the wrapper to dispatch the reusable AMI workflow from a consumer repository.
Run direct Packer validation only when contributing to the infrastructure
repository.

## Dispatch the AMI workflow

Configure an immutable infrastructure reference, application name, AWS region,
and deployment values in the consumer configuration. Preview the dispatch with
the required public subnet and temporary builder CIDR:

```bash
bin/poorman-aws --dry-run ami build \
  --subnet-id SUBNET_ID \
  --ssh-cidr BUILDER_CIDR
```

Review the generated workflow inputs and then repeat without `--dry-run` to
dispatch the build. The wrapper requires an immutable infrastructure ref and
does not accept `main` or `master` for operational commands.

## Validate the Packer profile locally

Run these commands from `backend/packer` when changing the Packer profile:

```bash
packer init -upgrade=false .
packer fmt -check .
packer validate -var-file=example.pkrvars.hcl .
```

Keep builder permissions temporary and narrowly scoped. Do not commit
credentials, private keys, populated variable files, Packer manifests, or
builder SSH state. Review the generated AMI identifier before selecting it for
an environment, then run the normal infrastructure plan before applying the
host change.
