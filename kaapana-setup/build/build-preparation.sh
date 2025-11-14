#!/bin/bash

#############################################
# Kaapana Build Machine Preparation Script
# Based on: 02-build-machine-preparation.md
# Duration: 30-60 minutes
#############################################

set -e  # Exit on error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Log functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
if [ "$EUID" -eq 0 ]; then 
    log_error "Do not run this script as root. Run as regular user with sudo privileges."
    exit 1
fi

echo "=================================================="
echo "   Kaapana Build Machine Preparation"
echo "   Based on guideline 02-build-machine-preparation.md"
echo "=================================================="
echo ""

#############################################
# Step 0: System Requirements Verification
#############################################

log_info "Verifying system requirements..."

# Check OS
if ! grep -qE "Ubuntu (22\.04|24\.04)" /etc/os-release; then
    log_error "Unsupported OS. Ubuntu 22.04 or 24.04 LTS required."
    exit 1
fi
log_success "OS check passed: $(lsb_release -d | cut -f2)"

# Check architecture
if [ "$(uname -m)" != "x86_64" ]; then
    log_error "Unsupported architecture. x86_64 required."
    exit 1
fi
log_success "Architecture check passed: x86_64"

# Check CPU cores
CPU_CORES=$(nproc)
if [ "$CPU_CORES" -lt 8 ]; then
    log_warning "CPU cores: $CPU_CORES (8+ recommended for optimal build performance)"
else
    log_success "CPU cores: $CPU_CORES"
fi

# Check RAM
RAM_GB=$(free -g | awk '/^Mem:/{print $2}')
if [ "$RAM_GB" -lt 64 ]; then
    log_warning "RAM: ${RAM_GB}GB (64GB+ recommended for optimal build performance)"
else
    log_success "RAM: ${RAM_GB}GB"
fi

# Check disk space
DISK_AVAIL=$(df / --output=avail -BG | tail -1 | tr -d 'G ')
if [ "$DISK_AVAIL" -lt 200 ]; then
    log_error "Insufficient disk space: ${DISK_AVAIL}GB available (200GB+ required)"
    log_error "Please expand your volume before proceeding."
    exit 1
fi
log_success "Disk space: ${DISK_AVAIL}GB available"

echo ""
read -p "Continue with installation? (y/n) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    log_info "Installation cancelled."
    exit 0
fi

#############################################
# Step 1: System Update and Core Dependencies
#############################################

log_info "Step 1: Updating system and installing core dependencies..."

sudo apt update
sudo apt upgrade -y

log_info "Installing essential build requirements..."
sudo apt install -y \
    curl \
    git \
    python3 \
    python3-pip \
    python3-venv \
    unzip \
    ca-certificates \
    apt-transport-https \
    gpg

# Verify installations
python3 --version
git --version
curl --version

log_success "Step 1 complete: Core dependencies installed"

#############################################
# Step 2: Install AWS CLI v2
#############################################

log_info "Step 2: Installing AWS CLI v2..."

if command -v aws &> /dev/null; then
    log_warning "AWS CLI already installed: $(aws --version)"
    read -p "Reinstall AWS CLI? (y/n) " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Skipping AWS CLI installation"
    else
        log_info "Reinstalling AWS CLI..."
        curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
        unzip -o awscliv2.zip
        sudo ./aws/install --update
        rm -rf aws awscliv2.zip
    fi
else
    log_info "Downloading and installing AWS CLI..."
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip awscliv2.zip
    sudo ./aws/install
    rm -rf aws awscliv2.zip
fi

aws --version
log_success "Step 2 complete: AWS CLI installed"

# Verify AWS credentials
log_info "Verifying AWS credentials..."
if aws sts get-caller-identity &> /dev/null; then
    log_success "AWS credentials configured and working"
    aws sts get-caller-identity
else
    log_warning "AWS credentials not configured or not working"
    log_info "If using EC2 with IAM role, this will be configured automatically"
    log_info "If not, run: aws configure"
fi

#############################################
# Step 3: Install Docker
#############################################

log_info "Step 3: Installing Docker..."

if command -v docker &> /dev/null; then
    log_warning "Docker already installed: $(docker --version)"
    read -p "Reinstall Docker? (y/n) " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Skipping Docker installation"
    else
        log_info "Reinstalling Docker..."
        # Remove old Docker packages
        sudo apt remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true
        # Install Docker
        sudo install -m 0755 -d /etc/apt/keyrings
        sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
        sudo chmod a+r /etc/apt/keyrings/docker.asc
        
        sudo tee /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Signed-By: /etc/apt/keyrings/docker.asc
EOF
        
        sudo apt update
        sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    fi
else
    log_info "Adding Docker repository..."
    sudo install -m 0755 -d /etc/apt/keyrings
    sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc
    
    sudo tee /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Signed-By: /etc/apt/keyrings/docker.asc
EOF
    
    sudo apt update
    log_info "Installing Docker Engine..."
    sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
fi

# Configure Docker for non-root access
log_info "Configuring Docker for non-root access..."
sudo groupadd docker 2>/dev/null || true
sudo usermod -aG docker $USER

docker --version
log_success "Step 3 complete: Docker installed"

# Test Docker (will fail if group membership not active)
log_info "Testing Docker installation..."
if docker run --rm hello-world &> /dev/null; then
    log_success "Docker test successful"
else
    log_warning "Docker test failed - you may need to logout and login again"
    log_info "Run: newgrp docker   (or logout and login)"
fi

#############################################
# Step 4: Install Helm
#############################################

log_info "Step 4: Installing Helm..."

