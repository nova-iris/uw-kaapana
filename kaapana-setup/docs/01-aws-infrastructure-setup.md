# 01 - AWS Infrastructure Setup

**Phase:** 1 - Preparation  
**Duration:** 2-4 hours  
**Prerequisite:** AWS account with billing enabled

---

## Overview

This guide covers setting up your AWS infrastructure for Kaapana deployment. You'll create an EC2 instance with proper security groups and storage configuration.

---

## What You'll Create

- 1x EC2 instance (r5.2xlarge or r5.4xlarge)
- Security group with required ports
- 200GB+ gp3 SSD storage
- Elastic IP (optional but recommended)
- SSH key pair for access

---

## Step 1: AWS Account Setup

### Verify AWS Access

```bash
# Install AWS CLI (if not installed)
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Configure AWS CLI
aws configure
# Enter:
# - AWS Access Key ID
# - AWS Secret Access Key
# - Default region (e.g., us-east-1)
# - Default output format: json

# Verify access
aws sts get-caller-identity
```

**Expected Output:**
```json
{
    "UserId": "AIDAXXXXXXXXXX",
    "Account": "123456789012",
    "Arn": "arn:aws:iam::123456789012:user/your-username"
}
```

---

## Step 2: Choose AWS Region

**Recommended Regions:**
- `us-east-1` (N. Virginia) - Lowest cost, most services
- `us-west-2` (Oregon) - Good for West Coast
- `eu-central-1` (Frankfurt) - Good for Europe
- `ap-southeast-1` (Singapore) - Good for Asia
```

---
## Step 4: Create Security Group

**Create security group:**
```bash
# Create security group
aws ec2 create-security-group \
  --group-name kaapana-poc-sg \
  --description "Security group for Kaapana POC" \
  --region $AWS_REGION

# Get security group ID
SG_ID=$(aws ec2 describe-security-groups \
  --group-names kaapana-poc-sg \
  --query 'SecurityGroups[0].GroupId' \
  --output text \
  --region $AWS_REGION)

echo "Security Group ID: $SG_ID"
```

**Add inbound rules:**
```bash
# SSH (your IP only for security)
MY_IP=$(curl -s https://checkip.amazonaws.com)
aws ec2 authorize-security-group-ingress \
  --group-id $SG_ID \
  --protocol tcp \
  --port 22 \
  --cidr $MY_IP/32 \
  --region $AWS_REGION

# HTTP (for redirect to HTTPS)
aws ec2 authorize-security-group-ingress \
  --group-id $SG_ID \
  --protocol tcp \
  --port 80 \
  --cidr 0.0.0.0/0 \
  --region $AWS_REGION

# HTTPS (web interface)
aws ec2 authorize-security-group-ingress \
  --group-id $SG_ID \
  --protocol tcp \
  --port 443 \
  --cidr 0.0.0.0/0 \
  --region $AWS_REGION

# DICOM (for DICOM uploads)
aws ec2 authorize-security-group-ingress \
  --group-id $SG_ID \
  --protocol tcp \
  --port 11112 \
  --cidr 0.0.0.0/0 \
  --region $AWS_REGION

# Verify rules
aws ec2 describe-security-groups \
  --group-ids $SG_ID \
  --query 'SecurityGroups[0].IpPermissions' \
  --region $AWS_REGION
```

---

## Step 5: Launch EC2 Instance

**Get Ubuntu 22.04 AMI ID:**
```bash
# Find Ubuntu 22.04 LTS AMI
AMI_ID=$(aws ec2 describe-images \
  --owners 099720109477 \
  --filters "Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*" \
  --query 'Images | sort_by(@, &CreationDate) | [-1].ImageId' \
  --output text \
  --region $AWS_REGION)

echo "Ubuntu 22.04 AMI: $AMI_ID"
```

**Launch instance (POC configuration):**
```bash
# For POC: r5.2xlarge (8 vCPU, 64GB RAM)
INSTANCE_TYPE="r5.2xlarge"

# Launch instance
INSTANCE_ID=$(aws ec2 run-instances \
  --image-id $AMI_ID \
  --instance-type $INSTANCE_TYPE \
  --key-name kaapana-poc-key \
  --security-group-ids $SG_ID \
  --block-device-mappings '[{
    "DeviceName": "/dev/sda1",
    "Ebs": {
      "VolumeSize": 200,
      "VolumeType": "gp3",
      "DeleteOnTermination": true
    }
  }]' \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=kaapana-poc-server},{Key=Project,Value=Kaapana-POC}]' \
  --region $AWS_REGION \
  --query 'Instances[0].InstanceId' \
  --output text)

