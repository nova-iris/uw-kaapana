terraform {
  required_version = ">= 1.5.0"
}

provider "aws" {
  profile = "kaapana"
  region  = var.aws_region
}

# Get AWS account info for tagging
data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

# Get Ubuntu 24.04 LTS AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Get availability zones
data "aws_availability_zones" "available" {
  state = "available"
}

# Local values for common configuration
locals {
  project_name = "kaapana-poc"
  environment  = "poc"

  common_tags = {
    Project     = local.project_name
    Environment = local.environment
    ManagedBy   = "terraform"
    Owner       = "kaapana-team"
  }

  # User data variables for EC2 instances
  user_data_vars = {
    project_name = local.project_name
    environment  = local.environment
  }

  # SSH key configuration
  key_name = var.create_key_pair ? var.key_name : null
}

# ==========================================
# VPC Module
# ==========================================
module "vpc" {
  source = "./modules/vpc"

  project_name      = local.project_name
  environment       = local.environment
  vpc_cidr          = var.vpc_cidr
  availability_zones = var.availability_zones
  common_tags       = local.common_tags
}

# ==========================================
# Security Module
# ==========================================
module "security" {
  source = "./modules/security"

  project_name      = local.project_name
  environment       = local.environment
  vpc_id            = module.vpc.vpc_id
  vpc_cidr          = module.vpc.vpc_cidr
  common_tags       = local.common_tags
  allowed_cidr_blocks = var.allowed_cidr_blocks
  ssh_cidr_blocks   = var.ssh_cidr_blocks
  enable_ebs_encryption = var.enable_ebs_encryption
  key_name          = local.key_name
}

# ==========================================
# Storage Module
# ==========================================
module "storage" {
  source = "./modules/storage"

  project_name        = local.project_name
  environment         = local.environment
  common_tags         = local.common_tags
  data_volume_size    = var.data_volume_size
  data_volume_type    = var.data_volume_type
  data_volume_iops    = var.data_volume_iops
  data_volume_throughput = var.data_volume_throughput
  enable_ebs_encryption = var.enable_ebs_encryption
  availability_zones  = [data.aws_availability_zones.available.names[0]]
  kms_key_id          = module.security.kms_key_arn
}

# ==========================================
# SSH Key Pair
# ==========================================
resource "aws_key_pair" "kaapana" {
  count      = var.create_key_pair ? 1 : 0
  key_name   = var.key_name
  public_key = file(var.public_key_path)

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-${local.environment}-key"
  })
}

# ==========================================
# EC2 Module
# ==========================================
module "ec2" {
  source = "./modules/ec2"

  project_name       = local.project_name
  environment        = local.environment
  common_tags        = local.common_tags
  instance_type      = var.instance_type
  ami_id             = data.aws_ami.ubuntu.id
  key_name           = var.create_key_pair ? var.key_name : null
  public_key_path    = var.create_key_pair ? var.public_key_path : null
  subnet_id          = module.vpc.public_subnet_ids[0]
  security_group_ids = [module.security.kaapana_security_group_id]
  iam_instance_profile = module.security.instance_profile_name
  root_volume_size   = var.root_volume_size
  data_volume_size   = var.data_volume_size
  data_volume_type   = var.data_volume_type
  data_volume_ids    = module.storage.data_volume_ids
  enable_ebs_encryption = var.enable_ebs_encryption
  kms_key_id         = module.security.kms_key_arn
  user_data_vars     = local.user_data_vars
  user_data          = file("${path.module}/user_data.sh")
}

# ==========================================
# Elastic IP Module
# ==========================================
module "elastic_ip" {
  source = "./modules/elastic-ip"

  project_name = local.project_name
  environment  = local.environment
  common_tags  = local.common_tags
  instance_id  = module.ec2.instance_id
  vpc          = true
}