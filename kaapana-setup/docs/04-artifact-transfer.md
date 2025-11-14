# 04 - Artifact Transfer to AWS Deployment Server

**Phase:** 2 - Build
**Duration:** 5-10 minutes
**Prerequisite:** 03-kaapana-build-process.md completed on separate build machine

---

## Overview

**⚠️ Only follow this guide if you built on a separate machine.**

If you built on your AWS deployment server, skip to [05-server-installation.md](05-server-installation.md).

**IMPORTANT:** This guide assumes you're using GitLab registry (or any external container registry). **Docker images are NOT transferred** since they're already pushed to the registry during build. Only deployment scripts and Helm charts need to be transferred.

This guide covers transferring:
- `deploy_platform.sh` script (~50KB)
- Helm chart package (~50-100MB)
- Configuration files
- Build metadata

---

## Transfer Methods

Choose based on your network and setup:

| Method | Speed | Complexity | Best For |
|--------|-------|------------|----------|
| **SCP** | Fast | Low | Direct network access |
| **AWS S3** | Medium | Medium | Cloud-based transfer |
| **Git/GitLab** | Fast | Low | Version control integration |

---

## Method 1: SCP Transfer (Recommended)

**Prerequisites:**
- SSH access from build machine to AWS server
- AWS server Elastic IP address
- SSH key for AWS server
- Docker images already pushed to GitLab registry

### On Build Machine

#### Step 1: Locate Build Artifacts
```bash
cd ~/kaapana

# Verify build artifacts exist
ls -la build/kaapana-admin-chart/

# Should show:
# - deploy_platform.sh (main deployment script)
# - kaapana-admin-chart/ (Helm chart directory)
# - kaapana-extension-collection/ (extensions)
# - tree-kaapana-admin-chart.txt (build manifest)
```

#### Step 2: Transfer Deployment Artifacts

**Set variables:**
```bash
# Replace with your values
export AWS_IP="YOUR_ELASTIC_IP"
export KEY_FILE="path/to/kaapana-poc-key.pem"
```

**Transfer deployment directory:**
```bash
# Create deployment directory on AWS server
ssh -i $KEY_FILE ubuntu@$AWS_IP "mkdir -p ~/kaapana"

# Transfer entire kaapana-admin-chart build output
scp -i $KEY_FILE \
  -o StrictHostKeyChecking=no \
  -r ~/kaapana/build/kaapana-admin-chart/ \
  ubuntu@$AWS_IP:~/kaapana/

# Transfer should complete in <5 minutes (no large Docker images)
```

**Verify transfer:**
```bash
# Check files on AWS server
ssh -i $KEY_FILE ubuntu@$AWS_IP "ls -la ~/kaapana/kaapana-admin-chart/"
```

### On AWS Server

#### Step 3: Verify Deployment Artifacts
```bash
# SSH to AWS server
ssh -i kaapana-poc-key.pem ubuntu@$ELASTIC_IP

# Check deployment artifacts
ls -la ~/kaapana/kaapana-admin-chart/

# Should show:
# - deploy_platform.sh (executable deployment script)
# - kaapana-admin-chart/ (Helm chart package)
# - tree-kaapana-admin-chart.txt (build manifest)
# - kaapana-extension-collection/ (optional extensions)

# Verify script is executable
chmod +x ~/kaapana/kaapana-admin-chart/deploy_platform.sh

# Check Helm chart package
ls -la ~/kaapana/kaapana-admin-chart/kaapana-admin-chart/*.tgz
```

#### Step 4: Verify GitLab Registry Access
```bash
# Test GitLab registry connectivity (replace with your registry)
docker pull registry.gitlab.com/yourusername/yourproject/base-python-cpu:latest

# If pull succeeds, registry access is working
# If it fails, you may need to login:
echo "YOUR_GITLAB_TOKEN" | docker login registry.gitlab.com --username YOUR_USERNAME --password-stdin
```

---

## Method 2: Git/GitLab Transfer (Recommended)

