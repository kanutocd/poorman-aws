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

resource "terraform_data" "production_destroy_guard" {
  input = var.environment

  lifecycle {
    prevent_destroy = var.environment == "production"
  }
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

  name                   = local.name
  bucket_name            = var.artifact_bucket_name
  artifact_prefix        = var.artifact_prefix
  release_retention_days = var.release_retention_days
  force_destroy          = var.allow_destructive_destroy
  tags                   = local.tags
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

resource "aws_backup_vault" "data" {
  count = var.environment == "production" && var.enable_data_volume_backups ? 1 : 0

  name        = "${local.name}-data"
  kms_key_arn = var.backup_kms_key_arn

  tags = merge(local.tags, {
    Name     = "${local.name}-data-backup"
    DataRole = "backup"
  })
}

resource "aws_backup_plan" "data" {
  count = var.environment == "production" && var.enable_data_volume_backups ? 1 : 0

  name = "${local.name}-data"

  rule {
    rule_name         = "daily"
    target_vault_name = aws_backup_vault.data[0].name
    schedule          = "cron(0 3 * * ? *)"

    lifecycle {
      delete_after = 7
    }
  }

  rule {
    rule_name         = "weekly"
    target_vault_name = aws_backup_vault.data[0].name
    schedule          = "cron(0 4 ? * SUN *)"

    lifecycle {
      delete_after = 28
    }
  }

  tags = local.tags
}

resource "aws_iam_role" "backup" {
  count = var.environment == "production" && var.enable_data_volume_backups ? 1 : 0

  name = "${local.name}-backup"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "backup.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = merge(local.tags, { Name = "${local.name}-backup" })
}

resource "aws_iam_role_policy_attachment" "backup" {
  count      = var.environment == "production" && var.enable_data_volume_backups ? 1 : 0
  role       = aws_iam_role.backup[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
}

resource "aws_iam_role_policy_attachment" "backup_restore" {
  count      = var.environment == "production" && var.enable_data_volume_backups ? 1 : 0
  role       = aws_iam_role.backup[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForRestores"
}

resource "aws_backup_selection" "data" {
  count        = var.environment == "production" && var.enable_data_volume_backups ? 1 : 0
  iam_role_arn = aws_iam_role.backup[0].arn
  name         = "${local.name}-data"
  plan_id      = aws_backup_plan.data[0].id

  resources = [module.compute.data_volume_arn]
}
