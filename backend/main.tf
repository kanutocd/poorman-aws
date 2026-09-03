locals {
  name = "${var.application_name}-${var.environment}-backend"
  api_hostname = var.api_hostname == null ? (
    var.environment == "production" ? "api.${var.route53_zone_name}" : "api.${var.environment}.${var.route53_zone_name}"
  ) : var.api_hostname
  tags = merge({
    Application = var.application_name
    Environment = var.environment
    ManagedBy   = "opentofu"
    Component   = "backend"
    CostModel   = "poorman"
  }, var.tags)
}

module "networking" {
  source = "./modules/networking"

  name               = local.name
  availability_zone  = var.availability_zone
  vpc_cidr           = var.vpc_cidr
  public_subnet_cidr = var.public_subnet_cidr
  tags               = local.tags
}

module "deployment_artifacts" {
  source = "./modules/deployment-artifacts"

  name            = local.name
  bucket_name     = var.artifact_bucket_name
  artifact_prefix = var.artifact_prefix
  force_destroy   = var.allow_destructive_destroy
  tags            = local.tags
}

module "compute" {
  source = "./modules/compute"

  name                      = local.name
  application_name          = var.application_name
  environment               = var.environment
  ami_id                    = var.ami_id
  instance_type             = var.instance_type
  subnet_id                 = module.networking.public_subnet_id
  security_group_id         = module.networking.instance_security_group_id
  artifact_bucket_name      = module.deployment_artifacts.bucket_name
  artifact_bucket_arn       = module.deployment_artifacts.bucket_arn
  artifact_prefix           = var.artifact_prefix
  ssm_parameter_path        = var.ssm_parameter_path
  ssm_session_kms_key_arn   = var.ssm_session_kms_key_arn
  root_volume_size_gib      = var.root_volume_size_gib
  data_volume_size_gib      = var.data_volume_size_gib
  retain_eip                = var.retain_eip
  retain_data_volume        = var.retain_data_volume
  allow_destructive_destroy = var.allow_destructive_destroy
  availability_zone         = var.availability_zone
  tags                      = local.tags
}

module "dns_tls" {
  source = "./modules/dns-tls"

  route53_zone_name = var.route53_zone_name
  route53_zone_id   = var.route53_zone_id
  api_hostname      = local.api_hostname
  api_public_ip     = module.compute.public_ip
}
