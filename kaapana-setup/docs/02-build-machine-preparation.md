# 02 - Build Machine Preparation

**Phase:** 1 - Preparation  
**Duration:** 30-60 minutes  
**Prerequisite:** Ubuntu 22.04 or 24.04 LTS (x64)

---

## Overview

This guide prepares your build machine to compile Kaapana from source. You can use:
- **Option A:** Your AWS EC2 instance (build then deploy on same machine)
- **Option B:** Separate Ubuntu build machine (build, then transfer to AWS)

**Recommended:** Use your AWS instance as the build machine for simplicity.

---

## Build Machine Requirements

### Minimum Specifications
- **OS:** Ubuntu 22.04 or 24.04 LTS (x64 ONLY)
- **CPU:** 8 cores minimum (16 cores recommended)
- **RAM:** 64GB minimum (128GB recommended)
- **Disk:** 200GB+ free space (build requires ~110GB for images + ~80GB for offline tarball if created)
- **Network:** Good internet connection (10+ Mbps)

### Verify System

```bash
# Check OS
lsb_release -a
# Must show: Ubuntu 22.04 or 24.04

# Check architecture
uname -m
# Must show: x86_64

# Check CPU cores
nproc
# Should show: 8+ (16+ recommended)

# Check RAM
free -h
# Should show: 64GB+ total (128GB+ recommended)

# Check disk space
df -h /
# Should show: 200GB+ available
```

**⚠️ Important Disk Space Note:**
- Docker images will be stored at `/var/lib/docker/`
- Complete build requires ~90GB (~110GB with build cache)
- Creating offline installation tarball requires ~80GB additional space
- Total recommended: 200GB+ free space

---

## Step 1: System Update and Core Dependencies

```bash
# Update package lists
sudo apt update

# Upgrade all packages
sudo apt upgrade -y

# Install essential build requirements
sudo apt install -y \
  curl \
  git \
  python3 \
  python3-pip

# Verify core installations
python3 --version  # Should be 3.10+
git --version
curl --version
```

**Note:** This follows the official Kaapana build requirements. Additional tools like `jq` and `screen` can be installed if needed for your workflow.

---

## Step 2: Install AWS CLI (Required for ECR)

**Install AWS CLI v2:**
```bash
# Download and install AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Verify installation
aws --version
```

**Expected output:**
```
aws-cli/2.31.35 Python/3.13.9 Linux/6.14.0-1016-aws exe/x86_64.ubuntu.24
```

**Configure AWS CLI (if not using IAM role):**
```bash
aws configure
# Enter your AWS Access Key ID
# Enter your AWS Secret Access Key
# Enter default region: us-east-1
# Enter default output format: json
```

**Verify AWS credentials:**
```bash
# If using EC2 with IAM role (recommended):
aws sts get-caller-identity
# Should show your AWS account and role information
```

**Expected output:**
```json
{
    "UserId": "AROA...:i-097dedda497eea74d",
    "Account": "223271671018",
    "Arn": "arn:aws:sts::223271671018:assumed-role/kaapana-poc-poc-ec2-role/i-097dedda497eea74d"
}
```

---

## Step 3: Install Docker

**Add Docker's official repository and install:**
```bash
# Add Docker's official GPG key
sudo apt-get update
sudo apt-get install -y ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add Docker repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker Engine
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Verify Docker installation
docker --version
```

**Configure Docker for non-root access:**
```bash
# Create docker group (if not exists)
sudo groupadd docker 2>/dev/null || true

# Add current user to docker group
sudo usermod -aG docker $USER

# Activate group membership for current session
newgrp docker

# Verify Docker works without sudo
docker run hello-world
```

**Expected output:**
```
Hello from Docker!
This message shows that your installation appears to be working correctly.
```

**Verify Docker setup:**
```bash
# Check Docker info
docker info | head -20

# Check Docker images
docker images

# Check Docker data location
ls -lh /var/lib/docker/
```

---

## Step 4: Install Helm

