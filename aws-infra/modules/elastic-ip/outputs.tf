output "elastic_ip" {
  description = "The Elastic IP address"
  value       = aws_eip.kaapana.public_ip
}

output "allocation_id" {
  description = "The allocation ID of the Elastic IP"
  value       = aws_eip.kaapana.id
}

output "association_id" {
  description = "The association ID of the Elastic IP"
  value       = aws_eip_association.kaapana.id
}

output "domain" {
  description = "The domain of the Elastic IP (vpc or standard)"
  value       = aws_eip.kaapana.domain
}


output "private_ip" {
  description = "The private IP address associated with the Elastic IP"
  value       = aws_eip.kaapana.private_ip
}