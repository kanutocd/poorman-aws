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

variable "release_retention_days" {
  description = "Number of days to retain current immutable release objects."
  type        = number
  default     = 30

  validation {
    condition     = var.release_retention_days >= 1
    error_message = "release_retention_days must be at least 1 day."
  }
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
