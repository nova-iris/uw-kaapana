# ==========================================
# Elastic IP Module for Kaapana POC
# ==========================================

# ==========================================
# Elastic IP Allocation
# ==========================================
resource "aws_eip" "kaapana" {
  domain = var.vpc ? "vpc" : "standard"

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-eip"
  })

  depends_on = [var.instance_id]
}

# ==========================================
# Elastic IP Association
# ==========================================
resource "aws_eip_association" "kaapana" {
  instance_id   = var.instance_id
  allocation_id = aws_eip.kaapana.id
}