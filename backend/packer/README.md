# application backend AMI

This Packer profile builds the reusable ARM64 host base consumed by
`backend`. It does not contain the application image or runtime
secrets. Application releases continue through the immutable S3 release path;
host administration uses AWS Systems Manager Session Manager.

The AMI contains:

- patched Amazon Linux 2023 ARM64;
- Docker and a pinned Docker Compose plugin;
- AWS CLI, the Amazon SSM Agent, `jq`, `xfsprogs`, and `zstd`;
- the non-root `application` host user in the Docker group; and
- the directories and host prerequisites used by cloud-init and release
  activation.

The default builder is `t4g.micro`, matching the OpenTofu examples. The
temporary builder needs public Internet access for package and Compose
downloads. It is terminated after the AMI is created.

## Install Packer

The Packer template requires Packer `1.11.0` or newer. On Ubuntu or Debian,
install the official HashiCorp package:

```bash
wget -O - https://apt.releases.hashicorp.com/gpg |
  sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
https://apt.releases.hashicorp.com \
$(grep -oP '(?<=UBUNTU_CODENAME=).*' /etc/os-release || lsb_release -cs) main" |
  sudo tee /etc/apt/sources.list.d/hashicorp.list

sudo apt update
sudo apt install packer
packer version
```

For other operating systems or installation methods, use the
[official Packer installation guide](https://developer.hashicorp.com/packer/install).

## Local build

Install Packer, configure AWS credentials, and select a public subnet and
operator CIDR. The CIDR must be narrow; it is used only by the temporary
builder security group.

```bash
cd backend/packer
cp example.pkrvars.hcl local.pkrvars.hcl
```

then replace `subnet_id` and `ssh_cidr` in `local.pkrvars.hcl`.


For the Packer build, use an existing public subnet—preferably the default VPC
subnet in the chosen region, such as `ap-southeast-1`.


Find one using the AWS CLI:


```bash
AWS_PROFILE=administrator aws ec2 describe-subnets \
  --region ap-southeast-1 \
  --filters Name=default-for-az,Values=true \
  --query 'Subnets[?MapPublicIpOnLaunch].{ID:SubnetId,AZ:AvailabilityZone,VPC:VpcId}' \
  --output table
```

Sample aws cli output:

```text
--------------------------------------------------------------------------
|                             DescribeSubnets                            |
+-----------------+----------------------------+-------------------------+
|       AZ        |            ID              |           VPC           |
+-----------------+----------------------------+-------------------------+
|  ap-southeast-1b|  subnet-0677ac5b9a45d8346  |  vpc-09b571b144b6003ad  |
|  ap-southeast-1c|  subnet-05953623f4e7a5820  |  vpc-09b571b144b6003ad  |
|  ap-southeast-1a|  subnet-06e47b76f86c720be  |  vpc-09b571b144b6003ad  |
+-----------------+----------------------------+-------------------------+
```

Use a subnet in the same region and Availability Zone as the build, such as
`ap-southeast-1a`.

Get your public IP:

```bash
curl -4 https://checkip.amazonaws.com
```

Then use the ipv4 public IP address as the `ssh_cidr` block value. e.g `221.121.102.30`

then the `ssh_cidr` value would be: `221.121.102.30/32`

Then finally initialize, validate the variable file, and `packer build`:

```bash
packer init .
packer fmt -check .
packer validate -var-file=local.pkrvars.hcl .
packer build -var-file=local.pkrvars.hcl .
```

Read the resulting AMI ID from `manifest.json`, review it, and place it in the
selected OpenTofu environment's `ami_id` variable. Do not commit
`local.pkrvars.hcl` or `manifest.json`.

## CI build

A consumer repository's AMI workflow should be manually dispatched because
each build creates temporary EC2/EBS resources and an AMI. The workflow should
use GitHub OIDC and a protected `ami-build` environment, and publish only the
sanitized Packer manifest as an artifact.

The AMI build role must be limited to the selected build subnet and temporary
builder resources. It must not have permission to change the application runtime
instances, DNS, certificates, S3 release objects, or frontend resources.

AMI builds are regional. Build a new AMI when the base operating system,
Docker/Compose version, or required host tooling changes; do not rebuild for
ordinary backend application releases.
