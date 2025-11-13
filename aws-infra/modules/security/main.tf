# ==========================================
# Security Module Wrapper for Kaapana POC
# ==========================================
# This module wraps terraform-aws-modules/security-group to provide
# Kaapana-specific configuration and interface

# ==========================================
# KMS Key for EBS Encryption
# ==========================================
resource "aws_kms_key" "ebs" {
  count = var.enable_ebs_encryption ? 1 : 0

  description             = "${var.project_name} EBS encryption key"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EnableRootAccount"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "EnableIAMUserPermissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.project_name}-${var.environment}-ec2-role"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-ebs-key"
  })
}

resource "aws_kms_alias" "ebs" {
  count = var.enable_ebs_encryption ? 1 : 0

  name          = "alias/${var.project_name}-${var.environment}-ebs"
  target_key_id = aws_kms_key.ebs[0].key_id
}

# ==========================================
# IAM Role and Instance Profile
# ==========================================
resource "aws_iam_role" "ec2" {
  name = "${var.project_name}-${var.environment}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = var.common_tags
}

resource "aws_iam_instance_profile" "ec2" {
  name = "${var.project_name}-${var.environment}-ec2-profile"
  role = aws_iam_role.ec2.name
}

# IAM policy for EBS encryption
resource "aws_iam_role_policy" "ebs_encryption" {
  count = var.enable_ebs_encryption ? 1 : 0

  name = "${var.project_name}-${var.environment}-ebs-encryption"
  role = aws_iam_role.ec2.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = [aws_kms_key.ebs[0].arn]
      }
    ]
  })
}

# IAM policy for CloudWatch logs
resource "aws_iam_role_policy" "cloudwatch" {
  name = "${var.project_name}-${var.environment}-cloudwatch"
  role = aws_iam_role.ec2.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams",
          "logs:DescribeLogGroups"
        ]
        Resource = "*"
      }
    ]
  })
}

# IAM policy for ECR access
resource "aws_iam_role_policy" "ecr" {
  name = "${var.project_name}-${var.environment}-ecr"
  role = aws_iam_role.ec2.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:GetRepositoryPolicy",
          "ecr:DescribeRepositories",
          "ecr:ListImages",
          "ecr:DescribeImages",
          "ecr:BatchGetImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:PutImage"
        ]
        Resource = "*"
      }
    ]
  })
}

# ==========================================
# Security Group using terraform-aws-modules/security-group
# ==========================================
module "kaapana_security_group" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 5.0"

  name        = "${var.project_name}-${var.environment}-sg"
  description = "Security group for Kaapana POC instances"
  vpc_id      = var.vpc_id

  # Custom ingress rules for specific ports
  ingress_with_cidr_blocks = [
    {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      description = "SSH access"
      cidr_blocks = join(",", var.ssh_cidr_blocks)
    },
    {
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      description = "HTTP access"
      cidr_blocks = join(",", var.allowed_cidr_blocks)
    },
    {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      description = "HTTPS access"
      cidr_blocks = join(",", var.allowed_cidr_blocks)
    },
    {
      from_port   = 11112
      to_port     = 11112
      protocol    = "tcp"
      description = "DICOM access"
      cidr_blocks = join(",", var.allowed_cidr_blocks)
    },
    {
      from_port   = 5000
      to_port     = 5020
      protocol    = "tcp"
      description = "Kaapana service ports"
      cidr_blocks = join(",", var.allowed_cidr_blocks)
    }
  ]

  # Egress rules - allow all outbound
  egress_rules = ["all-all"]

  tags = var.common_tags
}

# Data sources
data "aws_caller_identity" "current" {}