variable "name" {
  type = string
}

variable "bucket_name" {
  description = "Optional globally unique bucket name."
  type        = string
  default     = null
}

variable "artifact_prefix" {
  type = string
}

variable "force_destroy" {
  description = "Allow an explicitly authorized non-production teardown to remove all bucket objects."
  type        = bool
  default     = false
}

variable "tags" {
  type    = map(string)
  default = {}
}
