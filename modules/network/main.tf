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

# --- Free Gateway Endpoints (attach to private + db route tables) ---

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


