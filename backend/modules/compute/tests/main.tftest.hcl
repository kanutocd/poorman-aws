mock_provider "aws" {
  alias = "mock"
}

run "uses_default_host_and_volume_sizes" {
  command = plan

  providers = {
    aws = aws.mock
  }

  variables {
    name                 = "example-staging-backend"
    application_name     = "application"
    environment          = "staging"
    ami_id               = "ami-0123456789abcdef0"
    subnet_id            = "subnet-0123456789abcdef0"
    security_group_id    = "sg-0123456789abcdef0"
    artifact_bucket_name = "example-artifacts"
    artifact_bucket_arn  = "arn:aws:s3:::example-artifacts"
    artifact_prefix      = "releases"
    ssm_parameter_path   = "/application/staging"
    availability_zone    = "us-east-1a"
    retain_eip           = false
    retain_data_volume   = false
  }

  assert {
    condition     = aws_instance.this.instance_type == "t4g.micro"
    error_message = "The compute module default instance type must remain t4g.micro."
  }

  assert {
    condition     = aws_instance.this.root_block_device[0].volume_size == 10
    error_message = "The compute module default root volume size must remain 10 GiB."
  }

  assert {
    condition     = aws_ebs_volume.disposable_data[0].size == 20
    error_message = "The compute module default data volume size must remain 20 GiB."
  }
}

run "accepts_custom_host_and_volume_sizes" {
  command = plan

  providers = {
    aws = aws.mock
  }

  variables {
    name                 = "example-production-backend"
    application_name     = "application"
    environment          = "production"
    ami_id               = "ami-0123456789abcdef0"
    instance_type        = "t4g.small"
    root_volume_size_gib = 16
    data_volume_size_gib = 40
    subnet_id            = "subnet-0123456789abcdef0"
    security_group_id    = "sg-0123456789abcdef0"
    artifact_bucket_name = "example-artifacts"
    artifact_bucket_arn  = "arn:aws:s3:::example-artifacts"
    artifact_prefix      = "releases"
    ssm_parameter_path   = "/application/production"
    availability_zone    = "us-east-1a"
    retain_eip           = true
    retain_data_volume   = true
  }

  assert {
    condition     = aws_instance.this.instance_type == "t4g.small"
    error_message = "The configured instance type must be passed to the EC2 instance."
  }

  assert {
    condition     = aws_instance.this.root_block_device[0].volume_size == 16
    error_message = "The configured root volume size must be passed to the EC2 instance."
  }

  assert {
    condition     = aws_ebs_volume.retained_data[0].size == 40
    error_message = "The configured data volume size must be passed to the retained EBS volume."
  }
}
