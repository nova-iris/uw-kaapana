variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
}

variable "allowed_principal_arns" {
  description = "List of AWS principal ARNs allowed to access the ECR repository"
  type        = list(string)
  default     = []
}

variable "ec2_role_arn" {
  description = "ARN of the EC2 instance role that needs access to ECR"
  type        = string
  default     = ""
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}