variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
}

variable "data_volume_size" {
  description = "Size of the data volume in GB"
  type        = number
}

variable "data_volume_type" {
  description = "Type of the data volume (gp2, gp3, io1, etc.)"
  type        = string
}

variable "data_volume_iops" {
  description = "IOPS for the data volume (if applicable)"
  type        = number
}

variable "data_volume_throughput" {
  description = "Throughput for the data volume in MiB/s (if applicable)"
  type        = number
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
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

variable "enable_backup" {
  description = "Enable initial backup snapshot"
  type        = bool
  default     = false
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}