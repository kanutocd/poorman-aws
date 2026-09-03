output "instance_id" {
  value = aws_instance.this.id
}

output "public_ip" {
  description = "Current public IP, static while the environment is managed outside destructive teardown."
  value       = aws_eip.this.public_ip
}

output "eip_allocation_id" {
  description = "OpenTofu-managed Elastic IP allocation ID for host replacement verification."
  value       = aws_eip.this.id
}

output "data_volume_id" {
  description = "Attached data EBS volume ID."
  value = var.retain_data_volume ? (
    aws_ebs_volume.retained_data[0].id
  ) : aws_ebs_volume.disposable_data[0].id
}

output "instance_role_arn" {
  value = aws_iam_role.instance.arn
}
