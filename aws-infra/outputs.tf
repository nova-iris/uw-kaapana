# VPC Outputs
output "vpc_cidr" {
  description = "CIDR block of the created VPC"
  value       = module.vpc.vpc_cidr
}

# EC2 Outputs
output "instance_id" {
  description = "ID of the created EC2 instance"
  value       = module.ec2.id
}

output "instance_public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = module.ec2.public_ip
}

# Secondary EC2 Outputs
output "secondary_instance_id" {
  description = "ID of the secondary EC2 instance (if created)"
  value       = var.enable_secondary_instance ? module.ec2_secondary[0].id : null
}

output "secondary_instance_public_ip" {
  description = "Public IP address of the secondary EC2 instance (if created)"
  value       = var.enable_secondary_instance ? module.ec2_secondary[0].public_ip : null
}

output "secondary_instance_enabled" {
  description = "Whether the secondary instance is enabled"
  value       = var.enable_secondary_instance
}

# Elastic IP Outputs
output "elastic_ip" {
  description = "Elastic IP address"
  value       = module.elastic_ip.elastic_ip
}

# Connection Information
output "connection_info" {
  description = "Connection information for the primary instance"
  value = {
    ssh_host = module.elastic_ip.elastic_ip
    ssh_user = "ubuntu"
    ssh_key  = "${var.key_name}.pem"
    url      = "https://${module.elastic_ip.elastic_ip}"
  }
}

output "secondary_connection_info" {
  description = "Connection information for the secondary instance (if created)"
  value = var.enable_secondary_instance ? {
    ssh_host = module.ec2_secondary[0].public_ip
    ssh_user = "ubuntu"
    ssh_key  = "${var.key_name}.pem"
    url      = "http://${module.ec2_secondary[0].public_ip}"
  } : null
}
