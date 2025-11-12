variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
}

variable "instance_id" {
  description = "ID of the EC2 instance to associate with Elastic IP"
  type        = string
}

variable "vpc" {
  description = "Whether to create VPC EIP"
  type        = bool
  default     = true
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}