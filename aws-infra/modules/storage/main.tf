# ==========================================
# Storage Module for Kaapana POC
# ==========================================

# ==========================================
# EBS Data Volume for Kaapana
# ==========================================
resource "aws_ebs_volume" "kaapana_data" {
  availability_zone = var.availability_zones[0]
  size              = var.data_volume_size
  type              = var.data_volume_type
  iops              = var.data_volume_type == "gp3" ? var.data_volume_iops : null
  throughput        = var.data_volume_type == "gp3" ? var.data_volume_throughput : null
  encrypted         = var.enable_ebs_encryption
  kms_key_id        = var.enable_ebs_encryption ? var.kms_key_id : null

  tags = merge(var.common_tags, {
    Name        = "${var.project_name}-${var.environment}-data-volume"
    Description = "Data volume for Kaapana storage"
  })
}

# ==========================================
# Volume snapshot for backup protection (optional)
# ==========================================
resource "aws_ebs_snapshot" "kaapana_data_backup" {
  count = var.enable_backup ? 1 : 0

  volume_id   = aws_ebs_volume.kaapana_data.id
  description = "Initial backup snapshot for ${var.project_name} ${var.environment} data volume"

  tags = merge(var.common_tags, {
    Name        = "${var.project_name}-${var.environment}-data-snapshot"
    Description = "Backup snapshot for Kaapana data volume"
  })

  lifecycle {
    ignore_changes = [volume_id]
  }
}