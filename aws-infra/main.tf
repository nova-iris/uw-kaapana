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

  project_name       = local.project_name
  environment        = local.environment
  vpc_cidr           = var.vpc_cidr
  availability_zones = var.availability_zones
  common_tags        = local.common_tags
}

# ==========================================
# Security Module
# ==========================================
module "security" {
  source = "./modules/security"

  project_name          = local.project_name
  environment           = local.environment
  vpc_id                = module.vpc.vpc_id
  vpc_cidr              = module.vpc.vpc_cidr
  common_tags           = local.common_tags
  allowed_cidr_blocks   = var.allowed_cidr_blocks
  ssh_cidr_blocks       = var.ssh_cidr_blocks
  enable_ebs_encryption = var.enable_ebs_encryption
  key_name              = local.key_name
}

# ==========================================
# Storage Module
# ==========================================
# module "storage" {
#   source = "./modules/storage"

#   project_name           = local.project_name
#   environment            = local.environment
#   common_tags            = local.common_tags
#   data_volume_size       = var.data_volume_size
#   data_volume_type       = var.data_volume_type
#   data_volume_iops       = var.data_volume_iops
#   data_volume_throughput = var.data_volume_throughput
#   enable_ebs_encryption  = var.enable_ebs_encryption
#   availability_zones     = [data.aws_availability_zones.available.names[0]]
#   kms_key_id             = module.security.kms_key_arn
# }

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
# EC2 Module (Updated with proper volume configuration)
# ==========================================
module "ec2" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "~> 6.0"

  name = "${local.project_name}-${local.environment}-instance"

  ami                    = "ami-09c63204a7d809e8f" #data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  key_name               = var.create_key_pair ? var.key_name : null
  subnet_id              = module.vpc.public_subnet_ids[0]
  vpc_security_group_ids = [module.security.kaapana_security_group_id]
  iam_instance_profile   = module.security.instance_profile_name

  associate_public_ip_address = true
  user_data_replace_on_change = false

  # Root volume configuration (100GB) - Using correct parameter names for module
  root_block_device = {
    delete_on_termination = true
    encrypted             = var.enable_ebs_encryption
    iops                  = 3000
    kms_key_id            = var.enable_ebs_encryption ? module.security.kms_key_arn : null
    size                  = var.root_volume_size
    throughput            = 125
    type                  = "gp3"
  }

  # Use volume_tags for root volume tagging
  volume_tags = merge(local.common_tags, {
    Name = "${local.project_name}-${local.environment}-root-volume"
  })

  # User data for instance initialization
  user_data = file("${path.module}/user_data.sh")

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-${local.environment}-instance"
  })
}

# ==========================================
# Secondary EC2 Instance (Optional)
# ==========================================
module "ec2_secondary" {
  count   = var.enable_secondary_instance ? 1 : 0
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "~> 6.0"

  name = "${local.project_name}-${local.environment}-secondary-instance"

  ami                    = "ami-01dfe3fe50212ff27" # data.aws_ami.ubuntu.id
  instance_type          = "r5.4xlarge"            # var.instance_type
  key_name               = var.create_key_pair ? var.key_name : null
  subnet_id              = module.vpc.public_subnet_ids[0]
  vpc_security_group_ids = [module.security.kaapana_security_group_id]
  iam_instance_profile   = module.security.instance_profile_name

  associate_public_ip_address = true
  user_data_replace_on_change = false

  # Root volume configuration (500GB for secondary instance)
  root_block_device = {
    delete_on_termination = true
    encrypted             = var.enable_ebs_encryption
    iops                  = 3000
    kms_key_id            = var.enable_ebs_encryption ? module.security.kms_key_arn : null
    size                  = var.secondary_root_volume_size
    throughput            = 125
    type                  = "gp3"
  }

  # Use volume_tags for root volume tagging
  volume_tags = merge(local.common_tags, {
    Name = "${local.project_name}-${local.environment}-secondary-root-volume"
  })

  # User data for instance initialization
  user_data = file("${path.module}/user_data.sh")

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-${local.environment}-secondary-instance"
    Type = "secondary"
  })
}

# ==========================================
# Elastic IP Module
# ==========================================
module "elastic_ip" {
  source = "./modules/elastic-ip"

  project_name = local.project_name
  environment  = local.environment
  common_tags  = local.common_tags
  instance_id  = module.ec2.id
  vpc          = true
}
