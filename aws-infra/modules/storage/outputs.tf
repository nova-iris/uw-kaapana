output "data_volume_ids" {
  description = "IDs of the created data volumes"
  value       = [aws_ebs_volume.kaapana_data.id]
}

output "data_volume_size" {
  description = "Size of the data volumes"
  value       = aws_ebs_volume.kaapana_data.size
}

output "data_volume_type" {
  description = "Type of the data volumes"
  value       = aws_ebs_volume.kaapana_data.type
}

output "data_volume_availability_zone" {
  description = "Availability zone of the data volumes"
  value       = aws_ebs_volume.kaapana_data.availability_zone
}

output "data_volume_encrypted" {
  description = "Whether the data volumes are encrypted"
  value       = aws_ebs_volume.kaapana_data.encrypted
}

output "data_snapshot_ids" {
  description = "IDs of the created data snapshots"
  value       = var.enable_backup ? [aws_ebs_snapshot.kaapana_data_backup[0].id] : []
}