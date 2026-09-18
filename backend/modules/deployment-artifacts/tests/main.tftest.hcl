mock_provider "aws" {
  alias = "mock"
}

run "creates_private_versioned_artifact_bucket" {
  command = plan

  providers = {
    aws = aws.mock
  }

  variables {
    environment     = "staging"
    name            = "example-staging-backend"
    bucket_name     = "example-staging-artifacts"
    artifact_prefix = "releases"
    force_destroy   = false
    tags = {
      Environment = "test"
    }
  }

  assert {
    condition     = aws_s3_bucket.this.bucket == "example-staging-artifacts"
    error_message = "The configured artifact bucket name must be preserved."
  }

  assert {
    condition     = aws_s3_bucket_public_access_block.this.block_public_acls && aws_s3_bucket_public_access_block.this.restrict_public_buckets
    error_message = "Artifact buckets must block public access."
  }

  assert {
    condition     = aws_s3_bucket_versioning.this.versioning_configuration[0].status == "Enabled"
    error_message = "Artifact buckets must enable versioning."
  }

  assert {
    condition     = aws_s3_bucket_lifecycle_configuration.this.rule[0].expiration[0].days == 30
    error_message = "Current release objects must expire after the 30-day rollback window."
  }

  assert {
    condition     = aws_s3_bucket_lifecycle_configuration.this.rule[0].noncurrent_version_expiration[0].noncurrent_days == 30
    error_message = "Noncurrent release versions must expire after 30 days."
  }
}