**Add Helm's official repository and install:**
```bash
# Install dependencies
sudo apt-get install -y curl gpg apt-transport-https

# Add Helm GPG key
curl -fsSL https://packages.buildkite.com/helm-linux/helm-debian/gpgkey | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null

# Add Helm repository
echo "deb [signed-by=/usr/share/keyrings/helm.gpg] https://packages.buildkite.com/helm-linux/helm-debian/any/ any main" | \
  sudo tee /etc/apt/sources.list.d/helm-stable-debian.list

# Install Helm
sudo apt-get update
sudo apt-get install -y helm

# Verify Helm installation
helm version
```

**Install Helm kubeval plugin:**
```bash
helm plugin install https://github.com/instrumenta/helm-kubeval
```

**Verify plugin installation:**
```bash
helm plugin list
```

**Expected output:**
```
NAME    VERSION DESCRIPTION
kubeval 0.x.x   Validate Helm charts against Kubernetes schemas
```

---

## Step 5: Clone Kaapana Repository

```bash
# Clone Kaapana repository (master branch)
git clone -b master https://github.com/kaapana/kaapana.git

# Verify clone
ls -la kaapana/
cd kaapana
git branch
git log --oneline -5
```

**Expected structure:**
```
kaapana/
├── build-scripts/
├── server-installation/
├── platforms/
├── services/
├── data-processing/
├── docs/
├── README.md
└── ... (other directories)
```

---

## Step 6: Setup Python Virtual Environment (Recommended)

**Why use a virtual environment?**
- Best practice for Python dependency management
- Isolates Kaapana build dependencies from system packages
- On Ubuntu 24.04+, installing packages with pip outside a virtual environment may result in errors (PEP 668)

**Install venv package (if not already installed):**
```bash
sudo apt install -y python3-venv
```

**Create virtual environment:**
```bash
# Navigate to Kaapana directory
cd ~/kaapana

# Create virtual environment (only needed once)
python3 -m venv .venv
```

**Activate virtual environment:**
```bash
# Activate the virtual environment
source ~/kaapana/.venv/bin/activate

# Verify activation (prompt should show (.venv))
which python3
# Should show: /home/ubuntu/kaapana/.venv/bin/python3
```

**Make activation easy:**
```bash
# Add alias to bashrc for quick activation
echo "alias activate-kaapana='source ~/kaapana/.venv/bin/activate'" >> ~/.bashrc
source ~/.bashrc

# Test alias
activate-kaapana
```

---

## Step 7: Install Python Build Requirements

**Ensure virtual environment is activated:**
```bash
source ~/kaapana/.venv/bin/activate
```

**Install Kaapana build requirements:**
```bash
# Navigate to build-scripts directory
cd ~/kaapana/build-scripts

# Install Python requirements
python3 -m pip install -r requirements.txt

# Verify key packages installed
pip list | grep -E "PyYAML|jinja2|click|docker"
```

**Expected packages:**
- PyYAML
- Jinja2
- click
- docker
- requests
- (and others as specified in requirements.txt)

---

---

## Step 8: Verify Build Environment

**Run verification script:**

