variable "environment" {
  description = "Deployment environment used to protect production teardown."
  type        = string
}

variable "route53_zone_name" {
  type = string
}

variable "route53_zone_id" {
  type    = string
  default = null
}

variable "api_hostname" {
  type = string
}

variable "api_public_ip" {
  type = string
}
