output "kaapana_security_group_id" {
  description = "ID of the Kaapana security group"
  value       = module.kaapana_security_group.security_group_id
}

output "kaapana_security_group_arn" {
  description = "ARN of the Kaapana security group"
  value       = module.kaapana_security_group.security_group_arn
}

output "instance_profile_name" {
  description = "Name of the IAM instance profile"
  value       = aws_iam_instance_profile.ec2.name
}

output "instance_profile_arn" {
  description = "ARN of the IAM instance profile"
  value       = aws_iam_instance_profile.ec2.arn
}

output "iam_role_name" {
  description = "Name of the IAM role"
  value       = aws_iam_role.ec2.name
}

output "iam_role_arn" {
  description = "ARN of the IAM role"
  value       = aws_iam_role.ec2.arn
}

output "kms_key_id" {
  description = "ID of the KMS key for EBS encryption"
  value       = var.enable_ebs_encryption ? aws_kms_key.ebs[0].key_id : null
}

output "kms_key_arn" {
  description = "ARN of the KMS key for EBS encryption"
  value       = var.enable_ebs_encryption ? aws_kms_key.ebs[0].arn : null
}

output "kms_key_alias" {
  description = "Alias of the KMS key for EBS encryption"
  value       = var.enable_ebs_encryption ? aws_kms_alias.ebs[0].name : null
}