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

echo "User data execution completed at $(date)"