**Prerequisites:**
- GitLab repository: https://gitlab.com/trongtruong2509/kaapana
- Build artifacts committed to GitLab
- AWS server with Git access
- GitLab credentials (see gitlab-registry.md)

### On Build Machine

#### Step 1: Commit Build Artifacts to GitLab
```bash
# Navigate to your GitLab repository
cd /path/to/gitlab/kaapana

# Add deployment artifacts
git add deploy_platform.sh
git add kaapana-platform-chart-0.5.2.tgz
git add kaapana-extension-collection/
git add tree-kaapana-admin-chart.txt

# Commit deployment artifacts
git commit -m "Add Kaapana deployment artifacts
- deploy_platform.sh script (configured for GitLab registry)
- kaapana-platform-chart-0.5.2.tgz (main Helm chart)
- Extension charts and workflows
- Build manifest and configuration"

# Push to GitLab
git push origin main
```

### On AWS Server

#### Step 2: Clone and Deploy from GitLab
```bash
# Clone GitLab repository
cd ~
git clone https://gitlab.com/trongtruong2509/kaapana.git

# Navigate to deployment directory
cd ~/kaapana

# Verify deployment artifacts
ls -la deploy_platform.sh
ls -la kaapana-platform-chart-0.5.2.tgz
ls -la kaapana-extension-collection/charts/*.tgz

# The deploy_platform.sh is already configured with GitLab registry:
# CONTAINER_REGISTRY_URL="registry.gitlab.com/trongtruong2509/kaapana"
# CONTAINER_REGISTRY_USERNAME="trongtruong2509"
# CONTAINER_REGISTRY_PASSWORD="glpat-..."

# Make script executable and run deployment
chmod +x deploy_platform.sh
./deploy_platform.sh
```

**Advantages of GitLab Transfer:**
✅ Version control for all deployment artifacts
✅ Automatic backup and history
✅ Easy collaboration and sharing
✅ Built-in CI/CD capabilities
✅ Secure credential management
✅ No manual file transfers needed

---

## Method 3: AWS S3 Transfer

**Prerequisites:**
- AWS CLI installed on both machines
- S3 bucket with appropriate permissions
- IAM credentials configured

### On Build Machine

#### Step 1: Create Deployment Archive
```bash
cd ~/kaapana

# Create deployment archive (excluding Docker images)
tar -czf ~/kaapana-deployment.tar.gz \
  build/kaapana-admin-chart/ \
  --exclude='*.log' \
  --exclude='build/*.json'

# Check archive size (should be <200MB)
ls -lh ~/kaapana-deployment.tar.gz
```

#### Step 2: Upload to S3
```bash
# Set S3 bucket name
export S3_BUCKET="your-kaapana-transfer-bucket"

# Upload deployment archive
aws s3 cp ~/kaapana-deployment.tar.gz s3://$S3_BUCKET/

# Verify upload
aws s3 ls s3://$S3_BUCKET/
```

### On AWS Server

