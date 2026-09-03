packer {
  required_version = ">= 1.11.0"

  required_plugins {
    amazon = {
      source  = "github.com/hashicorp/amazon"
      version = "~> 1.8"
    }
  }
}

variable "aws_region" {
  description = "AWS region used by the temporary Packer builder and resulting AMI."
  type        = string
  default     = "ap-southeast-1"
}

variable "application_name" {
  description = "Stable application identifier used for AMI naming and host paths."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,32}$", var.application_name))
    error_message = "The application name must be 2-33 lowercase letters, numbers, or hyphens and start with a letter."
  }
}

variable "instance_type" {
  description = "Temporary ARM64 builder instance type."
  type        = string
  default     = "t4g.micro"
}

variable "source_ami_name_filter" {
  description = "Amazon Linux 2023 ARM64 source AMI filter."
  type        = string
  default     = "al2023-ami-2023.*-kernel-6.1-arm64"
}

variable "source_ami_owner" {
  description = "Source AMI owner."
  type        = string
  default     = "amazon"
}

variable "subnet_id" {
  description = "Optional public subnet for the temporary builder."
  type        = string
  default     = null
}

variable "ssh_cidr" {
  description = "Single operator or runner CIDR allowed to reach the temporary builder."
  type        = string

  validation {
    condition     = can(cidrhost(var.ssh_cidr, 0))
    error_message = "The SSH CIDR must be a valid CIDR block."
  }
}

variable "ami_name_prefix" {
  description = "Prefix for the immutable application backend AMI name."
  type        = string
  default     = "application-backend"

  validation {
    condition     = can(regex("^[a-zA-Z0-9][a-zA-Z0-9-]{2,48}$", var.ami_name_prefix))
    error_message = "The AMI name prefix must be 3-49 characters using letters, numbers, and hyphens."
  }
}

variable "compose_version" {
  description = "Pinned Docker Compose plugin release installed in the AMI."
  type        = string
  default     = "v2.39.2"
}

source "amazon-ebs" "application_backend" {
  region                                = var.aws_region
  instance_type                         = var.instance_type
  subnet_id                             = var.subnet_id
  ssh_username                          = "ec2-user"
  ssh_interface                         = "public_ip"
  associate_public_ip_address           = true
  temporary_security_group_source_cidrs = [var.ssh_cidr]

  ami_name = "${var.ami_name_prefix}-{{timestamp}}"

  source_ami_filter {
    filters = {
      name                = var.source_ami_name_filter
      root-device-type    = "ebs"
      virtualization-type = "hvm"
      architecture        = "arm64"
    }
    owners      = [var.source_ami_owner]
    most_recent = true
  }

  launch_block_device_mappings {
    device_name           = "/dev/xvda"
    volume_type           = "gp3"
    volume_size           = 10
    delete_on_termination = true
    encrypted             = true
  }

  imds_support = "v2.0"

  run_tags = {
    Application = var.application_name
    Component   = "backend-ami-builder"
    ManagedBy   = "packer"
  }

  tags = {
    Application  = var.application_name
    Component    = "backend-host-base"
    ManagedBy    = "packer"
    Architecture = "arm64"
  }
}

build {
  name    = "${var.application_name}-backend"
  sources = ["source.amazon-ebs.application_backend"]

  provisioner "shell" {
    script = "${path.root}/scripts/bake.sh"
    environment_vars = [
      "COMPOSE_VERSION=${var.compose_version}",
      "APPLICATION_NAME=${var.application_name}",
    ]
  }

  post-processor "manifest" {
    output     = "manifest.json"
    strip_path = true
    custom_data = {
      application     = var.application_name
      component       = "backend-host-base"
      architecture    = "arm64"
      compose_version = var.compose_version
      source_ami      = "${build.SourceAMI}"
    }
  }
}
