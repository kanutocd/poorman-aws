mock_provider "aws" {
  alias = "mock"
}

run "creates_public_subnet_with_restricted_edge_ports" {
  command = plan

  providers = {
    aws = aws.mock
  }

  variables {
    name               = "example-staging-backend"
    availability_zone  = "us-east-1a"
    vpc_cidr           = "10.70.0.0/24"
    public_subnet_cidr = "10.70.0.0/26"
    tags = {
      Environment = "test"
    }
  }

  assert {
    condition     = aws_vpc.this.enable_dns_support && aws_vpc.this.enable_dns_hostnames
    error_message = "The VPC must provide DNS support and hostnames."
  }

  assert {
    condition     = aws_subnet.public.map_public_ip_on_launch
    error_message = "The application subnet must assign public IPs for the public-host design."
  }

  assert {
    condition     = contains([for rule in aws_security_group.instance.ingress : rule.from_port], 80) && contains([for rule in aws_security_group.instance.ingress : rule.from_port], 443)
    error_message = "The instance security group must expose only HTTP and HTTPS edge ports."
  }
}
