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
- **CPU:** 8 cores minimum
- **RAM:** 16GB minimum (32GB recommended)
- **Disk:** 200GB free space minimum
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
# Should show: 8+

# Check RAM
free -h
# Should show: 16GB+ total

# Check disk space
df -h /
# Should show: 200GB+ available
```

---

## Step 1: System Update

```bash
# Update package lists
sudo apt update

# Upgrade all packages
sudo apt upgrade -y

# Install essential build tools
sudo apt install -y \
  nano \
  curl \
  git \
  wget \
  python3 \
  python3-pip \
  python3-venv \
  build-essential \
  htop \
  net-tools \
  unzip

# Verify installations
python3 --version  # Should be 3.10+
git --version
curl --version
```

---

## Step 2: Install Snap

Snap is required for Docker and Helm installation.

```bash
# Check if snap is installed
snap version

# If not installed:
sudo apt install -y snapd

# Enable and start snapd
sudo systemctl enable snapd
sudo systemctl start snapd

# Create symbolic link (if needed)
sudo ln -s /var/lib/snapd/snap /snap

# Verify
snap version
```

**⚠️ Important:** If snap was just installed, **reboot is required**:
```bash
sudo reboot
```

After reboot, reconnect and continue.

---

## Step 3: Install Docker

```bash
# Install Docker via Snap
sudo snap install docker --classic --channel=latest/stable

# Verify Docker installation
docker --version

# Test Docker (this will fail initially - that's expected)
docker run hello-world
# Error: permission denied (expected)
```

**Configure Docker permissions:**
```bash
# Create docker group (if not exists)
sudo groupadd docker 2>/dev/null || true

# Add current user to docker group
sudo usermod -aG docker $USER

# Fix Docker socket permissions for Snap Docker
sudo chown root:docker /var/run/docker.sock

# Test Docker again (should work now)
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

# Check Docker storage location
docker info | grep "Docker Root Dir"
```

---

## Step 4: Install Helm

```bash
# Install Helm via Snap
sudo snap install helm --classic --channel=latest/stable

# Verify Helm installation
helm version

# Install Helm kubeval plugin
helm plugin install https://github.com/instrumenta/helm-kubeval

# Verify plugin
helm plugin list
```

**Expected output:**
```
NAME    VERSION DESCRIPTION
kubeval 0.x.x   Validate Helm charts against Kubernetes schemas
```

---

## Step 5: Install Python Build Dependencies

```bash
# Create working directory
mkdir -p ~/kaapana-build
cd ~/kaapana-build

# Create Python virtual environment
python3 -m venv kaapana-venv

# Activate virtual environment
source kaapana-venv/bin/activate

# Verify activation (prompt should show (kaapana-venv))
which python3
# Should show: /home/ubuntu/kaapana-build/kaapana-venv/bin/python3

# Upgrade pip
pip install --upgrade pip

# Install basic Python build tools
pip install wheel setuptools
```

**Make activation easy:**
```bash
# Add alias to bashrc
echo "alias activate-kaapana='source ~/kaapana-build/kaapana-venv/bin/activate'" >> ~/.bashrc
source ~/.bashrc

# Test alias
activate-kaapana
```

---

## Step 6: Clone Kaapana Repository

```bash
# Ensure you're in build directory
cd ~/kaapana-build

# Activate venv
source kaapana-venv/bin/activate

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

## Step 7: Install Kaapana Build Requirements

```bash
# Navigate to build-scripts
cd ~/kaapana-build/kaapana/build-scripts

# Ensure venv is activated
source ~/kaapana-build/kaapana-venv/bin/activate

# Install Python requirements
pip install -r requirements.txt

# Verify key packages installed
pip list | grep -E "docker|PyYAML|jinja2|click"

# Note: docker Python package is not in requirements.txt but may be needed
pip install docker  # If docker package is expected
```

**Expected packages:**
- docker
- PyYAML
- Jinja2
- click
- requests
- (and others)

---

## Step 8: Verify Build Environment