```bash
# Create verification script
cat > ~/verify-build-env.sh << 'EOF'
#!/bin/bash
echo "=== Build Environment Verification ==="
echo ""

# OS Check
echo "OS: $(lsb_release -d | cut -f2)"
echo "Architecture: $(uname -m)"
echo ""

# Resources
echo "CPU Cores: $(nproc)"
echo "RAM: $(free -h | grep Mem | awk '{print $2}')"
echo "Root Disk Space: $(df -h / | tail -1 | awk '{print $4}')"
echo "Docker Disk Space: $(df -h /var/lib/docker | tail -1 | awk '{print $4}')"
echo ""

# Snap
echo "Snap: $(snap version | head -1 2>/dev/null || echo 'NOT INSTALLED')"
echo ""

# Snap
echo "Snap: $(snap version | head -1 2>/dev/null || echo 'NOT INSTALLED')"
echo ""

# Tools
echo "Docker: $(docker --version 2>/dev/null || echo 'NOT INSTALLED')"
echo "Helm: $(helm version --short 2>/dev/null || echo 'NOT INSTALLED')"
echo "Git: $(git --version 2>/dev/null || echo 'NOT INSTALLED')"
echo "Python: $(python3 --version 2>/dev/null || echo 'NOT INSTALLED')"
echo ""

# Docker Test
echo "Docker Test:"
if docker run --rm hello-world &>/dev/null; then
  echo "  ✅ Docker working (no sudo required)"
else
  echo "  ❌ Docker not working"
fi
echo ""

# Kaapana Repo
if [ -d ~/kaapana ]; then
  echo "✅ Kaapana repository cloned"
  echo "   Location: ~/kaapana"
else
  echo "❌ Kaapana repository not found"
fi
echo ""

# Python venv
if [ -d ~/kaapana/.venv ]; then
  echo "✅ Python virtual environment created"
else
  echo "❌ Python virtual environment not found"
fi
echo ""

# Build requirements
if source ~/kaapana/.venv/bin/activate && python3 -c "import docker, yaml, jinja2" 2>/dev/null; then
  echo "✅ Python build requirements installed"
  deactivate
else
  echo "❌ Python build requirements missing"
fi

echo ""
echo "=== Verification Complete ==="
EOF

chmod +x ~/verify-build-env.sh
~/verify-build-env.sh
```

**Expected output:**
```
=== Build Environment Verification ===

OS: Ubuntu 24.04.x LTS
Architecture: x86_64

CPU Cores: 16
RAM: 64Gi
Root Disk Space: 180G
Docker Disk Space: 180G

Snap: snap    2.63
snapd  2.63

Docker: Docker version 27.x.x, build xxxxxxx
Helm: v3.x.x
Git: git version 2.43.x
Python: Python 3.12.x

Docker Test:
  ✅ Docker working (no sudo required)

✅ Kaapana repository cloned
   Location: ~/kaapana

✅ Python virtual environment created

✅ Python build requirements installed

=== Verification Complete ===
```

**⚠️ Important Notes:**
- Ensure Docker Disk Space shows at least 200GB free at `/var/snap/docker/common/var-lib-docker/`
- Complete build requires ~90GB (~110GB with cache) + ~80GB if creating offline tarball
- If disk space is insufficient, follow the "Out of disk space" troubleshooting section

---

## Troubleshooting

### Docker permission denied
```bash
# Add user to docker group again
sudo usermod -aG docker $USER

# Apply group membership immediately
newgrp docker

# Test again
docker run hello-world

# Or logout and login again for group changes to take effect
exit
# Then SSH back in
```

### Python virtual environment issues
```bash
# If venv creation fails, ensure python3-venv is installed
sudo apt install -y python3-venv

# Remove existing venv and recreate
rm -rf ~/kaapana/.venv
cd ~/kaapana
python3 -m venv .venv

# Activate and verify
source ~/kaapana/.venv/bin/activate
which python3
```

### Python packages not found
```bash
# Ensure venv is activated
source ~/kaapana/.venv/bin/activate

# Check prompt - should show (.venv)
which python3

# Upgrade pip first
python3 -m pip install --upgrade pip

# Reinstall requirements
cd ~/kaapana/build-scripts
python3 -m pip install -r requirements.txt

# Verify installation
pip list | grep -E "PyYAML|jinja2|docker"
```

### Out of disk space

**⚠️ CRITICAL:** Kaapana build requires significant disk space. Plan accordingly BEFORE building.

**Space Requirements:**
- Build phase: ~90GB for 90+ container images
- Build cache: ~20GB additional
- Optional offline tarball: ~80GB additional
- **Total required: 200GB+ free space (300GB+ recommended)**

**Check current usage:**
```bash
# Check available space
df -h /
df -h /var/snap/docker/common/

# Check Docker current usage
du -sh /var/snap/docker/common/var-lib-docker/
docker system df

# Identify what's using space
docker images --format "table {{.Repository}}\t{{.Size}}" | sort -k3 -h
```

