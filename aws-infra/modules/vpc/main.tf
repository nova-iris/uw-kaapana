# ==========================================
# VPC Module Wrapper for Kaapana POC
# ==========================================
# This module wraps terraform-aws-modules/vpc to provide
# Kaapana-specific configuration and interface

# Get availability zones
data "aws_availability_zones" "available" {
  state = "available"
}

# ==========================================
# VPC using terraform-aws-modules/vpc
# ==========================================
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 6.0"

  name = "${var.project_name}-${var.environment}-vpc"
  cidr = var.vpc_cidr

  azs             = length(var.availability_zones) > 0 ? var.availability_zones : slice(data.aws_availability_zones.available.names, 0, 2)
  private_subnets = [for i in range(2) : cidrsubnet(var.vpc_cidr, 8, i + 10)]
  public_subnets  = [for i in range(2) : cidrsubnet(var.vpc_cidr, 8, i + 1)]

  enable_nat_gateway   = true
  enable_vpn_gateway   = false
  enable_dns_hostnames = true
  enable_dns_support   = true

  # Single NAT Gateway for cost optimization
  single_nat_gateway     = true
  one_nat_gateway_per_az = false

  tags = var.common_tags

  # Additional tags for VPC resources
  public_subnet_tags = merge(var.common_tags, {
    Type = "Public"
  })

  private_subnet_tags = merge(var.common_tags, {
    Type = "Private"
  })

  nat_gateway_tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-nat"
  })

  igw_tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-igw"
  })

  public_route_table_tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-public-rt"
  })

  private_route_table_tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-private-rt"
  })
}