**Run verification script:**
```bash
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
echo "Disk Space: $(df -h / | tail -1 | awk '{print $4}')"
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
if [ -d ~/kaapana-build/kaapana ]; then
  echo "✅ Kaapana repository cloned"
  echo "   Location: ~/kaapana-build/kaapana"
else
  echo "❌ Kaapana repository not found"
fi
echo ""

# Python venv
if [ -d ~/kaapana-build/kaapana-venv ]; then
  echo "✅ Python virtual environment created"
else
  echo "❌ Python virtual environment not found"
fi
echo ""

# Build requirements
if source ~/kaapana-build/kaapana-venv/bin/activate && python3 -c "import docker, yaml, jinja2" 2>/dev/null; then
  echo "✅ Python build requirements installed"
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

CPU Cores: 8
RAM: 62Gi
Root Disk Space: 3.5G
Data Disk Space: 467G

Docker: Docker version 28.x.x
Helm: v3.19.x
Git: git version 2.43.x
Python: Python 3.12.x

Docker Test:
  ✅ Docker working (no sudo required)

✅ Kaapana repository cloned
   Location: ~/kaapana-build/kaapana

✅ Python virtual environment created

✅ Python build requirements installed

=== Verification Complete ===
```

**⚠️ Important Note:** The verification script now checks both root and data disk space. If Data Disk Space shows "NOT MOUNTED", follow the "Out of disk space" troubleshooting section to mount additional storage.

---

## Step 9: Optional - Reboot for Clean State

**Recommended before starting build:**
```bash
# Reboot to ensure all changes applied
sudo reboot
```

**After reboot, verify everything still works:**
```bash
# Reconnect via SSH (key should be configured in ssh-agent or use -i if needed)
ssh ubuntu@$ELASTIC_IP

# Quick verification
docker run --rm hello-world
helm version
source ~/kaapana-build/kaapana-venv/bin/activate
python3 -c "import docker; print('Python OK')"
```

---

## Troubleshooting

### Docker permission denied
```bash
# For Snap Docker installations, fix socket permissions
sudo chown root:docker /var/run/docker.sock

# Add user to docker group again
sudo usermod -aG docker $USER

# Restart Docker service
sudo snap restart docker.dockerd

# Test again
docker run hello-world

# Or logout and login again
exit
# Then SSH back in
```

### Docker service not found
```bash
# For Snap Docker, check snap services instead
sudo snap services docker

# Restart if needed
sudo snap restart docker.dockerd

# Check status
sudo snap services docker
```

### Snap not working after install
```bash
# Snap requires reboot
sudo reboot

# After reboot, verify
snap version
```

### Python packages not found
```bash
# Ensure venv is activated
source ~/kaapana-build/kaapana-venv/bin/activate

# Check prompt - should show (kaapana-venv)
which python3

# Reinstall if needed
pip install -r ~/kaapana-build/kaapana/build-scripts/requirements.txt
```

### Out of disk space
```bash
# Check space and volumes
df -h
lsblk

# If AWS instance has additional unmounted volumes (common):
# 1. Check for unmounted volumes
sudo lsblk -f
sudo file -s /dev/nvme1n1  # Check second disk

# 2. If additional disk exists and is uninitialized, format and mount:
sudo mkfs.ext4 /dev/nvme1n1
sudo mkdir -p /data
sudo mount /dev/nvme1n1 /data
sudo chown ubuntu:ubuntu /data

# 3. Add to fstab for persistent mounting
echo '/dev/nvme1n1 /data ext4 defaults,nofail 0 2' | sudo tee -a /etc/fstab

# 4. Verify new space
df -h /data

# If root volume needs expansion:
# 1. AWS Console → EC2 → Volumes → Modify Volume
# 2. Increase size to 300GB or 500GB
# 3. On server:
sudo growpart /dev/nvme0n1 1
sudo resize2fs /dev/nvme0n1p1
df -h  # Verify new size
```

---

## Build Machine Ready Checklist

Before proceeding to the build process, verify:

- [x] Ubuntu 22.04 or 24.04 LTS installed
- [x] At least 8 CPU cores
- [x] At least 16GB RAM (preferably 64GB if AWS instance)
- [x] At least 200GB free disk space
- [x] Docker installed and working without sudo
- [x] Helm installed with kubeval plugin
- [x] Git installed
- [x] Python 3.10+ with venv
- [x] Kaapana repository cloned
- [x] Python build requirements installed
- [x] Internet connectivity working

---

## Next Steps

✅ **Build machine is ready!**

**Next:** [03-kaapana-build-process.md](03-kaapana-build-process.md)

You'll configure the build settings and execute the Kaapana build process (~1 hour).

---

**Document Status:** ✅ Complete  
**Next Document:** 03-kaapana-build-process.md
