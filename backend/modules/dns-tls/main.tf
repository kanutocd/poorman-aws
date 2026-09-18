resource "terraform_data" "production_destroy_guard" {
  input = var.environment

  lifecycle {
    prevent_destroy = var.environment == "production"
  }
}

data "aws_route53_zone" "by_name" {
  count        = var.route53_zone_id == null ? 1 : 0
  name         = var.route53_zone_name
  private_zone = false
}

data "aws_route53_zone" "by_id" {
  count   = var.route53_zone_id == null ? 0 : 1
  zone_id = var.route53_zone_id
}

locals {
  zone_id = var.route53_zone_id == null ? data.aws_route53_zone.by_name[0].zone_id : data.aws_route53_zone.by_id[0].zone_id
}

resource "aws_route53_record" "api" {
  zone_id = local.zone_id
  name    = var.api_hostname
  type    = "A"
  ttl     = 60
  records = [var.api_public_ip]
}
