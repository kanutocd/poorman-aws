variable "aws_region" {
  description = "AWS region for this environment."
  type        = string
  default     = "ap-southeast-1"
}

variable "application_name" {
  description = "Stable application identifier used for resource names, tags, and host paths."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,32}$", var.application_name))
    error_message = "application_name must be 2-33 lowercase letters, numbers, or hyphens and start with a letter."
  }
}

variable "environment" {
  description = "Deployment environment."
  type        = string

  validation {
    condition     = contains(["staging", "production"], var.environment)
    error_message = "environment must be staging or production."
  }
}

variable "availability_zone" {
  description = "Single Availability Zone used by the cost-optimized host."
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the environment VPC."
  type        = string
  default     = "10.70.0.0/24"
}

variable "public_subnet_cidr" {
  description = "CIDR block for the single public application subnet."
  type        = string
  default     = "10.70.0.0/26"
}

variable "ami_id" {
  description = "Reviewed AMI containing the Docker and host runtime prerequisites."
  type        = string

  validation {
    condition     = can(regex("^ami-[0-9a-f]+$", var.ami_id))
    error_message = "ami_id must be a valid AMI ID."
  }
}

variable "instance_type" {
  description = "Small EC2 instance type compatible with ami_id."
  type        = string
  default     = "t4g.micro"
}

variable "root_volume_size_gib" {
  description = "Encrypted disposable root volume size."
  type        = number
  default     = 10

  validation {
    condition     = var.root_volume_size_gib >= 8
    error_message = "root_volume_size_gib must be at least 8 GiB."
  }
}

variable "retain_eip" {
  description = "Retain the Elastic IP when a guarded non-production destroy terminates the environment."
  type        = bool
  default     = false
}

variable "data_volume_size_gib" {
  description = "Encrypted data EBS volume size."
  type        = number
  default     = 20

  validation {
    condition     = var.data_volume_size_gib >= 8
    error_message = "data_volume_size_gib must be at least 8 GiB."
  }
}

variable "retain_data_volume" {
  description = "Keep the separate data EBS volume when the EC2 instance is terminated."
  type        = bool
  default     = false
}

variable "allow_destructive_destroy" {
  description = "Allow the guarded non-production teardown to delete protected data and artifacts."
  type        = bool
  default     = false

  validation {
    condition     = !var.allow_destructive_destroy || var.environment != "production"
    error_message = "allow_destructive_destroy may not be enabled for production."
  }
}

variable "artifact_bucket_name" {
  description = "Optional globally unique name for the private deployment bucket."
  type        = string
  default     = null
}

variable "artifact_prefix" {
  description = "S3 prefix containing immutable backend release artifacts."
  type        = string
  default     = "releases"
}

variable "ssm_parameter_path" {
  description = "Environment-specific SSM path readable by the backend instance role."
  type        = string

  validation {
    condition     = can(regex("^/[^/].*[^/]$", var.ssm_parameter_path))
    error_message = "ssm_parameter_path must start and end with a non-slash path component."
  }
}

variable "ssm_session_kms_key_arn" {
  description = "Optional customer-managed KMS key ARN used to encrypt Session Manager session data."
  type        = string
  default     = null

  validation {
    condition = var.ssm_session_kms_key_arn == null || trimspace(var.ssm_session_kms_key_arn) == "" || can(
      regex("^arn:[^:]+:kms:[^:]+:[^:]+:key/.+$", trimspace(var.ssm_session_kms_key_arn))
    )
    error_message = "ssm_session_kms_key_arn must be a KMS key ARN when provided."
  }
}

variable "route53_zone_name" {
  description = "Name of the existing public Route 53 hosted zone."
  type        = string
}

variable "route53_zone_id" {
  description = "Optional hosted-zone ID. When omitted, the public zone is looked up by name."
  type        = string
  default     = null
}

variable "api_hostname" {
  description = "Environment-specific public API hostname."
  type        = string
  default     = null
}

variable "tags" {
  description = "Additional resource tags."
  type        = map(string)
  default     = {}
}
