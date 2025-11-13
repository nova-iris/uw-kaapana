# ==========================================
# ECR Module for Kaapana POC
# ==========================================

# ==========================================
# ECR Repository for Kaapana Docker Images
# ==========================================
resource "aws_ecr_repository" "kaapana" {
  name                 = "${var.project_name}-${var.environment}"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = merge(var.common_tags, {
    Name        = "${var.project_name}-${var.environment}-ecr"
    Description = "ECR repository for Kaapana Docker images"
  })
}

# ==========================================
# ECR Repository Policy
# ==========================================
resource "aws_ecr_repository_policy" "kaapana" {
  repository = aws_ecr_repository.kaapana.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowPushPull"
        Effect = "Allow"
        Principal = {
          AWS = concat(var.allowed_principal_arns, var.ec2_role_arn != "" ? [var.ec2_role_arn] : [])
        }
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:DescribeRepositories",
          "ecr:GetRepositoryPolicy",
          "ecr:ListImages",
          "ecr:DeleteRepository",
          "ecr:BatchDeleteImage",
          "ecr:SetRepositoryPolicy",
          "ecr:DescribeImages",
          "ecr:DescribeImageScanFindings"
        ]
      }
    ]
  })
}

# ==========================================
# ECR Lifecycle Policy
# ==========================================
resource "aws_ecr_lifecycle_policy" "kaapana" {
  repository = aws_ecr_repository.kaapana.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 images for each tag"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["0.3.", "latest"]
          countType     = "imageCountMoreThan"
          countNumber   = 10
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "Keep untagged images for 7 days"
        selection = {
          tagStatus = "untagged"
          countType = "sinceImagePushed"
          countUnit = "days"
          countNumber = 7
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}