#!/bin/bash
# User data script for Kaapana POC instance
# This is a placeholder script - infrastructure only

# Log file for debugging
exec > /var/log/user-data.log 2>&1
echo "Starting user data execution at $(date)"

# Update system
apt update
apt upgrade -y

# Install basic utilities
apt install -y curl wget git htop net-tools unzip

# Create kaapana user directories
# mkdir -p /home/kaapana/fast_data
# mkdir -p /home/kaapana/slow_data

# # Set proper ownership (kaapana user will be created during Kaapana installation)
# chown -R root:root /home/kaapana
# chmod -R 755 /home/kaapana

# # Create mounts file for reference (actual mounting will be done during Kaapana setup)
# cat > /etc/systemd/system/kaapana-data-volumes.service << 'EOF'
# [Unit]
# Description=Mount Kaapana data volumes
# After=local-fs.target

# [Service]
# Type=oneshot
# RemainAfterExit=yes
# ExecStart=/bin/mount /dev/sdh /home/kaapana/fast_data
# ExecStart=/bin/chown -R kaapana:kaapana /home/kaapana
# TimeoutStartSec=0

# [Install]
# WantedBy=multi-user.target
# EOF

# # Enable the service (but don't start until device is ready)
# systemctl enable kaapana-data-volumes.service

echo "User data execution completed at $(date)"