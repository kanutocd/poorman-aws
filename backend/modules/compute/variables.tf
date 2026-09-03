variable "name" {
  type = string
}

variable "application_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "ami_id" {
  type = string
}

variable "instance_type" {
  description = "EC2 instance type compatible with ami_id."
  type        = string
  default     = "t4g.micro"
}

variable "subnet_id" {
  type = string
}

variable "security_group_id" {
  type = string
}

variable "artifact_bucket_name" {
  type = string
}

variable "artifact_bucket_arn" {
  type = string
}

variable "artifact_prefix" {
  type = string
}

variable "ssm_parameter_path" {
  type = string
}

variable "ssm_session_kms_key_arn" {
  type    = string
  default = null
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

variable "data_volume_size_gib" {
  description = "Encrypted data EBS volume size."
  type        = number
  default     = 20

  validation {
    condition     = var.data_volume_size_gib >= 8
    error_message = "data_volume_size_gib must be at least 8 GiB."
  }
}

variable "retain_eip" {
  description = "Retain the Elastic IP when a guarded non-production destroy terminates the environment."
  type        = bool
}

variable "retain_data_volume" {
  description = "Keep the separate data EBS volume when the EC2 instance is terminated."
  type        = bool
}

variable "allow_destructive_destroy" {
  description = "Allow the guarded non-production teardown to delete a retained data volume."
  type        = bool
  default     = false
}

variable "availability_zone" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