**Option 1: Expand AWS Root Volume (Recommended for Single Volume Setup)**

```bash
# 1. AWS Console → EC2 → Volumes
#    - Select root volume (e.g., /dev/nvme0n1)
#    - Click "Modify Volume"
#    - Increase size to 300GB or 500GB
# 2. Wait 5-10 minutes for volume to expand
# 3. On server:

sudo growpart /dev/nvme0n1 1
sudo resize2fs /dev/nvme0n1p1

# Verify new size
df -h /
# Should now show 300GB+ available
```

**Option 2: Use Additional AWS Volume (if available)**

```bash
# Check for unmounted volumes
sudo lsblk -f
sudo file -s /dev/nvme1n1  # Check second disk

# If additional disk exists and is uninitialized:
sudo mkfs.ext4 /dev/nvme1n1
sudo mkdir -p /mnt/docker-storage
sudo mount /dev/nvme1n1 /mnt/docker-storage
sudo chown ubuntu:ubuntu /mnt/docker-storage

# Verify
df -h /mnt/docker-storage

# Add to fstab for persistent mounting after reboot
echo '/dev/nvme1n1 /mnt/docker-storage ext4 defaults,nofail 0 2' | sudo tee -a /etc/fstab
```

**Option 3: Clean Before Build (Limited help on first build)**

```bash
# Remove unused Docker images and build cache
docker system prune -af

# Check space freed
df -h /

# This only helps if you have old builds from previous attempts
```

**If you run out of space DURING the build:**

```bash
# 1. Stop the build immediately
# Press Ctrl+C (if in screen: Ctrl+A then K)

# 2. Clean Docker build cache (safe to do while build is stopped)
docker builder prune -af

# 3. Check freed space
df -h /

# 4. Either expand volume (Option 1) or use additional volume (Option 2)

# 5. Restart the build:
cd ~/kaapana
source ~/.venv/bin/activate
cd build-scripts
python3 start_build.py --config build-config.yaml --build-only --parallel 4
```

---

## Build Machine Ready Checklist

Before proceeding to the build process, verify:

- [ ] Ubuntu 22.04 or 24.04 LTS installed (x64 only)
- [ ] At least 8 CPU cores (16+ recommended)
- [ ] At least 64GB RAM (128GB recommended)
- [ ] At least 200GB free disk space (for build + cache + optional offline tarball)
- [ ] AWS CLI v2 installed and configured
- [ ] AWS credentials working (IAM role or access keys)
- [ ] Docker installed from official repository and working without sudo
- [ ] Helm installed from official repository with kubeval plugin
- [ ] Git and Python 3.10+ installed
- [ ] Kaapana repository cloned to ~/kaapana
- [ ] Python virtual environment created at ~/kaapana/.venv
- [ ] Python build requirements installed in virtual environment
- [ ] Verification script passed all checks
- [ ] Internet connectivity working
- [ ] ECR access configured (if using AWS ECR for container registry)

---

## Next Steps

✅ **Build machine is ready!**

**Next:** [03-kaapana-build-process.md](03-kaapana-build-process.md)

You'll configure the build settings and execute the Kaapana build process (~1 hour).

---

## Reference Documentation

This guide is based on the official Kaapana documentation:

- **Kaapana Build Guide:** https://kaapana.readthedocs.io/en/latest/installation_guide/build.html
- **Kaapana Requirements:** https://kaapana.readthedocs.io/en/latest/installation_guide/requirements.html
- **Docker Installation (Linux):** https://docs.docker.com/engine/install/ubuntu/
- **Docker Post-Install (Linux):** https://docs.docker.com/engine/install/linux-postinstall/
- **Helm Installation:** https://helm.sh/docs/intro/install/
- **Kaapana GitHub Repository:** https://github.com/kaapana/kaapana

---

**Document Status:** ✅ Complete  
**Last Updated:** Using official Docker and Helm repositories (no snap required)  
**Next Document:** 03-kaapana-build-process.md