echo "Instance ID: $INSTANCE_ID"
```

**For Production-ready POC (recommended):**
```bash
# Better performance: r5.4xlarge (16 vCPU, 128GB RAM)
INSTANCE_TYPE="r5.4xlarge"

INSTANCE_ID=$(aws ec2 run-instances \
  --image-id $AMI_ID \
  --instance-type $INSTANCE_TYPE \
  --key-name kaapana-poc-key \
  --security-group-ids $SG_ID \
  --block-device-mappings '[{
    "DeviceName": "/dev/sda1",
    "Ebs": {
      "VolumeSize": 500,
      "VolumeType": "gp3",
      "DeleteOnTermination": true
    }
  }]' \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=kaapana-poc-server},{Key=Project,Value=Kaapana-POC}]' \
  --region $AWS_REGION \
  --query 'Instances[0].InstanceId' \
  --output text)

echo "Instance ID: $INSTANCE_ID"
```

**Wait for instance to start:**
```bash
# Wait for running state
aws ec2 wait instance-running \
  --instance-ids $INSTANCE_ID \
  --region $AWS_REGION

echo "Instance is running!"

# Get public IP
PUBLIC_IP=$(aws ec2 describe-instances \
  --instance-ids $INSTANCE_ID \
  --query 'Reservations[0].Instances[0].PublicIpAddress' \
  --output text \
  --region $AWS_REGION)

echo "Public IP: $PUBLIC_IP"
```

---

## Step 6: Allocate Elastic IP (Recommended)

**Why?** Elastic IP ensures your instance keeps the same IP even after stop/start.

```bash
# Allocate Elastic IP
ALLOCATION_ID=$(aws ec2 allocate-address \
  --domain vpc \
  --region $AWS_REGION \
  --query 'AllocationId' \
  --output text)

echo "Allocation ID: $ALLOCATION_ID"

# Associate with instance
aws ec2 associate-address \
  --instance-id $INSTANCE_ID \
  --allocation-id $ALLOCATION_ID \
  --region $AWS_REGION

# Get new Elastic IP
ELASTIC_IP=$(aws ec2 describe-addresses \
  --allocation-ids $ALLOCATION_ID \
  --query 'Addresses[0].PublicIp' \
  --output text \
  --region $AWS_REGION)

echo "Elastic IP: $ELASTIC_IP"
echo "Use this IP for all connections!"
```

---

## Step 7: Connect to Instance

**Save connection info:**
```bash
# Save for easy access
cat > ~/kaapana-aws-info.txt << EOF
AWS Region: $AWS_REGION
Instance ID: $INSTANCE_ID
Security Group ID: $SG_ID
Public IP: $ELASTIC_IP
Key File: kaapana-poc-key.pem

SSH Command:
ssh -i kaapana-poc-key.pem ubuntu@$ELASTIC_IP
EOF

cat ~/kaapana-aws-info.txt
```

**Test SSH connection:**
```bash
# Connect to instance
ssh -i kaapana-poc-key.pem ubuntu@$ELASTIC_IP

# Once connected, verify system
uname -a
lsb_release -a
df -h
free -h
lscpu | grep -E "CPU|Thread"

# Exit
exit
```

---

## Step 8: Initial System Configuration

**Connect and update:**
```bash
# Connect to instance
ssh -i kaapana-poc-key.pem ubuntu@$ELASTIC_IP

# Update system
sudo apt update
sudo apt upgrade -y

# Install essential tools
sudo apt install -y nano curl git wget htop net-tools unzip

# Set timezone
sudo timedatectl set-timezone America/New_York  # Adjust to your timezone

# Set hostname
sudo hostnamectl set-hostname kaapana-poc

# Update /etc/hosts
echo "127.0.0.1 kaapana-poc" | sudo tee -a /etc/hosts

