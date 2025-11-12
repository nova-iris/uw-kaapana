# 04 - Artifact Transfer to AWS Deployment Server

**Phase:** 2 - Build  
**Duration:** 30-60 minutes (depends on network speed)  
**Prerequisite:** 03-kaapana-build-process.md completed on separate build machine

---

## Overview

**⚠️ Only follow this guide if you built on a separate machine.**

If you built on your AWS deployment server, skip to [05-server-installation.md](05-server-installation.md).

This guide covers transferring:
- Docker images (~30-40GB compressed)
- Helm charts (~500MB-1GB)
- Deployment scripts
- Configuration files

---

## Transfer Methods

Choose based on your network and setup:

| Method | Speed | Complexity | Best For |
|--------|-------|------------|----------|
| **SCP** | Fast on LAN | Low | Direct network access |
| **AWS S3** | Medium | Medium | Cloud-based transfer |
| **External Drive** | N/A | Low | No network, physical access |

---

## Method 1: SCP Transfer (Recommended)

**Prerequisites:**
- SSH access from build machine to AWS server
- AWS server Elastic IP address
- SSH key for AWS server

### On Build Machine

#### Step 1: Create Transfer Archives
```bash
cd ~/kaapana-build/kaapana

# Export Docker images
echo "Exporting Docker images (this takes time)..."
docker save $(docker images --format "{{.Repository}}:{{.Tag}}" | grep "local-only") \
  -o ~/kaapana-images.tar

# Compress images (saves transfer time)
echo "Compressing images (this takes time)..."
gzip ~/kaapana-images.tar

# Archive Helm charts and scripts
echo "Archiving Helm charts and scripts..."
tar -czf ~/kaapana-charts.tar.gz \
  build-scripts/builds/ \
  server-installation/ \
  platforms/

# Check archive sizes
ls -lh ~ | grep kaapana
```

**Expected output:**
```
-rw-rw-r-- 1 ubuntu ubuntu 35G  kaapana-images.tar.gz
-rw-rw-r-- 1 ubuntu ubuntu 800M kaapana-charts.tar.gz
```

#### Step 2: Transfer to AWS Server

**Set variables:**
```bash
# Replace with your values
export AWS_IP="YOUR_ELASTIC_IP"
export KEY_FILE="path/to/kaapana-poc-key.pem"
```

**Transfer images:**
```bash
# Transfer Docker images (large file, takes time)
scp -i $KEY_FILE \
  -o StrictHostKeyChecking=no \
  -o ServerAliveInterval=60 \
  ~/kaapana-images.tar.gz \
  ubuntu@$AWS_IP:~/

# Show transfer progress (run in another terminal)
# watch -n 5 'ls -lh ~/kaapana-images.tar.gz'
```

**Transfer charts:**
```bash
# Transfer Helm charts and scripts
scp -i $KEY_FILE \
  ~/kaapana-charts.tar.gz \
  ubuntu@$AWS_IP:~/
```

**Verify transfer:**
```bash
# Check files on AWS server
ssh -i $KEY_FILE ubuntu@$AWS_IP "ls -lh ~/ | grep kaapana"
```

### On AWS Server

#### Step 3: Extract Archives
```bash
# SSH to AWS server
ssh -i kaapana-poc-key.pem ubuntu@$ELASTIC_IP

# Check disk space (need 100GB+ free)
df -h /

# Create working directory
mkdir -p ~/kaapana-deploy
cd ~/kaapana-deploy

# Extract Helm charts and scripts
echo "Extracting charts and scripts..."
tar -xzf ~/kaapana-charts.tar.gz

# Load Docker images (takes time)
echo "Loading Docker images (this takes time)..."
gunzip -c ~/kaapana-images.tar.gz | docker load

# Verify images loaded
docker images | wc -l
# Should show: 90+ images
```

#### Step 4: Verify Transfer
```bash
# Verify Docker images
docker images | grep "local-only" | head -20

# Verify Helm charts
ls -la ~/kaapana-deploy/build-scripts/builds/*.tgz

# Verify deployment scripts
ls -la ~/kaapana-deploy/server-installation/server_installation.sh
ls -la ~/kaapana-deploy/platforms/deploy_platform.sh

# Check directory structure
tree -L 2 ~/kaapana-deploy/
```

