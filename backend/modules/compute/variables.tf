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
  type = string
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
  type = number
}

variable "data_volume_size_gib" {
  type = number
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