# Verify
hostnamectl
```

---

## Step 9: Create Storage Directories

```bash
# Create kaapana user (if not exists)
sudo useradd -m -s /bin/bash kaapana 2>/dev/null || true

# Create directory structure
sudo mkdir -p /home/kaapana/fast_data
sudo mkdir -p /home/kaapana/slow_data

# Set ownership
sudo chown -R kaapana:kaapana /home/kaapana
sudo chmod -R 755 /home/kaapana

# Verify
ls -la /home/kaapana/
df -h
```

---

## Step 10: Verify AWS Setup

**Checklist:**
```bash
# 1. Instance running
aws ec2 describe-instances \
  --instance-ids $INSTANCE_ID \
  --query 'Reservations[0].Instances[0].State.Name' \
  --output text

# 2. Security group configured
aws ec2 describe-security-groups \
  --group-ids $SG_ID \
  --query 'SecurityGroups[0].IpPermissions[*].[FromPort,ToPort,IpProtocol]' \
  --output table

# 3. Elastic IP associated
aws ec2 describe-addresses \
  --allocation-ids $ALLOCATION_ID \
  --query 'Addresses[0].[PublicIp,InstanceId]' \
  --output table

# 4. SSH connectivity
ssh -i kaapana-poc-key.pem ubuntu@$ELASTIC_IP 'echo "SSH OK"'

# 5. Disk space
ssh -i kaapana-poc-key.pem ubuntu@$ELASTIC_IP 'df -h | grep "/$"'
```

**Expected Results:**
- ✅ Instance state: running
- ✅ Security group: 4 inbound rules (22, 80, 443, 11112)
- ✅ Elastic IP: Associated with instance
- ✅ SSH: Connection successful
- ✅ Disk: 200GB+ available

---

## Cost Estimate

**Monthly costs (on-demand pricing):**
- r5.2xlarge: ~$368/month
- 200GB gp3 storage: ~$17/month
- Elastic IP (while associated): $0/month
- **Total: ~$385/month**

**Cost optimization:**
- Stop instance when not in use (saves ~50%)
- Use Savings Plans (saves ~35-40%)
- Reserved Instances for 1 year (saves ~40%)

---

## Troubleshooting

### Cannot connect via SSH
```bash
# Check instance state
aws ec2 describe-instances --instance-ids $INSTANCE_ID \
  --query 'Reservations[0].Instances[0].State.Name'

# Check security group allows your IP
aws ec2 describe-security-groups --group-ids $SG_ID

# Verify key permissions
ls -l kaapana-poc-key.pem  # Should be -r--------
chmod 400 kaapana-poc-key.pem

# Try with verbose
ssh -v -i kaapana-poc-key.pem ubuntu@$ELASTIC_IP
```

### IP changed after stop/start
```bash
# This is why Elastic IP is recommended!
# Get current IP
aws ec2 describe-instances --instance-ids $INSTANCE_ID \
  --query 'Reservations[0].Instances[0].PublicIpAddress' \
  --output text
```

---

## Next Steps

✅ **AWS infrastructure is ready!**

**Next:** [02-build-machine-preparation.md](02-build-machine-preparation.md)

You'll prepare the build machine (can be the same AWS instance or a separate Ubuntu machine) to build Kaapana from source.

---

## Save Your Configuration

```bash
# Save all important info
cat > ~/kaapana-deployment-config.sh << 'EOF'
#!/bin/bash
# Kaapana AWS Configuration

export AWS_REGION="us-east-1"
export INSTANCE_ID="i-xxxxxxxxx"
export SG_ID="sg-xxxxxxxxx"
export ELASTIC_IP="x.x.x.x"
export KEY_FILE="kaapana-poc-key.pem"

alias ssh-kaapana="ssh -i $KEY_FILE ubuntu@$ELASTIC_IP"
alias scp-kaapana="scp -i $KEY_FILE"

echo "Kaapana AWS Configuration Loaded"
echo "Instance: $INSTANCE_ID"
echo "IP: $ELASTIC_IP"
echo "Use: ssh-kaapana to connect"
EOF

# Load configuration
source ~/kaapana-deployment-config.sh
```

---

**Document Status:** ✅ Complete  
**Next Document:** 02-build-machine-preparation.md
