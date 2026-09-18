variable "environment" {
  description = "Deployment environment used to protect production teardown."
  type        = string
}

variable "name" {
  type = string
}

variable "availability_zone" {
  type = string
}

variable "vpc_cidr" {
  type = string
}

variable "public_subnet_cidr" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
