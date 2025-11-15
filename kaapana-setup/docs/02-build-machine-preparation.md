# 02 - Build Machine Preparation

**Phase:** 1 - Preparation  
**Duration:** 30-60 minutes  

---

## Overview

This guide prepares your build machine to compile Kaapana from source. You'll install and configure all necessary tools, including AWS CLI, Docker, Helm, and Python dependencies.


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
cat /etc/*release
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

## Installation Methods

You have two options for preparing the build machine:

- **Automated Installation (Recommended):** Run the provided script that handles all installations automatically
- **Manual Installation:** Follow the step-by-step instructions for each tool

## Automated Installation (Recommended)

Run the automated preparation script that installs and configures all required tools:

```bash
# ssh into your build machine 
# And clone the setup repository
git clone https://github.com/nova-iris/uw-kaapana.git ~/uw-kaapana

# Navigate to the build scripts directory
cd ~/uw-kaapana/kaapana-setup/build

# Make the script executable (if needed)
chmod +x build-preparation.sh

# Run the automated preparation script
./build-preparation.sh
```

**What the script does:**
- Verifies system requirements (OS, CPU, RAM, disk space)
- Updates system packages
- Installs AWS CLI v2 and verifies credentials
- Installs Docker from official repository
- Configures Docker for non-root access
- Installs Helm with kubeval plugin
- Clones Kaapana repository
- Creates Python virtual environment
- Installs Python build requirements
- Adds convenient aliases to ~/.bashrc

**After the script completes:**
```bash
# Activate the virtual environment
source ~/.bashrc  # Reload bashrc to add aliases
activate-kaapana  # Use the alias created by the script

# Verify everything is working
python3 --version
docker --version
helm version
```

**Continue to:** [Next Steps](#next-steps)

---

## Manual Installation

Follow the detailed step-by-step instructions below if you prefer manual setup or need to customize specific components.

**Note:** The following manual instructions are provided for reference or for users who need to customize specific components. Most users should use the [Automated Installation](#automated-installation-recommended) option above.


### Step 1: System Update and Core Dependencies

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
---

### Step 2: Install AWS CLI

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

### Step 3: Install Docker

**Add Docker's official repository and install:**
```bash
# Add Docker's official GPG key:
sudo apt update
sudo apt install ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
sudo tee /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Signed-By: /etc/apt/keyrings/docker.asc
EOF

sudo apt update

# Install Docker Engine
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

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
---

### Step 4: Install Helm

**Add Helm's official repository and install:**
```bash
# Install dependencies
sudo apt install -y curl gpg apt-transport-https

# Add Helm GPG key
curl -fsSL https://packages.buildkite.com/helm-linux/helm-debian/gpgkey | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null

# Add Helm repository
echo "deb [signed-by=/usr/share/keyrings/helm.gpg] https://packages.buildkite.com/helm-linux/helm-debian/any/ any main" | \
  sudo tee /etc/apt/sources.list.d/helm-stable-debian.list

# Install Helm
sudo apt update
sudo apt install -y helm

# Verify Helm installation
helm version
```

**Install Helm kubeval plugin:**
```bash
helm plugin install https://github.com/instrumenta/helm-kubeval

# Verify plugin installation:
helm plugin list
# Expected output:
# kubeval 0.x.x   Validate Helm charts against Kubernetes schemas
```
---

### Step 5: Clone Kaapana Repository

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

### Step 6: Setup Python Virtual Environment (Recommended)

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

### Step 7: Install Python Build Requirements

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
```

---

## Next Steps

✅ **Build machine is ready!**

Now you have two options for deploying Kaapana:

### Option 1: Build from Source (Recommended for Customization)
**Next:** [03-kaapana-build-process.md](03-kaapana-build-process.md)
- Build Kaapana Docker images from source (~2 hours)
- Full control over build configuration
- Requires building 90+ containers locally
- Script location: `~/kaapana/build/kaapana-admin-chart/deploy_platform.sh`

### Option 2: Use Pre-built Images (Recommended for Quick Deployment)
**Next:** [06-platform-deployment.md](06-platform-deployment.md)
- Use pre-built Docker images from GitLab registry
- Faster deployment (~30 minutes)
- Requires GitLab registry credentials
- Script location: `~/uw-kaapana/kaapana-setup/build/deploy_platform.sh`

**Choose Option 1** if you need to customize Kaapana or want to build from source.
**Choose Option 2** if you want quick deployment with standard configurations.

### Required Credentials

Both options require proper registry credentials:
- **Option 1**: AWS ECR credentials (configured during build)
- **Option 2**: GitLab registry credentials for pre-built images

```bash
# For GitLab registry access (Option 2)
# You'll need to configure these in deployment:
# Registry URL: registry.gitlab.com
# Username: Your GitLab username
# Password: GitLab access token with registry access
```

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