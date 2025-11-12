# ==========================================
# EC2 Module Wrapper for Kaapana POC
# ==========================================
# This module wraps terraform-aws-modules/ec2-instance to provide
# Kaapana-specific configuration and interface

# ==========================================
# EC2 Instance using terraform-aws-modules/ec2-instance
# ==========================================
module "ec2_instance" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "~> 6.0"

  name = "${var.project_name}-${var.environment}-instance"

  ami                    = var.ami_id
  instance_type          = var.instance_type
  key_name               = var.key_name
  subnet_id              = var.subnet_id
  vpc_security_group_ids = var.security_group_ids
  iam_instance_profile   = var.iam_instance_profile

  associate_public_ip_address = true
  user_data_replace_on_change = false

  
  
  # User data for instance initialization
  user_data = var.user_data

  tags = var.common_tags
}

# ==========================================
# Volume Attachments for external data volumes (if provided)
# ==========================================
resource "aws_volume_attachment" "external_data" {
  count       = length(var.data_volume_ids)
  device_name = "/dev/sdi"  # Use /dev/sdi to avoid conflicts with ebs_block_device
  instance_id = module.ec2_instance.id
  volume_id   = var.data_volume_ids[count.index]
}