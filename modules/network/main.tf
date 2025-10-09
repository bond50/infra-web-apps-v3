terraform {
  required_version = ">= 1.13.3"
  required_providers {
    aws = { source = "hashicorp/aws" }
  }
}



# NOTE: we no longer read data.aws_region.current.name to avoid the deprecation warning
# We take region via var.region passed from root.

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 6.4"

  name = var.name
  cidr = var.vpc_cidr
  azs  = var.azs

  public_subnets   = var.public_subnet_cidrs
  private_subnets  = var.private_app_subnet_cidrs
  database_subnets = var.private_db_subnet_cidrs

  enable_nat_gateway = var.enable_nat_gateway
  single_nat_gateway = var.enable_nat_gateway

  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge({ Module = "network" }, var.tags)

  public_subnet_tags   = { Tier = "public" }
  private_subnet_tags  = { Tier = "private-app" }
  database_subnet_tags = { Tier = "private-db" }
}

############################################
# NAT INSTANCE (conditional)
# Creates only when:
#   enable_nat_instance = true
# and enable_nat_gateway = false (avoid conflict)
############################################

# Latest Amazon Linux 2023 AMI via SSM
data "aws_ssm_parameter" "al2023_ami" {
  count = var.enable_nat_instance && !var.enable_nat_gateway ? 1 : 0
  name  = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

# Security Group for NAT instance
resource "aws_security_group" "nat" {
  count       = var.enable_nat_instance && !var.enable_nat_gateway ? 1 : 0
  name        = "${var.name}-nat-sg"
  description = "NAT instance SG"
  vpc_id      = module.vpc.vpc_id

  # Allow SSH only from your allowed CIDR
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ssh_allowed_cidr]
  }

  # Allow forwarding from inside the VPC (private subnets will send traffic to it)
  ingress {
    description = "VPC ingress (NAT forwarding)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    description = "All egress"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge({ Name = "${var.name}-nat-sg" }, var.tags)
}

# NAT Instance in first public subnet
resource "aws_instance" "nat" {
  count                       = var.enable_nat_instance && !var.enable_nat_gateway ? 1 : 0
  ami                         = data.aws_ssm_parameter.al2023_ami[0].value
  instance_type               = "t3.micro"
  subnet_id                   = module.vpc.public_subnet_ids[0]
  vpc_security_group_ids      = [aws_security_group.nat[0].id]
  associate_public_ip_address = true

  # NAT instance must disable source/dest check
  source_dest_check = false

  user_data = <<-EOT
    #!/usr/bin/env bash
    set -euxo pipefail
    # Enable IP forwarding
    echo 1 > /proc/sys/net/ipv4/ip_forward
    sed -i 's/^#*net.ipv4.ip_forward.*/net.ipv4.ip_forward=1/' /etc/sysctl.conf
    sysctl -p

    # Simple MASQUERADE
    iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
    # (Optional) Persist rules across reboots
    dnf -y install iptables-services || yum -y install iptables-services
    service iptables save || true
    systemctl enable iptables || true
  EOT

  tags = merge({ Name = "${var.name}-nat" }, var.tags)
}

# Route private route tables to NAT instance
resource "aws_route" "private_to_nat" {
  count                  = var.enable_nat_instance && !var.enable_nat_gateway ? length(module.vpc.private_route_table_ids) : 0
  route_table_id         = module.vpc.private_route_table_ids[count.index]
  destination_cidr_block = "0.0.0.0/0"
  instance_id            = aws_instance.nat[0].id

  depends_on = [aws_instance.nat]
}

# Route db route tables to NAT instance (if you want db subnets to have egress)
resource "aws_route" "db_to_nat" {
  count                  = var.enable_nat_instance && !var.enable_nat_gateway ? length(module.vpc.database_route_table_ids) : 0
  route_table_id         = module.vpc.database_route_table_ids[count.index]
  destination_cidr_block = "0.0.0.0/0"
  instance_id            = aws_instance.nat[0].id

  depends_on = [aws_instance.nat]
}


# S3 Gateway endpoint
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = module.vpc.vpc_id
  service_name      = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"

  route_table_ids = concat(
    module.vpc.private_route_table_ids,
    module.vpc.database_route_table_ids
  )

  tags = merge(var.tags, { Name = "${var.name}-s3-endpoint" })
}

# DynamoDB Gateway endpoint
resource "aws_vpc_endpoint" "dynamodb" {
  vpc_id            = module.vpc.vpc_id
  service_name      = "com.amazonaws.${var.region}.dynamodb"
  vpc_endpoint_type = "Gateway"

  route_table_ids = concat(
    module.vpc.private_route_table_ids,
    module.vpc.database_route_table_ids
  )

  tags = merge(var.tags, { Name = "${var.name}-dynamodb-endpoint" })
}


