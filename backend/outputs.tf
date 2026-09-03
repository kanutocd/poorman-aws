output "architecture" {
  description = "Provisioned backend architecture."
  value       = "single public EC2 host + Internet Gateway + SSM + private S3 artifacts"
}

output "vpc_id" {
  value = module.networking.vpc_id
}

output "public_subnet_id" {
  value = module.networking.public_subnet_id
}

output "instance_id" {
  value = module.compute.instance_id
}

output "instance_public_ip" {
  value = module.compute.public_ip
}

output "instance_security_group_id" {
  value = module.networking.instance_security_group_id
}

output "deployment_bucket" {
  value = module.deployment_artifacts.bucket_name
}

output "deployment_bucket_arn" {
  value = module.deployment_artifacts.bucket_arn
}

output "instance_role_arn" {
  value = module.compute.instance_role_arn
}

output "ssm_start_session_command" {
  description = "AWS CLI command for a Session Manager shell on the backend host."
  value       = "aws ssm start-session --region ${var.aws_region} --target ${module.compute.instance_id}"
}

output "api_record_target" {
  description = "Elastic IP target of the OpenTofu-managed API record."
  value       = module.compute.public_ip
}

output "api_eip_allocation_id" {
  description = "Elastic IP allocation ID to preserve across backend host replacement."
  value       = module.compute.eip_allocation_id
}

output "data_volume_id" {
  description = "Attached backend data EBS volume ID."
  value       = module.compute.data_volume_id
}

output "api_hostname" {
  value = module.dns_tls.api_hostname
}
