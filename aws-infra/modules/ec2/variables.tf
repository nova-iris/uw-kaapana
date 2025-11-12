variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
}

variable "ami_id" {
  description = "AMI ID for the EC2 instance"
  type        = string
}

variable "key_name" {
  description = "Name of the EC2 key pair"
  type        = string
  default     = null
}

variable "public_key_path" {
  description = "Path to the SSH public key file"
  type        = string
  default     = null
}

variable "subnet_id" {
  description = "ID of the subnet where the instance will be launched"
  type        = string
}

variable "security_group_ids" {
  description = "List of security group IDs"
  type        = list(string)
}

variable "iam_instance_profile" {
  description = "Name of the IAM instance profile"
  type        = string
}

variable "root_volume_size" {
  description = "Size of the root volume in GB"
  type        = number
}

variable "data_volume_size" {
  description = "Size of the data volume in GB"
  type        = number
}

variable "data_volume_type" {
  description = "Type of the data volume"
  type        = string
}

variable "data_volume_ids" {
  description = "List of existing data volume IDs to attach"
  type        = list(string)
  default     = []
}

variable "enable_ebs_encryption" {
  description = "Enable EBS volume encryption"
  type        = bool
}

variable "kms_key_id" {
  description = "KMS key ID for EBS encryption"
  type        = string
  default     = null
}

variable "user_data" {
  description = "Path to user data script"
  type        = string
}

variable "user_data_vars" {
  description = "Variables to pass to user data template"
  type        = map(string)
  default     = {}
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}