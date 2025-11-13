output "ecr_repository_url" {
  description = "URL of the ECR repository"
  value       = aws_ecr_repository.kaapana.repository_url
}

output "ecr_repository_name" {
  description = "Name of the ECR repository"
  value       = aws_ecr_repository.kaapana.name
}

output "ecr_repository_arn" {
  description = "ARN of the ECR repository"
  value       = aws_ecr_repository.kaapana.arn
}

output "ecr_registry_id" {
  description = "Registry ID of the ECR repository"
  value       = aws_ecr_repository.kaapana.registry_id
}