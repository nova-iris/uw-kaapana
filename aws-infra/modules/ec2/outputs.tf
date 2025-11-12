output "instance_id" {
  description = "ID of the EC2 instance"
  value       = module.ec2_instance.id
}

output "instance_arn" {
  description = "ARN of the EC2 instance"
  value       = module.ec2_instance.arn
}

output "instance_public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = module.ec2_instance.public_ip
}

output "instance_private_ip" {
  description = "Private IP address of the EC2 instance"
  value       = module.ec2_instance.private_ip
}

output "instance_public_dns" {
  description = "Public DNS hostname of the EC2 instance"
  value       = module.ec2_instance.public_dns
}

output "instance_private_dns" {
  description = "Private DNS hostname of the EC2 instance"
  value       = module.ec2_instance.private_dns
}

output "instance_availability_zone" {
  description = "Availability zone of the EC2 instance"
  value       = module.ec2_instance.availability_zone
}

output "instance_subnet_id" {
  description = "Subnet ID of the EC2 instance"
  value       = var.subnet_id
}

output "instance_ami" {
  description = "AMI ID used for the EC2 instance"
  value       = var.ami_id
}

output "instance_type" {
  description = "Instance type of the EC2 instance"
  value       = var.instance_type
}

output "attached_volume_ids" {
  description = "IDs of external volumes attached to the instance"
  value       = aws_volume_attachment.external_data[*].volume_id
}