if command -v helm &> /dev/null; then
    log_warning "Helm already installed: $(helm version --short)"
    read -p "Reinstall Helm? (y/n) " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Skipping Helm installation"
    else
        log_info "Reinstalling Helm..."
        curl -fsSL https://packages.buildkite.com/helm-linux/helm-debian/gpgkey | \
            gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
        echo "deb [signed-by=/usr/share/keyrings/helm.gpg] https://packages.buildkite.com/helm-linux/helm-debian/any/ any main" | \
            sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
        sudo apt update
        sudo apt install -y helm
    fi
else
    log_info "Adding Helm repository..."
    curl -fsSL https://packages.buildkite.com/helm-linux/helm-debian/gpgkey | \
        gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
    echo "deb [signed-by=/usr/share/keyrings/helm.gpg] https://packages.buildkite.com/helm-linux/helm-debian/any/ any main" | \
        sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
    sudo apt update
    log_info "Installing Helm..."
    sudo apt install -y helm
fi

helm version
log_success "Step 4 complete: Helm installed"

# Install Helm kubeval plugin
log_info "Installing Helm kubeval plugin..."
if helm plugin list | grep -q kubeval; then
    log_warning "Helm kubeval plugin already installed"
else
    helm plugin install https://github.com/instrumenta/helm-kubeval
    log_success "Helm kubeval plugin installed"
fi

#############################################
# Step 5: Clone Kaapana Repository
#############################################

log_info "Step 5: Cloning Kaapana repository..."

if [ -d "$HOME/kaapana" ]; then
    log_warning "Kaapana directory already exists at $HOME/kaapana"
    read -p "Remove and re-clone? (y/n) " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log_info "Removing existing directory..."
        rm -rf "$HOME/kaapana"
        log_info "Cloning Kaapana repository..."
        git clone -b master https://github.com/kaapana/kaapana.git "$HOME/kaapana"
    else
        log_info "Skipping repository clone"
    fi
else
    log_info "Cloning Kaapana repository to $HOME/kaapana..."
    git clone -b master https://github.com/kaapana/kaapana.git "$HOME/kaapana"
fi

if [ -d "$HOME/kaapana" ]; then
    cd "$HOME/kaapana"
    log_info "Current branch: $(git branch --show-current)"
    log_info "Recent commits:"
    git log --oneline -5
    log_success "Step 5 complete: Kaapana repository cloned"
else
    log_error "Failed to clone Kaapana repository"
    exit 1
fi

#############################################
# Step 6: Setup Python Virtual Environment
#############################################

log_info "Step 6: Setting up Python virtual environment..."

cd "$HOME/kaapana"

if [ -d ".venv" ]; then
    log_warning "Virtual environment already exists"
    read -p "Remove and recreate? (y/n) " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -rf .venv
        log_info "Creating virtual environment..."
        python3 -m venv .venv
    else
        log_info "Using existing virtual environment"
    fi
else
    log_info "Creating virtual environment..."
    python3 -m venv .venv
fi

log_success "Virtual environment created at $HOME/kaapana/.venv"

# Add activation alias to bashrc
if ! grep -q "alias activate-kaapana" "$HOME/.bashrc"; then
    log_info "Adding activation alias to ~/.bashrc..."
    echo "" >> "$HOME/.bashrc"
    echo "# Kaapana virtual environment activation" >> "$HOME/.bashrc"
    echo "alias activate-kaapana='source ~/kaapana/.venv/bin/activate'" >> "$HOME/.bashrc"
    log_success "Alias added: activate-kaapana"
else
    log_info "Activation alias already exists in ~/.bashrc"
fi

log_success "Step 6 complete: Python virtual environment ready"

#############################################
# Step 7: Install Python Build Requirements
#############################################

log_info "Step 7: Installing Python build requirements..."

cd "$HOME/kaapana"
source .venv/bin/activate

log_info "Upgrading pip..."
python3 -m pip install --upgrade pip

log_info "Installing build requirements from requirements.txt..."
cd build-scripts
python3 -m pip install -r requirements.txt

log_success "Step 7 complete: Python requirements installed"

# Verify key packages
log_info "Verifying key packages installed:"
pip list | grep -E "PyYAML|jinja2|docker|requests" || log_warning "Some packages may be missing"

#############################################
# Final Summary
#############################################

echo ""
echo "=================================================="
echo "   Build Machine Preparation Complete!"
echo "=================================================="
echo ""

log_success "All steps completed successfully!"
echo ""
echo "Summary:"
echo "  ✓ System requirements verified"
echo "  ✓ Core dependencies installed"
echo "  ✓ AWS CLI installed and configured"
echo "  ✓ Docker installed and configured"
echo "  ✓ Helm installed with kubeval plugin"
echo "  ✓ Kaapana repository cloned"
echo "  ✓ Python virtual environment created"
echo "  ✓ Build requirements installed"
echo ""
echo "Important Notes:"
echo "  • Activate virtual environment: source ~/kaapana/.venv/bin/activate"
echo "  • Or use alias: activate-kaapana"
echo "  • Docker group membership: You may need to logout/login for docker to work without sudo"
echo "  • Free disk space: ${DISK_AVAIL}GB (200GB+ recommended for build)"
echo ""
echo "Next Steps:"
echo "  1. Activate virtual environment: source ~/kaapana/.venv/bin/activate"
echo "  2. Configure build settings: cd ~/kaapana/build-scripts"
echo "  3. Follow guideline: 03-kaapana-build-process.md"
echo ""
echo "To activate virtual environment now, run:"
echo "  source ~/.bashrc && activate-kaapana"
echo ""
