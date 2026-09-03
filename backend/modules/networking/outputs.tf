output "vpc_id" {
  value = aws_vpc.this.id
}

output "public_subnet_id" {
  value = aws_subnet.public.id
}

output "instance_security_group_id" {
  value = aws_security_group.instance.id
}