**Expected structure:**
```
~/kaapana-deploy/
├── build-scripts/
│   └── builds/           # Helm charts
├── server-installation/
│   ├── server_installation.sh
│   └── ... (scripts)
└── platforms/
    ├── deploy_platform.sh
    ├── kaapana-platform-chart/
    └── kaapana-admin-chart/
```

#### Step 5: Cleanup (Optional)
```bash
# Remove compressed archives to free space
rm ~/kaapana-images.tar.gz
rm ~/kaapana-charts.tar.gz

# Check disk space
df -h /
```

---

## Method 2: AWS S3 Transfer

**Prerequisites:**
- AWS CLI installed on both machines
- S3 bucket with appropriate permissions
- IAM credentials configured

### On Build Machine

#### Step 1: Create Archives (same as Method 1)
```bash
cd ~/kaapana-build/kaapana

docker save $(docker images --format "{{.Repository}}:{{.Tag}}" | grep "local-only") \
  -o ~/kaapana-images.tar
gzip ~/kaapana-images.tar

tar -czf ~/kaapana-charts.tar.gz \
  build-scripts/builds/ \
  server-installation/ \
  platforms/
```

#### Step 2: Upload to S3
```bash
# Set S3 bucket name
export S3_BUCKET="your-kaapana-transfer-bucket"

# Create bucket (if not exists)
aws s3 mb s3://$S3_BUCKET --region us-east-1

# Upload images (parallel multipart for speed)
aws s3 cp ~/kaapana-images.tar.gz s3://$S3_BUCKET/ \
  --storage-class STANDARD \
  --no-progress

# Upload charts
aws s3 cp ~/kaapana-charts.tar.gz s3://$S3_BUCKET/

# Verify upload
aws s3 ls s3://$S3_BUCKET/
```

### On AWS Server

#### Step 3: Download from S3
```bash
# Set S3 bucket name
export S3_BUCKET="your-kaapana-transfer-bucket"

# Download images
aws s3 cp s3://$S3_BUCKET/kaapana-images.tar.gz ~/

# Download charts
aws s3 cp s3://$S3_BUCKET/kaapana-charts.tar.gz ~/

# Verify downloads
ls -lh ~/ | grep kaapana
```

#### Step 4: Extract (same as Method 1 Step 3)
```bash
mkdir -p ~/kaapana-deploy
cd ~/kaapana-deploy
tar -xzf ~/kaapana-charts.tar.gz
gunzip -c ~/kaapana-images.tar.gz | docker load
```

#### Step 5: Cleanup S3 (Optional)
```bash
# Delete from S3 to avoid charges
aws s3 rm s3://$S3_BUCKET/kaapana-images.tar.gz
aws s3 rm s3://$S3_BUCKET/kaapana-charts.tar.gz

# Delete bucket (if no longer needed)
aws s3 rb s3://$S3_BUCKET
```

---

## Method 3: External Drive Transfer

**Prerequisites:**
- External USB drive with 50GB+ space
- Physical access to both machines

### On Build Machine

#### Step 1: Mount External Drive
```bash
# List drives
lsblk

# Mount drive (adjust device name)
sudo mkdir -p /mnt/usb
sudo mount /dev/sdb1 /mnt/usb

# Verify mount
df -h | grep usb
```

#### Step 2: Copy Archives to Drive
```bash
# Create archives (same as Method 1)
cd ~/kaapana-build/kaapana

docker save $(docker images --format "{{.Repository}}:{{.Tag}}" | grep "local-only") \
  -o ~/kaapana-images.tar
gzip ~/kaapana-images.tar

tar -czf ~/kaapana-charts.tar.gz \
  build-scripts/builds/ \
  server-installation/ \
  platforms/

# Copy to drive
sudo cp ~/kaapana-images.tar.gz /mnt/usb/
sudo cp ~/kaapana-charts.tar.gz /mnt/usb/

# Verify copy
ls -lh /mnt/usb/

# Unmount drive
sudo umount /mnt/usb
```

### On AWS Server

#### Step 3: Mount and Copy from Drive
```bash
# Mount drive
sudo mkdir -p /mnt/usb
sudo mount /dev/sdb1 /mnt/usb

# Copy from drive
cp /mnt/usb/kaapana-images.tar.gz ~/
cp /mnt/usb/kaapana-charts.tar.gz ~/

# Unmount drive
sudo umount /mnt/usb

# Extract (same as Method 1 Step 3)
mkdir -p ~/kaapana-deploy
cd ~/kaapana-deploy
tar -xzf ~/kaapana-charts.tar.gz
gunzip -c ~/kaapana-images.tar.gz | docker load
```