#### Step 3: Download and Extract
```bash
# Set S3 bucket name
export S3_BUCKET="your-kaapana-transfer-bucket"

# Download deployment archive
aws s3 cp s3://$S3_BUCKET/kaapana-deployment.tar.gz ~/

# Extract deployment artifacts
cd ~
tar -xzf ~/kaapana-deployment.tar.gz

# Verify deployment artifacts
ls -la kaapana/build/kaapana-admin-chart/deploy_platform.sh
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

# Deployment script
if [ -f ~/kaapana/kaapana-admin-chart/deploy_platform.sh ]; then
  echo "✅ deploy_platform.sh found"
  if [ -x ~/kaapana/kaapana-admin-chart/deploy_platform.sh ]; then
    echo "  ✅ Script is executable"
  else
    echo "  ❌ Script is not executable"
  fi
else
  echo "❌ deploy_platform.sh missing"
fi
echo ""

# Helm chart package
CHART_COUNT=$(find ~/kaapana/kaapana-admin-chart/kaapana-admin-chart/ -name "*.tgz" 2>/dev/null | wc -l)
echo "Helm Chart Packages: $CHART_COUNT"
if [ "$CHART_COUNT" -ge 1 ]; then
  echo "  ✅ Helm chart packages found"
  ls -la ~/kaapana/kaapana-admin-chart/kaapana-admin-chart/*.tgz
else
  echo "  ❌ Helm chart packages missing"
fi
echo ""

# GitLab registry connectivity (if using GitLab)
echo "Testing GitLab registry connectivity..."
docker pull registry.gitlab.com/library/alpine:latest > /dev/null 2>&1
if [ $? -eq 0 ]; then
  echo "  ✅ GitLab registry accessible"
else
  echo "  ❌ GitLab registry not accessible"
  echo "  → Run: docker login registry.gitlab.com"
fi
echo ""

# Disk space
DISK_AVAIL=$(df -h / | tail -1 | awk '{print $4}')
echo "Disk Space Available: $DISK_AVAIL"
if [[ "$DISK_AVAIL" == *"G"* ]]; then
  NUM_GB=$(echo $DISK_AVAIL | sed 's/G//')
  if [ "$NUM_GB" -gt 20 ]; then
    echo "  ✅ Sufficient disk space for deployment"
  else
    echo "  ⚠️  Low disk space (<20GB), consider expanding"
  fi
fi
echo ""

echo "=== Verification Complete ==="
EOF

chmod +x ~/verify-transfer.sh
~/verify-transfer.sh
```

**Expected output:**
```
=== Kaapana Transfer Verification ===

✅ deploy_platform.sh found
  ✅ Script is executable

Helm Chart Packages: 1
  ✅ Helm chart packages found
  -rw-r--r-- 1 ubuntu ubuntu 45M kaapana-admin-chart-0.5.2.tgz

  ✅ GitLab registry accessible

Disk Space Available: 78G
  ✅ Sufficient disk space for deployment

=== Verification Complete ===
```

---

## Troubleshooting

### SCP transfer fails: "Connection timeout"
```bash
# Check SSH connectivity
ssh -i $KEY_FILE ubuntu@$AWS_IP "echo 'Connection OK'"

# Try with verbose output
scp -v -i $KEY_FILE -r ~/kaapana/build/kaapana-admin-chart/ ubuntu@$AWS_IP:~/kaapana/

# Check AWS security group allows SSH (port 22)
# AWS Console → EC2 → Security Groups → Inbound Rules
```

### GitLab registry authentication fails
```bash
# Login to GitLab registry
echo "YOUR_GITLAB_TOKEN" | docker login registry.gitlab.com --username YOUR_USERNAME --password-stdin

# Verify login
docker pull registry.gitlab.com/YOUR_USERNAME/YOUR_PROJECT/base-python-cpu:latest
```

### Helm chart not found
```bash
# Check if charts were generated during build
ls -la ~/kaapana/build/kaapana-admin-chart/kaapana-admin-chart/

# If missing, rebuild charts only:
cd ~/kaapana/build-scripts
./start_build.py --config build-config.yaml --charts-only
```

### deploy_platform.sh not executable
```bash
# Make script executable
chmod +x ~/kaapana/kaapana-admin-chart/deploy_platform.sh

# Verify permissions
ls -la ~/kaapana/kaapana-admin-chart/deploy_platform.sh
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

- [x] `deploy_platform.sh` exists and is executable
- [x] Helm chart package (`*.tgz`) exists in `kaapana-admin-chart/` directory
- [x] GitLab registry accessible (or appropriate container registry)
- [x] At least 20GB disk space free (for application data)
- [x] SSH key access for remote management
- [x] Docker installed and configured
- [x] Kubernetes (MicroK8s) installed (from 05-server-installation.md)

**IMPORTANT:** No Docker images need to be transferred when using external registry (GitLab). Images will be pulled during deployment.

---

## Next Steps

✅ **Transfer complete!**

**Next:** [05-server-installation.md](05-server-installation.md)

You'll install MicroK8s and prepare the Kubernetes environment for Kaapana deployment.

---