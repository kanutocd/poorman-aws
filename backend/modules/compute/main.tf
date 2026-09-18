data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}
data "aws_region" "current" {}
data "aws_kms_key" "ssm" {
  key_id = "alias/aws/ssm"
}

locals {
  parameter_path      = trimsuffix(var.ssm_parameter_path, "/")
  session_kms_key_arn = trimspace(var.ssm_session_kms_key_arn == null ? "" : var.ssm_session_kms_key_arn)
}

resource "aws_iam_role" "instance" {
  name = "${var.name}-instance"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "instance" {
  name = "artifact-and-runtime-access"
  role = aws_iam_role.instance.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat([
      {
        Sid      = "ListReleaseArtifacts"
        Effect   = "Allow"
        Action   = ["s3:GetBucketLocation", "s3:ListBucket"]
        Resource = var.artifact_bucket_arn
        Condition = {
          StringLike = {
            "s3:prefix" = [
              var.artifact_prefix,
              "${var.artifact_prefix}/*",
            ]
          }
        }
      },
      {
        Sid      = "ReadReleaseArtifacts"
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:GetObjectVersion"]
        Resource = "${var.artifact_bucket_arn}/${var.artifact_prefix}/*"
      },
      {
        Sid    = "ReadRuntimeParameters"
        Effect = "Allow"
        Action = ["ssm:DescribeParameters", "ssm:GetParameter", "ssm:GetParameters", "ssm:GetParametersByPath"]
        Resource = [
          "arn:${data.aws_partition.current.partition}:ssm:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:parameter${local.parameter_path}",
          "arn:${data.aws_partition.current.partition}:ssm:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:parameter${local.parameter_path}/*",
        ]
      },
      {
        Sid      = "DecryptSsmParameters"
        Effect   = "Allow"
        Action   = ["kms:Decrypt"]
        Resource = data.aws_kms_key.ssm.arn
      },
      ], local.session_kms_key_arn == "" ? [] : [{
        Sid      = "DecryptSessionManagerDataKey"
        Effect   = "Allow"
        Action   = ["kms:Decrypt"]
        Resource = local.session_kms_key_arn
    }])
  })
}

resource "aws_iam_role_policy_attachment" "ssm_managed_instance_core" {
  role       = aws_iam_role.instance.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "this" {
  name = "${var.name}-instance"
  role = aws_iam_role.instance.name
  tags = var.tags

  depends_on = [aws_iam_role_policy_attachment.ssm_managed_instance_core]
}

resource "aws_eip" "this" {
  domain = "vpc"

  tags = merge(var.tags, { Name = "${var.name}-eip" })

  lifecycle {
    prevent_destroy = var.retain_eip
  }
}

resource "aws_ebs_volume" "retained_data" {
  count = var.retain_data_volume ? 1 : 0

  availability_zone = var.availability_zone
  encrypted         = true
  size              = var.data_volume_size_gib
  type              = "gp3"

  tags = merge(var.tags, {
    Name     = "${var.name}-data"
    DataRole = "persistent"
  })

  lifecycle {
    prevent_destroy = var.retain_data_volume && !var.allow_destructive_destroy
  }
}

resource "aws_ebs_volume" "disposable_data" {
  count = var.retain_data_volume ? 0 : 1

  availability_zone = var.availability_zone
  encrypted         = true
  size              = var.data_volume_size_gib
  type              = "gp3"

  tags = merge(var.tags, {
    Name     = "${var.name}-data"
    DataRole = "disposable"
  })
}

resource "aws_instance" "this" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [var.security_group_id]
  associate_public_ip_address = true
  ebs_optimized               = true
  iam_instance_profile        = aws_iam_instance_profile.this.name
  user_data = templatefile("${path.module}/bootstrap.sh.tftpl", {
    application_name              = var.application_name
    environment                   = var.environment
    root_dir                      = "/srv/${var.application_name}"
    data_volume_id                = var.retain_data_volume ? aws_ebs_volume.retained_data[0].id : aws_ebs_volume.disposable_data[0].id
    data_device_name              = "/dev/sdf"
    data_mount_point              = "/srv/${var.application_name}-data"
    artifact_bucket_name          = var.artifact_bucket_name
    artifact_prefix               = var.artifact_prefix
    ssm_parameter_path            = var.ssm_parameter_path
    render_runtime_env_script_b64 = base64encode(file("${path.module}/../../scripts/render-runtime-env"))
    activate_release_script_b64   = base64encode(file("${path.module}/../../scripts/activate-release"))
  })

  metadata_options {
    http_endpoint               = "enabled"
    http_protocol_ipv6          = "disabled"
    http_put_response_hop_limit = 1
    http_tokens                 = "required"
    instance_metadata_tags      = "enabled"
  }

  root_block_device {
    delete_on_termination = true
    encrypted             = true
    volume_size           = var.root_volume_size_gib
    volume_type           = "gp3"
  }

  tags = merge(var.tags, {
    Name = var.name
    Role = "backend"
  })

  lifecycle {
    create_before_destroy = true

    precondition {
      condition     = var.environment != "production" || var.retain_eip
      error_message = "Production requires retain_eip = true."
    }

    precondition {
      condition     = var.environment != "production" || var.retain_data_volume
      error_message = "Production requires retain_data_volume = true."
    }
  }
}

resource "aws_eip_association" "this" {
  allocation_id = aws_eip.this.id
  instance_id   = aws_instance.this.id
}

resource "aws_volume_attachment" "data" {
  device_name = "/dev/sdf"
  instance_id = aws_instance.this.id
  volume_id = var.retain_data_volume ? (
    aws_ebs_volume.retained_data[0].id
  ) : aws_ebs_volume.disposable_data[0].id

  depends_on = [aws_instance.this]
}
