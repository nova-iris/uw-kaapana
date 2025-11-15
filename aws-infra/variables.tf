variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
  default     = "us-east-1"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
  default     = []
}

variable "instance_type" {
  description = "EC2 instance type for Kaapana server"
  type        = string
  default     = "r5.2xlarge"
}

variable "root_volume_size" {
  description = "Size of the root volume in GB"
  type        = number
  default     = 500
}

variable "data_volume_size" {
  description = "Size of the data volume in GB"
  type        = number
  default     = 500
}

variable "data_volume_type" {
  description = "Type of the data volume"
  type        = string
  default     = "gp3"
}

variable "data_volume_iops" {
  description = "IOPS for the data volume (if applicable)"
  type        = number
  default     = 3000
}

variable "data_volume_throughput" {
  description = "Throughput for the data volume in MiB/s (if applicable)"
  type        = number
  default     = 125
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to access Kaapana services"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "ssh_cidr_blocks" {
  description = "CIDR blocks allowed to SSH into instances"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "enable_ebs_encryption" {
  description = "Enable EBS volume encryption"
  type        = bool
  default     = true
}

variable "create_key_pair" {
  description = "Create a new EC2 key pair from local public key"
  type        = bool
  default     = true
}

variable "public_key_path" {
  description = "Path to the SSH public key file"
  type        = string
  default     = "~/.ssh/kaapana-poc.pub"
}

variable "key_name" {
  description = "Name of the EC2 key pair"
  type        = string
  default     = "kaapana-poc-key"
}

variable "allowed_principal_arns" {
  description = "List of AWS principal ARNs allowed to access ECR repository"
  type        = list(string)
  default     = []
}

variable "enable_secondary_instance" {
  description = "Enable creation of secondary EC2 instance"
  type        = bool
  default     = false
}

variable "secondary_root_volume_size" {
  description = "Size of the secondary instance root volume in GB"
  type        = number
  default     = 500
}

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}
