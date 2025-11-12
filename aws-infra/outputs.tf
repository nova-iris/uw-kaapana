# VPC Outputs
output "vpc_cidr" {
  description = "CIDR block of the created VPC"
  value       = module.vpc.vpc_cidr
}

# EC2 Outputs
output "instance_id" {
  description = "ID of the created EC2 instance"
  value       = module.ec2.instance_id
}

output "instance_public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = module.ec2.instance_public_ip
}

# Elastic IP Outputs
output "elastic_ip" {
  description = "Elastic IP address"
  value       = module.elastic_ip.elastic_ip
}

# Connection Information
output "connection_info" {
  description = "Connection information for the instance"
  value = {
    ssh_host = module.elastic_ip.elastic_ip
    ssh_user = "ubuntu"
    ssh_key  = "${var.key_name}.pem"
    url      = "https://${module.elastic_ip.elastic_ip}"
  }
}
