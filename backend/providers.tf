provider "aws" {
  region = var.aws_region

  default_tags {
    tags = merge({
      Application = var.application_name
      Environment = var.environment
      ManagedBy   = "opentofu"
      Component   = "backend"
      CostModel   = "poorman"
    }, var.tags)
  }
}