---

## Verification

### Verify Complete Transfer

**Run this verification on AWS server:**
```bash
cat > ~/verify-transfer.sh << 'EOF'
#!/bin/bash
echo "=== Kaapana Transfer Verification ==="
echo ""

# Docker images
IMAGE_COUNT=$(docker images | grep "local-only" | wc -l)
echo "Docker Images: $IMAGE_COUNT"
if [ "$IMAGE_COUNT" -ge 90 ]; then
  echo "  ✅ All images transferred"
else
  echo "  ❌ Missing images (expected 90+)"
fi
echo ""

# Helm charts
CHART_COUNT=$(find ~/kaapana-deploy/build-scripts/builds/ -name "*.tgz" 2>/dev/null | wc -l)
echo "Helm Charts: $CHART_COUNT"
if [ "$CHART_COUNT" -ge 2 ]; then
  echo "  ✅ Charts transferred"
else
  echo "  ❌ Charts missing"
fi
echo ""

# Deployment scripts
if [ -f ~/kaapana-deploy/server-installation/server_installation.sh ]; then
  echo "✅ server_installation.sh found"
else
  echo "❌ server_installation.sh missing"
fi

if [ -f ~/kaapana-deploy/platforms/deploy_platform.sh ]; then
  echo "✅ deploy_platform.sh found"
else
  echo "❌ deploy_platform.sh missing"
fi
echo ""

# Disk space
DISK_AVAIL=$(df -h / | tail -1 | awk '{print $4}')
echo "Disk Space Available: $DISK_AVAIL"
echo ""

echo "=== Verification Complete ==="
EOF

chmod +x ~/verify-transfer.sh
~/verify-transfer.sh
```

**Expected output:**
```
=== Kaapana Transfer Verification ===

Docker Images: 92
  ✅ All images transferred

Helm Charts: 4
  ✅ Charts transferred

✅ server_installation.sh found
✅ deploy_platform.sh found

Disk Space Available: 150G

=== Verification Complete ===
```

---

## Troubleshooting

### SCP transfer fails: "Connection timeout"
```bash
# Check SSH connectivity
ssh -i $KEY_FILE ubuntu@$AWS_IP "echo 'Connection OK'"

# Try with verbose output
scp -v -i $KEY_FILE ~/kaapana-images.tar.gz ubuntu@$AWS_IP:~/

# Check AWS security group allows SSH (port 22)
# AWS Console → EC2 → Security Groups → Inbound Rules
```

### Transfer interrupted
```bash
# Resume using rsync instead of scp
rsync -avz --progress --partial \
  -e "ssh -i $KEY_FILE" \
  ~/kaapana-images.tar.gz \
  ubuntu@$AWS_IP:~/
```

### Docker load fails
```bash
# Check file integrity
gunzip -t ~/kaapana-images.tar.gz
# Should output: OK

# If corrupted, re-transfer
# Try loading without decompression first:
docker load -i ~/kaapana-images.tar.gz
```

### Out of disk space on AWS server
```bash
# Check space
df -h

# Expand AWS EBS volume:
# 1. AWS Console → EC2 → Volumes → Modify Volume (increase size)
# 2. On server:
sudo growpart /dev/nvme0n1 1
sudo resize2fs /dev/nvme0n1p1
df -h  # Verify
```

---

## Transfer Complete Checklist

Before proceeding to deployment, verify on AWS server:

- [x] 90+ Docker images loaded (`docker images | wc -l`)
- [x] Images tagged with `local-only/*`
- [x] Helm charts in `~/kaapana-deploy/build-scripts/builds/`
- [x] `server_installation.sh` exists
- [x] `deploy_platform.sh` exists
- [x] Directory structure matches expected layout
- [x] At least 100GB disk space free
- [x] Docker working without sudo

---

## Next Steps

✅ **Transfer complete!**

**Next:** [05-server-installation.md](05-server-installation.md)

You'll install MicroK8s and prepare the Kubernetes environment for Kaapana deployment.

---

## Quick Reference

**Verify transfer:**
```bash
~/verify-transfer.sh
```

**Check images:**
```bash
docker images | grep "local-only" | wc -l
```

**Check charts:**
```bash
ls -la ~/kaapana-deploy/build-scripts/builds/
```

**Check disk space:**
```bash
df -h /
```

---

**Document Status:** ✅ Complete  
**Next Document:** 05-server-installation.md
