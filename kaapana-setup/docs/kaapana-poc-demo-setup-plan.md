# Kaapana POC Demo Setup Plan

**Version:** 1.0  
**Date:** November 11, 2025  
**Target Completion:** 2 weeks  
**Focus:** Proof of Concept (POC) Setup

## Executive Summary

This document provides a detailed step-by-step plan for setting up a Kaapana POC demo environment on AWS infrastructure. The setup focuses on core functionality including DICOM processing, AI-based segmentation (nnU-Net), Airflow workflow orchestration, and user management. The deployment will use pre-built containers to expedite the setup process.

**Key Objectives:**
- Deploy minimal but functional Kaapana platform on AWS
- Demonstrate core medical imaging workflows
- Enable DICOM data processing and AI segmentation
- Validate system stability and persistence
- Prepare for testing and production phases (January 2025)

**Infrastructure Choice:** AWS (Amazon Web Services) has been selected as the cloud provider for this deployment.

---

## Phase Overview

### Timeline Breakdown
| Phase | Duration | Status |
|-------|----------|--------|
| Phase 1: Environment Preparation | 2-3 days | Milestone 1 |
| Phase 2: Base Platform Installation | 1-2 days | Milestone 2 |
| Phase 3: Core Modules Configuration | 3-4 days | Milestone 3 |
| Phase 4: Verification & Documentation | 2-3 days | Milestone 4 |
| **Total** | **8-12 days** | **POC Complete** |

---

## Phase 1: Environment Preparation & Familiarization

**Objective:** Prepare infrastructure and understand Kaapana architecture.

**Duration:** 2-3 days

### 1.1 Prerequisites

#### Required Knowledge
- Basic understanding of:
  - Linux system administration (Ubuntu)
  - Container technologies (Docker, Kubernetes)
  - Medical imaging concepts (DICOM)
  - Command-line operations

#### Required Access
- [ ] Kaapana GitHub repository access
- [ ] Kaapana Slack community membership
- [ ] DKFZ container registry credentials or pre-built tarball
- [ ] Cloud provider account (AWS or DigitalOcean recommended)

### 1.2 Hardware Requirements

#### Minimum Specifications (POC)
- **CPU:** 8 cores minimum (16 cores recommended)
- **RAM:** 64GB minimum (128GB recommended)
- **Storage:**
  - Fast storage (SSD): 100GB minimum (200GB recommended)
  - Slow storage (HDD): 100GB minimum (for DICOM images)
  - Total: 200GB minimum
- **Operating System:** Ubuntu Server 22.04 or 24.04 LTS
- **Network:** Internet access for container registry and updates
- **GPU:** Optional (NVIDIA GPU for accelerated AI processing)

#### AWS Instance Recommendations

**Selected Cloud Provider: Amazon Web Services (AWS)**

**Minimum Configuration (POC):**
- Instance type: `r5.2xlarge`
  - 8 vCPU
  - 64GB RAM
  - Network: Up to 10 Gbps
- Storage: 200GB gp3 SSD (3000 IOPS baseline)
- Estimated cost: ~$368/month (on-demand)
- Cost optimization: Use Savings Plans for ~40% discount

**Recommended Configuration (Production-ready POC):**
- Instance type: `r5.4xlarge`
  - 16 vCPU
  - 128GB RAM
  - Network: Up to 10 Gbps
- Storage: 500GB gp3 SSD (3000 IOPS baseline)
- Estimated cost: ~$736/month (on-demand)
- Cost optimization: Use Reserved Instances or Savings Plans

**Region Selection:**
- Choose region closest to your location for lower latency
- Consider: `us-east-1`, `us-west-2`, `eu-central-1`, or `ap-southeast-1`

### 1.3 Infrastructure Setup

#### Step 1: Provision AWS EC2 Instance

**Using AWS Console:**

1. **Login to AWS Console**
   ```
   Navigate to: https://console.aws.amazon.com/
   Login with your AWS credentials
   ```

2. **Launch EC2 Instance**
   ```
   Navigate to: EC2 Dashboard → Instances → Launch Instance
   ```

3. **Configure Instance:**
   - **Name:** `kaapana-poc-server`
   - **Application and OS Images (AMI):**
     - Select: Ubuntu Server 22.04 LTS or 24.04 LTS
     - Architecture: 64-bit (x86)
     - AMI ID: Search for "Ubuntu 22.04 LTS" or "Ubuntu 24.04 LTS"
   
   - **Instance type:**
     - For POC: `r5.2xlarge` (8 vCPU, 64GB RAM)
     - For better performance: `r5.4xlarge` (16 vCPU, 128GB RAM)
   
   - **Key pair (login):**
     - Create new key pair or select existing
     - Key pair name: `kaapana-poc-key`
     - Key pair type: RSA
     - Private key format: `.pem` (for SSH)
     - Download and save the `.pem` file securely
   
   - **Network settings:**
     - VPC: Default or create new
     - Subnet: Default (ensure it has internet access)
     - Auto-assign public IP: Enable
   
   - **Configure storage:**
     - Root volume:
       - Size: 200 GB (minimum) or 500 GB (recommended)
       - Volume type: gp3
       - IOPS: 3000 (default)
       - Throughput: 125 MB/s (default)
       - Delete on termination: Enable (or disable if you want to preserve data)
   
   - **Advanced details:**
     - Leave defaults or configure as needed

4. **Configure Security Group**
   
   Create a new security group named: `kaapana-poc-sg`
   
   **Inbound Rules:**
   ```
   Type            Protocol    Port Range    Source              Description
   SSH             TCP         22            Your IP/CIDR        SSH access
   HTTP            TCP         80            0.0.0.0/0           Web interface (redirect)
   HTTPS           TCP         443           0.0.0.0/0           Web interface
   Custom TCP      TCP         11112         0.0.0.0/0           DICOM DIMSE
   ```
   
   **Outbound Rules:**
   ```
   Type            Protocol    Port Range    Destination         Description
   All traffic     All         All           0.0.0.0/0           Internet access
   ```

5. **Review and Launch**
   - Review all settings
   - Click "Launch instance"
   - Wait for instance state to become "Running"
   - Note the Public IPv4 address

**Using AWS CLI (Alternative):**

```bash
# Set variables
INSTANCE_TYPE="r5.2xlarge"
AMI_ID="ami-xxxxxxxxx"  # Get latest Ubuntu 22.04 AMI for your region
KEY_NAME="kaapana-poc-key"
SECURITY_GROUP="kaapana-poc-sg"
SUBNET_ID="subnet-xxxxxxxxx"  # Your subnet ID

# Create key pair if needed
aws ec2 create-key-pair --key-name $KEY_NAME --query 'KeyMaterial' --output text > kaapana-poc-key.pem
chmod 400 kaapana-poc-key.pem

# Create security group
aws ec2 create-security-group \
  --group-name $SECURITY_GROUP \
  --description "Security group for Kaapana POC"

# Get security group ID
SG_ID=$(aws ec2 describe-security-groups --group-names $SECURITY_GROUP --query 'SecurityGroups[0].GroupId' --output text)

# Add inbound rules
aws ec2 authorize-security-group-ingress --group-id $SG_ID --protocol tcp --port 22 --cidr $(curl -s https://checkip.amazonaws.com)/32
aws ec2 authorize-security-group-ingress --group-id $SG_ID --protocol tcp --port 80 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id $SG_ID --protocol tcp --port 443 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id $SG_ID --protocol tcp --port 11112 --cidr 0.0.0.0/0

# Launch instance
aws ec2 run-instances \
  --image-id $AMI_ID \
  --instance-type $INSTANCE_TYPE \
  --key-name $KEY_NAME \
  --security-group-ids $SG_ID \
  --block-device-mappings 'DeviceName=/dev/sda1,Ebs={VolumeSize=200,VolumeType=gp3}' \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=kaapana-poc-server}]'
```

6. **Allocate Elastic IP (Optional but Recommended)**
   
   An Elastic IP ensures your instance keeps the same IP address even after stops/starts.
   
   **Console:**
   ```
   Navigate to: EC2 → Network & Security → Elastic IPs
   Click: Allocate Elastic IP address
   Select: Amazon's pool of IPv4 addresses
   Click: Allocate
   Select the allocated IP → Actions → Associate Elastic IP address
   Select your instance → Associate
   ```
   
   **CLI:**
   ```bash
   # Allocate Elastic IP
   ALLOCATION_ID=$(aws ec2 allocate-address --domain vpc --query 'AllocationId' --output text)
   
   # Get instance ID
   INSTANCE_ID=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=kaapana-poc-server" --query 'Reservations[0].Instances[0].InstanceId' --output text)
   
   # Associate Elastic IP
   aws ec2 associate-address --instance-id $INSTANCE_ID --allocation-id $ALLOCATION_ID
   ```

7. **Connect to Instance**
   
   ```bash
   # Set permissions on key file
   chmod 400 kaapana-poc-key.pem
   
   # SSH to instance (replace with your public IP)
   ssh -i kaapana-poc-key.pem ubuntu@<PUBLIC_IP>
   ```

**Success Criteria:**
- EC2 instance running and accessible via SSH
- Security group properly configured
- Adequate resources allocated (8+ vCPU, 64+ GB RAM, 200+ GB storage)
- Network connectivity confirmed

#### Step 2: System Configuration

**Connect to your EC2 instance:**
```bash
ssh -i kaapana-poc-key.pem ubuntu@<PUBLIC_IP>
```

**Update system packages:**
```bash
# Update package list
sudo apt update

# Upgrade all packages
sudo apt upgrade -y

# Install essential tools
sudo apt install -y nano curl git wget htop net-tools
```

**Configure timezone and locale:**
```bash
# Set timezone (example: US Eastern)
sudo timedatectl set-timezone America/New_York

# Or use interactive selector
sudo dpkg-reconfigure tzdata

# Verify timezone
timedatectl

# Configure locale (if needed)
sudo locale-gen en_US.UTF-8
sudo update-locale LANG=en_US.UTF-8
```

**Set hostname:**
```bash
# Set hostname
sudo hostnamectl set-hostname kaapana-poc

# Update /etc/hosts
sudo nano /etc/hosts
# Add line: 127.0.0.1 kaapana-poc

# Verify
hostnamectl
```

**Create storage directory structure:**
```bash
# Create kaapana user (if not exists)
sudo useradd -m -s /bin/bash kaapana || true

# Create directory structure
sudo mkdir -p /home/kaapana/fast_data
sudo mkdir -p /home/kaapana/slow_data

# Set permissions
sudo chown -R kaapana:kaapana /home/kaapana
sudo chmod -R 755 /home/kaapana

# Verify
ls -la /home/kaapana/
```

**Optional: Add additional EBS volumes for separate fast/slow storage**

If you want dedicated volumes for fast and slow data:

```bash
# On AWS Console:
# 1. Create new EBS volume (EC2 → Volumes → Create Volume)
#    - For slow data (DICOM storage): 500GB gp3 or st1 (throughput optimized HDD)
#    - Ensure it's in same AZ as your instance
# 2. Attach volume to instance (Actions → Attach Volume)

# List available disks
lsblk

# Format new volume (example: /dev/nvme1n1)
sudo mkfs.ext4 /dev/nvme1n1

# Create mount point
sudo mkdir -p /mnt/slow_data

# Mount volume
sudo mount /dev/nvme1n1 /mnt/slow_data

# Get UUID for permanent mounting
sudo blkid /dev/nvme1n1

# Add to /etc/fstab for automatic mounting
echo "UUID=<your-uuid> /mnt/slow_data ext4 defaults,nofail 0 2" | sudo tee -a /etc/fstab

# Update slow_data symlink
sudo rm -rf /home/kaapana/slow_data
sudo ln -s /mnt/slow_data /home/kaapana/slow_data
sudo chown -R kaapana:kaapana /mnt/slow_data
```

**Verify system configuration:**
```bash
# Check disk space
df -h

# Check memory
free -h

# Check CPU
lscpu

# Check network
ip addr show
```

**Success Criteria:**
- System fully updated
- Storage directories created and accessible
- Hostname set correctly
- Adequate disk space available (200GB+ free)

### 1.4 Documentation Review

#### Required Reading
- [ ] Kaapana official documentation: https://kaapana.readthedocs.io/en/latest/
- [ ] Installation guide sections
- [ ] User guide overview
- [ ] Review repository structure in `public/kaapana`
- [ ] Study example workflows in `templates_and_examples/examples/`

#### Community Engagement
- [ ] Join Kaapana Slack workspace
- [ ] Introduce yourself and project goals
- [ ] Request container registry credentials or pre-built tarball

**Success Criteria:**
- Understanding of Kaapana architecture
- Familiarity with key components (dcm4chee, Airflow, OpenSearch, MinIO)
- Access to community support channels
- Container registry credentials obtained

### 1.5 Obtain Pre-built Containers

#### Option A: Container Registry Access (Recommended)
- [ ] Contact DKFZ Kaapana team via Slack or email
- [ ] Receive registry URL, username, and password
- [ ] Test registry access from deployment server

#### Option B: Pre-built Tarball
- [ ] Request offline installation tarball (~80GB)
- [ ] Transfer tarball to deployment server
- [ ] Verify checksum/integrity

**Success Criteria:**
- Container registry credentials validated OR
- Pre-built tarball received and verified

---

## Phase 2: Base Platform Installation

**Objective:** Install Kaapana base platform and core services.

**Duration:** 1-2 days

### 2.1 Server Installation Script

#### Step 1: Prepare Installation Script

**Clone Kaapana repository:**
```bash
# Navigate to home directory
cd ~

# Install git if not already installed
sudo apt install -y git

# Clone Kaapana repository
git clone -b master https://github.com/kaapana/kaapana.git

# Navigate to repository
cd kaapana

# Check current directory structure
ls -la

# Navigate to server installation directory
cd server-installation

# List contents
ls -la
```

**Review installation script:**
```bash
# View the installation script
cat server_installation.sh | less

# Or use nano to view
nano server_installation.sh

# Key parameters to understand:
# - Online installation (default)
# - GPU support detection
# - MicroK8s installation
# - Required packages
```

**Make script executable:**
```bash
# Add execute permissions
chmod +x server_installation.sh

# Verify permissions
ls -l server_installation.sh
```

**Key Configuration:**
- Installation mode: Online (with internet access)
- GPU support: Will be auto-detected (r5 instances don't have GPU)
- Proxy settings: Not required for AWS instances with internet access

#### Step 2: Install Dependencies

**Execute server installation script:**
```bash
# Ensure you're in the server-installation directory
cd ~/kaapana/server-installation

# Run the installation script with sudo
sudo ./server_installation.sh

# The script will:
# 1. Check system requirements
# 2. Install snap and snapd
# 3. Install Docker
# 4. Install MicroK8s
# 5. Configure MicroK8s addons
# 6. Set up networking
# 7. Configure GPU support (if available)
# 8. Add current user to required groups

# Monitor the installation progress
# The script will show progress messages
# Installation takes approximately 10-20 minutes
```

**Expected output during installation:**
```
Installing prerequisites...
Installing Docker...
Installing MicroK8s...
Configuring MicroK8s addons...
Setting up storage...
Configuring networking...
Installation completed successfully!
Please reboot the system for changes to take effect.
```

**Verify installation before reboot:**
```bash
# Check if snap is installed
snap version

# Check if Docker is installed
docker --version

# Check if MicroK8s is installed
snap list | grep microk8s

# Check user groups (should include docker and microk8s)
groups $USER
```

**Reboot system:**
```bash
# Reboot the system
sudo reboot

# Wait for system to reboot (approximately 2-3 minutes)
# SSH connection will be disconnected
```

**Reconnect after reboot:**
```bash
# Wait 2-3 minutes, then reconnect via SSH
ssh -i kaapana-poc-key.pem ubuntu@<PUBLIC_IP>

# Check system uptime
uptime
```

**Components Installed:**
- MicroK8s (Kubernetes distribution)
- Container runtime (containerd)
- Network plugins (Calico or Flannel)
- Storage support (hostpath-storage)
- Docker (for container management)
- Snap (package manager)

**Success Criteria:**
- Installation script completes without errors
- System reboots successfully
- MicroK8s running and accessible
- All required dependencies installed
- No error messages in installation log

#### Step 3: Verify Kubernetes Environment

**Check MicroK8s status:**
```bash
# Check MicroK8s status
microk8s status --wait-ready

# Expected output shows:
# microk8s is running
# high-availability: no
# List of enabled addons
```

**Verify node readiness:**
```bash
# Check cluster info
microk8s kubectl cluster-info

# Get node status
microk8s kubectl get nodes

# Expected output:
# NAME          STATUS   ROLES    AGE   VERSION
# kaapana-poc   Ready    <none>   5m    v1.xx.x

# Get detailed node information
microk8s kubectl describe node
```

**Test kubectl commands:**
```bash
# List all namespaces
microk8s kubectl get namespaces

# List all pods (should be mostly empty at this point)
microk8s kubectl get pods --all-namespaces

# Check system pods
microk8s kubectl get pods -n kube-system

# Expected system pods:
# - calico-node
# - calico-kube-controllers
# - coredns
# - hostpath-provisioner
```

**Confirm storage classes available:**
```bash
# List storage classes
microk8s kubectl get storageclass

# Expected output:
# NAME                          PROVISIONER
# microk8s-hostpath (default)   microk8s.io/hostpath

# Get detailed storage class info
microk8s kubectl describe storageclass microk8s-hostpath
```

**Verify MicroK8s addons:**
```bash
# List enabled addons
microk8s status

# Should show enabled addons:
# dns: enabled
# ha-cluster: disabled
# helm: enabled (or will be enabled)
# hostpath-storage: enabled
# storage: enabled

# Enable Helm if not already enabled
microk8s enable helm3

# Enable DNS if not already enabled
microk8s enable dns
```

**Create kubectl alias (optional but recommended):**
```bash
# Add alias to bashrc
echo "alias kubectl='microk8s kubectl'" >> ~/.bashrc
source ~/.bashrc

# Now you can use 'kubectl' instead of 'microk8s kubectl'
kubectl get nodes
```

**Check system resources:**
```bash
# Check node resources
microk8s kubectl top node

# If metrics not available yet, that's normal
# Metrics server might not be installed yet

# Check resource capacity
microk8s kubectl describe node | grep -A 5 "Capacity:"
microk8s kubectl describe node | grep -A 5 "Allocatable:"
```

**Expected Observations:**
- MicroK8s status shows "running"
- Single node in "Ready" state
- DNS addon enabled
- Hostpath storage provisioner available
- System pods running in kube-system namespace
- Kubectl commands execute successfully

### 2.2 Platform Deployment

#### Step 1: Prepare Deployment Script

**Navigate to Kaapana repository:**
```bash
cd ~/kaapana
```

**Option A: Using Pre-built Containers (Recommended)**

If you received container registry credentials from DKFZ:

```bash
# Navigate to platforms directory
cd ~/kaapana/platforms

# Copy the deployment template
cp deploy_platform_template.sh deploy_platform.sh

# Make executable
chmod +x deploy_platform.sh

# Edit the deployment script
nano deploy_platform.sh
```

**Edit the following variables in `deploy_platform.sh`:**

```bash
# Container registry configuration
CONTAINER_REGISTRY_URL="registry.dkfz.de"  # Replace with actual registry URL
CONTAINER_REGISTRY_USERNAME="your-username"  # Replace with your username
CONTAINER_REGISTRY_PASSWORD="your-password"  # Replace with your password

# Server configuration
SERVER_DOMAIN="<YOUR_PUBLIC_IP>"  # Replace with your EC2 public IP or domain
GPU_SUPPORT="false"  # Set to false for r5 instances (no GPU)

# Storage configuration
FAST_DATA_DIR="/home/kaapana/fast_data"
SLOW_DATA_DIR="/home/kaapana/slow_data"

# Deployment mode
DEV_MODE="true"  # Set to true for POC/development

# Optional: HTTP/HTTPS configuration
HTTP_PORT="80"
HTTPS_PORT="443"

# Optional: Helm chart version (leave default unless specified)
CHART_VERSION="latest"
```

**⚠️ Cannot Access Slack for Registry Credentials?**

If you cannot get registry credentials through Slack, you have alternatives:

1. **Contact DKFZ Team Directly:**
   ```
   Email: kaapana@dkfz-heidelberg.de
   Subject: Request Container Registry Access
   Mention: Cannot access Slack, need registry credentials or pre-built tarball
   Expected response: 1-3 business days
   ```

2. **Build Kaapana from Source (Fully Supported):**
   - See detailed guide: `kaapana-build-from-source.md`
   - Time: ~1.5-2 hours (includes ~1 hour build time)
   - Requirements: Ubuntu 22.04/24.04 x64 with 200GB+ disk space
   - Fully official approach with support available

**Option B: If You Have Pre-built Tarball**

If you received a pre-built tarball from DKFZ or built one locally:

```bash
# Transfer tarball to EC2 instance (from your local machine)
scp -i kaapana-poc-key.pem kaapana-offline-installer.tar.gz ubuntu@<PUBLIC_IP>:~

# On EC2 instance, extract tarball
cd ~
tar -xzf kaapana-offline-installer.tar.gz

# Navigate to extracted directory
cd kaapana-offline-installer

# The directory should contain deploy_platform.sh
ls -la deploy_platform.sh

# Make executable
chmod +x deploy_platform.sh

# Edit configuration
nano deploy_platform.sh

# Edit the same variables as Option A above
```

**Verify configuration:**
```bash
# Display configuration (without showing password)
cat deploy_platform.sh | grep -v PASSWORD | grep "="

# Check that all required variables are set
grep "CONTAINER_REGISTRY_URL" deploy_platform.sh
grep "SERVER_DOMAIN" deploy_platform.sh
grep "FAST_DATA_DIR" deploy_platform.sh
```

**Key Configuration Parameters:**
- `CONTAINER_REGISTRY_URL`: Registry URL from DKFZ (e.g., registry.dkfz.de)
- `CONTAINER_REGISTRY_USERNAME`: Registry username
- `CONTAINER_REGISTRY_PASSWORD`: Registry password
- `SERVER_DOMAIN`: Your EC2 public IP address or domain name
- `GPU_SUPPORT`: `false` (r5 instances don't have GPU)
- `FAST_DATA_DIR`: `/home/kaapana/fast_data`
- `SLOW_DATA_DIR`: `/home/kaapana/slow_data`
- `DEV_MODE`: `true` (for POC demo with simplified authentication)

#### Step 2: Execute Deployment

**Run deployment script:**
```bash
# Ensure you're in the correct directory
# For Option A (repository):
cd ~/kaapana/platforms

# For Option B (tarball):
cd ~/kaapana-offline-installer

# Run deployment script with sudo
sudo ./deploy_platform.sh

# The script will prompt you for configuration
# If you edited the script with correct values, it will use those
# Otherwise, provide values when prompted
```

**Interactive prompts (if not pre-configured):**
```
Enter server domain/IP: <YOUR_PUBLIC_IP>
Enable GPU support? (yes/no): no
Container registry URL: registry.dkfz.de
Container registry username: your-username
Container registry password: [hidden]
Fast data directory [/home/kaapana/fast_data]:
Slow data directory [/home/kaapana/slow_data]:
Enable dev mode? (yes/no): yes
```

**Monitor deployment progress:**

The script will:
1. Create Kubernetes namespaces
2. Create registry credentials secret
3. Install Helm charts
4. Deploy platform services
5. Deploy core modules

```bash
# Expected output during deployment:
Creating namespace: kaapana
Creating registry secret...
Installing Kaapana admin chart...
Installing platform components...
Deploying core services...
Waiting for pods to start...

# This process takes approximately 5-15 minutes
# depending on internet speed and system resources
```

**In a separate terminal (optional), monitor the deployment:**
```bash
# Open new SSH session
ssh -i kaapana-poc-key.pem ubuntu@<PUBLIC_IP>

# Watch pod creation in real-time
watch microk8s kubectl get pods --all-namespaces

# Or use kubectl if you created the alias
watch kubectl get pods --all-namespaces

# Watch helm releases
watch microk8s helm list --all-namespaces
```

**Wait for deployment completion:**
```bash
# The script will show completion message
Deployment completed successfully!
Kaapana platform is now available at: https://<YOUR_IP>
Default credentials:
  Username: kaapana
  Password: kaapana

# If the script hangs, check pods in another terminal
# Look for pods in CrashLoopBackOff or Error state
```

**Success Criteria:**
- Deployment script completes successfully
- Success message displayed
- Helm releases installed (check with: `microk8s helm list --all-namespaces`)
- No error messages in deployment logs
- Script provides access URL and credentials

#### Step 3: Monitor Pod Startup

**Watch pod status:**
```bash
# Watch all pods in real-time
watch microk8s kubectl get pods --all-namespaces

# Or with kubectl alias
watch kubectl get pods -A

# Press Ctrl+C to exit watch when all pods are ready

# Expected pod states:
# - Running: Pod is operational
# - Completed: Job/Init container finished successfully
# - ContainerCreating: Pod is starting (normal during initialization)
# - Pending: Waiting for resources or image pull
```

**Check pod status in detail:**
```bash
# Get all pods with more details
microk8s kubectl get pods --all-namespaces -o wide

# Count pods by status
microk8s kubectl get pods --all-namespaces --no-headers | awk '{print $4}' | sort | uniq -c

# Expected output example:
#   35 Running
#    5 Completed
#    2 ContainerCreating
```

**Verify all pods are ready:**
```bash
# List pods that are not running
microk8s kubectl get pods --all-namespaces --field-selector=status.phase!=Running,status.phase!=Succeeded

# If output is empty (except header), all pods are healthy

# Check for pods in error states
microk8s kubectl get pods --all-namespaces | grep -E 'CrashLoopBackOff|Error|ImagePullBackOff'

# This should return nothing if all is well
```

**Check specific namespaces:**
```bash
# List all namespaces
microk8s kubectl get namespaces

# Check pods in kaapana namespace
microk8s kubectl get pods -n kaapana

# Check pods in kube-system namespace
microk8s kubectl get pods -n kube-system

# Check pods in other relevant namespaces
microk8s kubectl get pods -n kaapana-admin
microk8s kubectl get pods -n monitoring
microk8s kubectl get pods -n store
```

**Review pod logs if issues occur:**
```bash
# Get logs from a specific pod
microk8s kubectl logs <pod-name> -n <namespace>

# Example: Check backend logs
microk8s kubectl logs -n kaapana -l app=kaapana-backend

# Get logs from previous crashed container
microk8s kubectl logs <pod-name> -n <namespace> --previous

# Describe pod to see events and issues
microk8s kubectl describe pod <pod-name> -n <namespace>

# Common issues to check in describe output:
# - Image pull errors (check registry credentials)
# - Resource constraints (insufficient memory/CPU)
# - Volume mount issues
# - Network connectivity problems
```

**Check pod readiness:**
```bash
# List pods with readiness status
microk8s kubectl get pods --all-namespaces -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name,READY:.status.containerStatuses[*].ready,STATUS:.status.phase

# Wait for all pods to be ready
microk8s kubectl wait --for=condition=ready pod --all --all-namespaces --timeout=600s
```

**Verify critical services:**
```bash
# Check deployment status
microk8s kubectl get deployments --all-namespaces

# Check statefulsets (databases, etc.)
microk8s kubectl get statefulsets --all-namespaces

# Check services
microk8s kubectl get services --all-namespaces
```

**Expected Pod Count:** 30-50 pods depending on configuration

**Key Pods to Verify:**
- kaapana-backend (main API)
- dcm4chee-arc (PACS)
- postgres (database)
- opensearch (search engine)
- minio (object storage)
- airflow-webserver (workflow UI)
- airflow-scheduler (workflow scheduler)
- keycloak (authentication)
- traefik or nginx-ingress (ingress controller)

**Success Criteria:**
- All critical pods in "Running" state
- No pods in "CrashLoopBackOff" or "Error" state
- Pod readiness checks passing
- No persistent errors in pod logs
- Platform initialization complete (typically 5-10 minutes after deployment start)

### 2.3 Initial Access Verification

#### Step 1: Access Web Interface

**Get your access URL:**
```bash
# Your Kaapana URL is:
https://<YOUR_EC2_PUBLIC_IP>

# Or if you set up a domain:
https://<YOUR_DOMAIN>

# Example:
# https://54.123.45.67
```

**Verify ingress is working:**
```bash
# Check ingress controller
microk8s kubectl get pods -n kube-system | grep -i ingress

# Check ingress rules
microk8s kubectl get ingress --all-namespaces

# Test connectivity from server
curl -k https://localhost
# Should return HTML content

# Test from external (your local machine)
curl -k https://<YOUR_EC2_PUBLIC_IP>
# Should return HTML content
```

**Access from web browser:**

1. Open your web browser (Chrome, Firefox, Safari)

2. Navigate to:
   ```
   https://<YOUR_EC2_PUBLIC_IP>
   ```

3. Accept self-signed certificate warning:
   - **Chrome:** Click "Advanced" → "Proceed to <IP> (unsafe)"
   - **Firefox:** Click "Advanced" → "Accept the Risk and Continue"
   - **Safari:** Click "Show Details" → "visit this website"
   
   Note: This is normal for POC without proper SSL certificate

4. Verify Kaapana login page loads:
   - You should see Kaapana logo
   - Login form with username and password fields
   - "Sign In" button

**Troubleshooting if page doesn't load:**

```bash
# Check if ports are accessible
sudo netstat -tlnp | grep -E ':80|:443'

# Check ingress controller logs
microk8s kubectl logs -n kube-system -l app.kubernetes.io/name=ingress-nginx

# Check security group allows traffic
# On AWS Console: EC2 → Security Groups → kaapana-poc-sg
# Verify inbound rules allow ports 80 and 443 from 0.0.0.0/0

# Test port connectivity from local machine
telnet <YOUR_EC2_PUBLIC_IP> 443
# Should connect successfully

# Or use curl with verbose output
curl -vk https://<YOUR_EC2_PUBLIC_IP>
```

**Default Credentials (Dev Mode):**
- Username: `kaapana`
- Password: `kaapana`

**Expected Login Page:**
- Clean interface with Kaapana branding
- Username and password input fields
- Language selector (optional)
- Sign In button

#### Step 2: Login to Platform

**Login procedure:**

1. Enter credentials:
   ```
   Username: kaapana
   Password: kaapana
   ```

2. Click "Sign In" button

3. Wait for authentication (2-5 seconds)

4. You should be redirected to the main dashboard

**Verify dashboard loads:**

After successful login, you should see:

- **Top Navigation Bar:**
  - Kaapana logo (top left)
  - Navigation menu items
  - User profile icon (top right)
  - Notifications icon (if applicable)

- **Main Dashboard:**
  - Welcome message or dashboard widgets
  - Statistics or system overview
  - Quick action buttons
  - Recently accessed items

- **Sidebar Menu (typical sections):**
  - Datasets / Data Browser
  - Workflows
  - Processing / Jobs
  - Administration
  - Settings

**Check main navigation:**

Click through the main menu items to verify accessibility:

```
1. Datasets/Data Browser
   - Should show empty dataset list initially
   - Upload button should be visible

2. Workflows
   - Should redirect to Airflow interface
   - May require additional authentication or SSO

3. Jobs/Processing
   - Should show job history (empty initially)
   
4. Administration (if visible)
   - User management
   - System settings
   - Module configuration

5. User Profile (top right icon)
   - Account information
   - Logout option
   - Settings
```

**Verify basic UI functionality:**

Test the following:

```bash
# Open browser developer console (F12)
# Check for errors in Console tab
# Should not see any red error messages

# Common JavaScript errors to watch for:
# - API connection errors (check network tab)
# - Authentication token issues
# - Resource loading failures
```

**Test navigation:**
- Click between different menu items
- Ensure pages load without errors
- Verify no 404 or 500 errors
- Check that navigation is responsive

**Check user profile:**
- Click on user profile icon (top right)
- Should show:
  - Username: kaapana
  - Email (if configured)
  - Role/permissions
  - Logout button

**Verify backend connectivity:**
```bash
# From server, check backend logs
microk8s kubectl logs -n kaapana -l app=kaapana-backend --tail=50

# Should see authentication logs:
# "User kaapana logged in successfully"
# or similar authentication messages

# Check for errors
microk8s kubectl logs -n kaapana -l app=kaapana-backend | grep -i error
```

**Expected Observations:**
- Dashboard displays without errors
- Navigation menu accessible and responsive
- User profile shows username "kaapana"
- No JavaScript console errors
- No 404 or 500 HTTP errors
- Pages load within 2-3 seconds
- All UI elements render correctly

#### Step 3: Verify Keycloak Authentication

**Access Keycloak admin console:**

1. Navigate to Keycloak:
   ```
   https://<YOUR_EC2_PUBLIC_IP>/auth
   
   Or:
   https://<YOUR_EC2_PUBLIC_IP>/auth/admin
   ```

2. You should see Keycloak admin login page

**Login with Keycloak admin credentials:**

Default Keycloak credentials (Dev Mode):
```
Username: admin
Password: Kaapana2020
```

If these don't work, check deployment logs:
```bash
# Check Keycloak pod
microk8s kubectl get pods -n kaapana | grep keycloak

# Get Keycloak logs to find admin password
microk8s kubectl logs -n kaapana <keycloak-pod-name> | grep -i "admin password"

# Or check Keycloak configuration
microk8s kubectl get secret -n kaapana keycloak-secret -o jsonpath='{.data.admin-password}' | base64 -d
echo
```

**Verify user realm:**

After logging into Keycloak:

1. Select the realm (dropdown top left):
   - Should show "kaapana" realm or "master" realm
   - Switch to "kaapana" realm if available

2. Navigate to "Users" (left sidebar):
   - Click "Users"
   - Click "View all users" button

3. Verify user accounts:
   - Should see "kaapana" user listed
   - May see other default users

**Check user details:**
```
1. Click on "kaapana" user
2. Verify details:
   - Username: kaapana
   - Email: (may be set or empty)
   - Email Verified: (may be true/false)
   - Enabled: Yes

3. Check "Role Mappings" tab:
   - Should have appropriate roles assigned
   
4. Check "Credentials" tab:
   - Password is set
   - Temporary: No
```

**Verify realm settings:**

1. Navigate to "Realm Settings" (left sidebar)
2. Check key settings:
   - Display name: Kaapana (or similar)
   - Login settings configured
   - Tokens configured
   - Sessions configured

**Test authentication flow:**

```bash
# From server, test Keycloak API
curl -k https://localhost/auth/realms/kaapana

# Should return realm configuration JSON

# Test token endpoint
curl -k -X POST https://localhost/auth/realms/kaapana/protocol/openid-connect/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=kaapana" \
  -d "password=kaapana" \
  -d "grant_type=password" \
  -d "client_id=kaapana-client"

# Should return access token if authentication works
```

**Verify Keycloak integration with Kaapana:**
```bash
# Check Keycloak pod status
microk8s kubectl get pods -n kaapana -l app=keycloak

# Check Keycloak service
microk8s kubectl get svc -n kaapana -l app=keycloak

# Check Keycloak logs for authentication events
microk8s kubectl logs -n kaapana -l app=keycloak --tail=100 | grep -i "login\|auth"
```

**Success Criteria:**
- Web interface accessible at https://<YOUR_IP>
- Login successful with default credentials (kaapana/kaapana)
- Dashboard functional and responsive
- Keycloak admin console accessible
- Keycloak realm configured with kaapana user
- Authentication flow working correctly
- No authentication errors in logs

---

## Phase 3: Core Modules Configuration

**Objective:** Enable and validate key Kaapana modules.

**Duration:** 3-4 days

### 3.1 Core Services Overview

**Focus Modules for POC:**
1. **dcm4chee** - DICOM storage and PACS server
2. **OpenSearch** - DICOM metadata indexing and search
3. **MinIO** - Object storage backend
4. **Airflow** - Workflow orchestration
5. **Keycloak** - User authentication
6. **OHIF Viewer** - Medical image visualization

### 3.2 DICOM Storage (dcm4chee)

#### Step 1: Verify dcm4chee Service
- [ ] Check dcm4chee pods running
- [ ] Verify PACS service accessible
- [ ] Confirm DICOM port 11112 listening
- [ ] Review dcm4chee configuration

**Expected Services:**
- dcm4chee-arc (PACS application)
- dcm4chee-db (PostgreSQL database)

**Success Criteria:**
- dcm4chee pods in "Running" state
- DICOM AE Title configured
- Port 11112 accessible from network

#### Step 2: Configure DICOM Storage Parameters
- [ ] Review storage capacity allocation
- [ ] Configure DICOM retention policies (if needed)
- [ ] Set up AE Title and port configuration
- [ ] Verify database connectivity

**Key Configuration:**
- AE Title: Default or custom
- Port: 11112 (DIMSE)
- Storage location: Configured in deployment
- Database: PostgreSQL

**Success Criteria:**
- DICOM storage configured correctly
- Database connection established
- Storage directories writable

### 3.3 Object Storage (MinIO)

#### Step 1: Access MinIO Console
- [ ] Navigate to MinIO web interface
- [ ] Login with MinIO credentials
- [ ] Verify buckets created
- [ ] Check storage capacity

**Default Credentials (Dev Mode):**
- Username: `kaapanaminio`
- Password: `Kaapana2020`

#### Step 2: Verify Storage Backend
- [ ] Confirm MinIO pods running
- [ ] Check bucket structure
- [ ] Verify read/write permissions
- [ ] Test file upload (small test file)

**Expected Buckets:**
- Workflow data buckets
- Model storage buckets
- Temporary processing buckets

**Success Criteria:**
- MinIO console accessible
- Buckets created and accessible
- Storage operations functional

### 3.4 Workflow Orchestration (Airflow)

#### Step 1: Access Airflow Web UI
- [ ] Navigate to Airflow interface (typically `/flow`)
- [ ] Login with Airflow credentials
- [ ] Verify DAGs (Directed Acyclic Graphs) loaded
- [ ] Check worker pods status

**Default Access:**
- Usually integrated with Kaapana authentication
- Or separate Airflow credentials if configured

#### Step 2: Verify Workflow Components
- [ ] Check available DAGs list
- [ ] Verify executor configuration (Kubernetes executor)
- [ ] Confirm connections configured
- [ ] Review example workflows

**Expected DAGs:**
- DICOM import workflows
- Segmentation pipelines (nnU-Net)
- Data export workflows
- Preprocessing workflows

#### Step 3: Test Simple Workflow
- [ ] Trigger a test/example DAG
- [ ] Monitor task execution
- [ ] Verify worker pods spawn correctly
- [ ] Check task logs for completion

**Success Criteria:**
- Airflow UI accessible
- DAGs loaded and visible
- Test workflow executes successfully
- Worker pods scale properly

### 3.5 Search and Indexing (OpenSearch)

#### Step 1: Verify OpenSearch Service
- [ ] Check OpenSearch pods running
- [ ] Verify OpenSearch Dashboards accessible
- [ ] Confirm indices created
- [ ] Test search functionality

#### Step 2: Validate DICOM Metadata Indexing
- [ ] Check DICOM metadata index
- [ ] Verify index mapping
- [ ] Test search queries
- [ ] Review index statistics

**Success Criteria:**
- OpenSearch service operational
- Indices created and accessible
- Search functionality working
- Dashboard loads successfully

### 3.6 Module Integration Testing

#### Step 1: Verify Inter-Service Communication
- [ ] Test Airflow → MinIO connectivity
- [ ] Verify Airflow → dcm4chee connectivity
- [ ] Check OpenSearch indexing from dcm4chee
- [ ] Confirm Keycloak authentication across services

#### Step 2: Review Service Mesh
- [ ] Check internal DNS resolution
- [ ] Verify service discovery working
- [ ] Test network policies
- [ ] Review pod-to-pod communication

**Success Criteria:**
- All services can communicate
- No network connectivity issues
- Service discovery functional
- Authentication propagates correctly

---

## Phase 4: Verification, Documentation & Demo

**Objective:** Validate system functionality and prepare demo.

**Duration:** 2-3 days

### 4.1 Data Upload and Processing

#### Step 1: Obtain Sample DICOM Data

**Download public DICOM datasets:**

**Option 1: The Cancer Imaging Archive (TCIA)**

From your local machine or EC2 instance:

```bash
# On your local machine or EC2:
# Install wget if not available
sudo apt install -y wget unzip

# Create directory for DICOM data
mkdir -p ~/dicom-samples
cd ~/dicom-samples

# Download sample datasets from TCIA
# Example: Low-Dose CT Image and Projection Data (LDCT-and-Projection-data)
# Visit: https://www.cancerimagingarchive.net/collection/ldct-and-projection-data/

# Or use DICOM Library samples
wget https://www.dicomlibrary.com/samples/chest-ct.zip
unzip chest-ct.zip

# Or download via TCIA's NBIA Data Retriever (GUI tool)
# Instructions at: https://wiki.cancerimagingarchive.net/display/NBIA/Downloading+TCIA+Images
```

**Option 2: DICOM Library (Quick Samples)**

```bash
# Download sample DICOM files
cd ~/dicom-samples

# Sample chest CT
wget -O sample-ct.dcm "https://www.dicomlibrary.com/dicom/samples/chest-ct.dcm"

# Sample MRI
wget -O sample-mri.dcm "https://www.dicomlibrary.com/dicom/samples/brain-mri.dcm"

# Verify files downloaded
ls -lh *.dcm
```

**Option 3: Generate Test DICOM (for basic testing)**

```bash
# Install dcmtk tools
sudo apt install -y dcmtk

# Convert a PNG/JPEG to DICOM (for testing only)
# First, get a test image
wget https://upload.wikimedia.org/wikipedia/commons/thumb/3/3f/Chest_radiograph.jpg/320px-Chest_radiograph.jpg -O test-image.jpg

# Convert to DICOM using img2dcm
img2dcm test-image.jpg test-image.dcm

# Verify DICOM file
dcmdump test-image.dcm | head -30
```

**Verify DICOM files are valid:**

```bash
# Install DICOM tools
sudo apt install -y dcmtk

# Verify DICOM file integrity
dcmdump <filename>.dcm

# Check DICOM tags
dcmdump <filename>.dcm | grep -E "PatientName|StudyDate|Modality"

# Validate DICOM structure
dcmftest <filename>.dcm
```

**Organize datasets by study/series:**

```bash
# Create organized structure
mkdir -p ~/dicom-samples/organized
cd ~/dicom-samples/organized

# Organize by patient/study/series
mkdir -p Patient001/Study001/Series001
mkdir -p Patient001/Study001/Series002

# Move files to appropriate directories
# (Do this based on your downloaded data)

# Or use dcmtk to auto-organize
dcmftest --sort-by-study ~/dicom-samples/*.dcm
```

**Transfer DICOM files to EC2 (if downloaded locally):**

```bash
# From your local machine:
scp -i kaapana-poc-key.pem -r ~/dicom-samples ubuntu@<YOUR_EC2_PUBLIC_IP>:~/

# Verify transfer
ssh -i kaapana-poc-key.pem ubuntu@<YOUR_EC2_PUBLIC_IP> "ls -lh ~/dicom-samples"
```

**Recommended Test Datasets:**
- **Small CT series:** 10-50 slices (~ 5-50 MB)
- **MRI series:** T1/T2 weighted images for segmentation testing
- **Multi-modality studies:** CT + PET for advanced workflows

**Example Public Dataset Sources:**
1. **TCIA Collections:**
   - LIDC-IDRI (Lung CT images)
   - TCGA (Various cancer imaging)
   - RIDER (Repeat imaging for testing)

2. **DICOM Library:**
   - Quick sample files for testing
   - Various modalities available

3. **Medical Segmentation Decathlon:**
   - http://medicaldecathlon.com/
   - Pre-organized for segmentation tasks

#### Step 2: Upload DICOM Data via UI

**Navigate to data upload section:**

1. Access Kaapana web interface:
   ```
   https://<YOUR_EC2_PUBLIC_IP>
   ```

2. Login with credentials:
   ```
   Username: kaapana
   Password: kaapana
   ```

3. Navigate to upload interface:
   - Look for "Datasets" or "Data Browser" in the main menu
   - Click on "Upload" button or "Import Data" option
   - Or navigate to dedicated upload page

**Select DICOM files for upload:**

**Method 1: Web UI Upload**

1. Click "Upload" or "Browse" button

2. Select DICOM files:
   - Single file selection: Click a .dcm file
   - Multiple files: Hold Ctrl/Cmd and click multiple files
   - Folder upload: Some browsers support folder selection

3. Alternatively, use drag-and-drop:
   - Drag DICOM files or folders directly into the upload area

**Method 2: If UI Upload Not Available, Use DICOM Send**

```bash
# From EC2 instance or machine with DICOM files:

# Install dcmtk if not already installed
sudo apt install -y dcmtk

# Send DICOM files to dcm4chee
dcmsend -v \
  <YOUR_EC2_PUBLIC_IP> 11112 \
  ~/dicom-samples/*.dcm

# For recursive directory send
find ~/dicom-samples -name "*.dcm" -exec dcmsend <YOUR_EC2_PUBLIC_IP> 11112 {} \;

# With specific AE Title (if required)
dcmsend -v \
  -aet KAAPANA_CLIENT \
  -aec KAAPANA \
  <YOUR_EC2_PUBLIC_IP> 11112 \
  ~/dicom-samples/*.dcm
```

**Initiate upload process:**

1. After selecting files, click "Upload" or "Start Upload" button

2. The upload process will begin:
   - Progress bar appears
   - File count shown (e.g., "Uploading 45 files...")
   - Upload speed displayed

3. Wait for upload to complete:
   - Small datasets (< 100 MB): 30 seconds - 2 minutes
   - Medium datasets (100-500 MB): 2-10 minutes
   - Large datasets (> 500 MB): 10+ minutes

**Monitor upload progress:**

```bash
# From server, monitor dcm4chee logs
microk8s kubectl logs -n kaapana -l app=dcm4chee-arc --follow

# Watch for DICOM receive messages:
# "C-STORE RQ received"
# "Study stored successfully"

# Monitor storage usage
df -h /home/kaapana/slow_data

# Check number of studies in dcm4chee
# (via dcm4chee web interface if accessible)
```

**Verify upload completion:**

UI should show:
- ✅ Green checkmark or "Upload Complete" message
- Total files uploaded count
- "Success" status
- Option to view uploaded data

**Troubleshooting upload issues:**

```bash
# If upload fails, check:

# 1. dcm4chee pod is running
microk8s kubectl get pods -n kaapana | grep dcm4chee

# 2. Check dcm4chee logs for errors
microk8s kubectl logs -n kaapana -l app=dcm4chee-arc | grep -i error

# 3. Verify storage space available
df -h

# 4. Check network connectivity to port 11112
sudo netstat -tlnp | grep 11112

# 5. Verify files are valid DICOM
dcmdump ~/dicom-samples/sample.dcm | head -20

# 6. Check security group allows port 11112
# AWS Console → EC2 → Security Groups → kaapana-poc-sg
```

**Success Criteria:**
- Files upload without errors
- Progress indicator reaches 100%
- Confirmation message displayed ("Upload Successful" or similar)
- No error messages in UI or logs
- Files appear in dataset browser

#### Step 3: Verify Data Storage

**Check data visible in Kaapana UI:**

1. Navigate to "Datasets" or "Data Browser" in Kaapana UI

2. You should see uploaded studies listed:
   ```
   - Study date
   - Patient ID/Name
   - Modality (CT, MRI, etc.)
   - Number of series
   - Number of instances (images)
   ```

3. Verify study count matches uploaded data

4. Click on a study to view details:
   - Series list
   - Image count per series
   - Study description
   - Patient demographics

**Verify DICOM metadata indexed:**

**Via Kaapana UI:**
- Use search functionality to find studies
- Try searching by:
  - Patient name
  - Study date
  - Modality
  - Study description

**Via OpenSearch (if accessible):**

```bash
# Access OpenSearch from server
microk8s kubectl port-forward -n kaapana svc/opensearch 9200:9200 &

# Query DICOM index
curl -k -u admin:admin https://localhost:9200/_cat/indices?v | grep dicom

# Search for studies
curl -k -u admin:admin -X GET "https://localhost:9200/dicom-*/_search?pretty" -H 'Content-Type: application/json' -d'
{
  "query": {
    "match_all": {}
  },
  "size": 10
}
'

# Count documents in DICOM index
curl -k -u admin:admin -X GET "https://localhost:9200/dicom-*/_count?pretty"
```

**Confirm images stored in dcm4chee:**

**Via dcm4chee Web UI (if available):**

1. Access dcm4chee interface:
   ```
   https://<YOUR_EC2_PUBLIC_IP>/dcm4chee-arc
   
   Or via port-forward:
   microk8s kubectl port-forward -n kaapana svc/dcm4chee-arc 8080:8080 &
   http://localhost:8080/dcm4chee-arc/ui2
   ```

2. Login (if required):
   ```
   Username: admin (or as configured)
   Password: admin (or as configured)
   ```

3. Search for studies:
   - Enter search criteria
   - View study list
   - Verify image count

**Via command line:**

```bash
# Check dcm4chee storage directory
sudo ls -lh /home/kaapana/slow_data/dcm4chee/

# Count DICOM files stored
sudo find /home/kaapana/slow_data/dcm4chee/ -name "*.dcm" | wc -l

# Check PostgreSQL database (dcm4chee metadata)
microk8s kubectl exec -n kaapana <postgres-pod-name> -- psql -U kaapana -d kaapana -c "SELECT COUNT(*) FROM study;"

# View study list
microk8s kubectl exec -n kaapana <postgres-pod-name> -- psql -U kaapana -d kaapana -c "SELECT study_iuid, study_date FROM study LIMIT 10;"
```

**Test image retrieval and display:**

1. In Kaapana UI, click on a study

2. Click on a series to view images

3. Verify thumbnails load:
   - Should see image previews
   - Thumbnails should show actual image content
   - No broken image icons

**Use OHIF Viewer to visualize images:**

1. From study or series view, click "View in OHIF" or "Open Viewer"

2. OHIF Viewer should open:
   ```
   - Image canvas displays DICOM images
   - Scrollable series (mousewheel or slider)
   - Window/Level adjustment tools
   - Measurement tools
   - Multiple series layout (if multi-series study)
   ```

3. Test OHIF functionality:
   ```bash
   # Scroll through images
   # Use window/level tool (right-click drag or preset buttons)
   # Zoom in/out (mousewheel or zoom tool)
   # Pan image (middle-click drag or pan tool)
   # Measure distances (measurement tool)
   # View different series (series selector)
   ```

4. Verify image quality:
   - Images display correctly
   - No corruption or artifacts
   - Proper orientation
   - Correct window/level presets

**Alternative: Access OHIF directly:**

```bash
# If OHIF is available at a separate endpoint:
https://<YOUR_EC2_PUBLIC_IP>/ohif

# Or via port-forward
microk8s kubectl port-forward -n kaapana svc/ohif-viewer 3000:3000 &
# Then access: http://localhost:3000
```

**Verify metadata in OpenSearch Dashboards:**

```bash
# Port-forward OpenSearch Dashboards
microk8s kubectl port-forward -n kaapana svc/opensearch-dashboards 5601:5601 &

# Access via browser:
http://localhost:5601

# Or if accessible externally:
https://<YOUR_EC2_PUBLIC_IP>/opensearch-dashboards

# Login and check DICOM indices
```

**Expected Observations:**
- Studies appear in dataset browser immediately after upload
- Metadata searchable in OpenSearch (search functionality works)
- Images stored in dcm4chee (files visible in storage directory)
- Images viewable in OHIF viewer without errors
- Thumbnails generated correctly and display image content
- Window/level adjustments work in OHIF
- All DICOM metadata fields populated correctly

### 4.2 AI Segmentation Workflow

#### Step 1: Prepare nnU-Net Segmentation
- [ ] Locate nnU-Net segmentation DAG in Airflow
- [ ] Review DAG parameters and requirements
- [ ] Select appropriate dataset for segmentation
- [ ] Verify model availability

#### Step 2: Execute Segmentation Workflow
- [ ] Trigger nnU-Net segmentation DAG
- [ ] Select uploaded DICOM study
- [ ] Configure segmentation parameters
- [ ] Start workflow execution
- [ ] Monitor workflow progress in Airflow

**Workflow Steps to Monitor:**
- Data extraction
- Preprocessing
- Model inference
- Post-processing
- Result storage

#### Step 3: Review Segmentation Results
- [ ] Check workflow completion status
- [ ] Verify segmentation masks generated
- [ ] View results in OHIF viewer
- [ ] Validate segmentation quality
- [ ] Export results if needed

**Success Criteria:**
- Workflow completes without errors
- Segmentation masks generated
- Results visualized correctly
- Performance acceptable (processing time)

### 4.3 User Management and Collaboration

#### Step 1: Create Demo User Accounts
- [ ] Access Keycloak admin console
- [ ] Create test user accounts:
  - User type: Researcher/Developer
  - User type: Administrator
  - User type: Read-only viewer
- [ ] Assign appropriate roles and permissions
- [ ] Test user login with new accounts

#### Step 2: Test Access Control
- [ ] Login as different user types
- [ ] Verify role-based access control (RBAC)
- [ ] Test data visibility per user
- [ ] Confirm workflow execution permissions
- [ ] Validate admin vs. user capabilities

**Success Criteria:**
- Multiple user accounts created
- Roles enforced correctly
- Access control functional
- User collaboration features working

### 4.4 System Persistence Testing

#### Step 1: Data Persistence Verification
- [ ] Note current system state (uploaded data, users, workflows)
- [ ] Restart Kaapana platform (undeploy/redeploy) or reboot server
- [ ] Wait for system to fully restart
- [ ] Verify data still present after restart

**Items to Verify:**
- Uploaded DICOM studies
- User accounts
- Workflow history
- Segmentation results
- Configuration settings

#### Step 2: Database Persistence
- [ ] Check PostgreSQL data persistence
- [ ] Verify OpenSearch indices intact
- [ ] Confirm MinIO object storage retained
- [ ] Validate Keycloak realm configuration

**Success Criteria:**
- All data persists across restarts
- No data loss observed
- System recovers fully
- Services resume normal operation

### 4.5 Performance Validation

#### Step 1: Resource Monitoring
- [ ] Monitor CPU utilization
- [ ] Check memory usage
- [ ] Review disk I/O performance
- [ ] Monitor network bandwidth
- [ ] Check pod resource allocation

**Monitoring Tools:**
- Kubernetes metrics (`kubectl top`)
- System monitoring (`htop`, `iostat`)
- Prometheus/Grafana (if enabled)

#### Step 2: Performance Benchmarks
- [ ] Measure DICOM upload speed
- [ ] Time workflow execution (nnU-Net segmentation)
- [ ] Test concurrent user access
- [ ] Evaluate search query response times

**Expected Performance (Minimum Specs):**
- DICOM upload: Dependent on network
- Segmentation: 5-15 minutes per study (CPU)
- UI responsiveness: < 2 seconds per page
- Search queries: < 1 second

**Success Criteria:**
- System performs within acceptable limits
- No resource exhaustion
- Responsive user experience

### 4.6 Documentation Deliverables

#### Step 1: Installation Documentation
Document the following:
- [ ] **Infrastructure Setup**
  - Cloud provider details
  - VM specifications
  - Network configuration
  - Storage layout

- [ ] **Installation Steps**
  - Commands executed
  - Configuration parameters used
  - Any deviations from standard process
  - Issues encountered and resolutions

- [ ] **Access Information**
  - Server URL/IP address
  - Login credentials (securely stored)
  - Service endpoints
  - Port mappings

#### Step 2: Configuration Documentation
- [ ] **Module Configuration**
  - dcm4chee settings
  - MinIO configuration
  - Airflow DAG configuration
  - OpenSearch indices

- [ ] **User Management**
  - User account details
  - Role assignments
  - Permission model

- [ ] **Integration Points**
  - Service dependencies
  - Data flow diagrams
  - API endpoints

#### Step 3: Verification Checklist
Create checklist documenting:
- [ ] All installed components
- [ ] Verification test results
- [ ] Sample data upload status
- [ ] Workflow execution results
- [ ] Performance metrics
- [ ] Known issues or limitations

#### Step 4: Demo Preparation
- [ ] **Screenshots**
  - Dashboard overview
  - DICOM data browser
  - OHIF viewer with loaded study
  - Airflow workflow execution
  - Segmentation results

- [ ] **Demo Script**
  - Login procedure
  - Data upload demonstration
  - Workflow execution walkthrough
  - Results visualization
  - User management overview

- [ ] **Video Recording** (optional)
  - Screen recording of key workflows
  - Narrated demo walkthrough

**Success Criteria:**
- Complete installation documentation
- Verification checklist filled
- Demo materials prepared
- Screenshots captured

---

## Troubleshooting Guide

### AWS-Specific Issues

#### Issue: Cannot Connect to EC2 Instance via SSH

**Symptoms:**
- Connection timeout
- Connection refused
- Permission denied

**Solutions:**
```bash
# 1. Verify instance is running
aws ec2 describe-instances --instance-ids <INSTANCE_ID> --query 'Reservations[0].Instances[0].State.Name'

# 2. Check security group allows SSH from your IP
aws ec2 describe-security-groups --group-ids <SG_ID> | grep -A 10 IpPermissions

# 3. Verify correct key file and permissions
chmod 400 kaapana-poc-key.pem
ls -l kaapana-poc-key.pem  # Should show: -r--------

# 4. Check correct username (ubuntu for Ubuntu AMI)
ssh -i kaapana-poc-key.pem ubuntu@<PUBLIC_IP> -v

# 5. If IP changed (without Elastic IP), get new IP
aws ec2 describe-instances --instance-ids <INSTANCE_ID> --query 'Reservations[0].Instances[0].PublicIpAddress' --output text
```

#### Issue: Out of Disk Space on AWS

**Symptoms:**
- Pods failing with disk pressure
- Cannot create files
- Services crashing

**Solutions:**
```bash
# 1. Check current disk usage
df -h

# 2. Extend existing EBS volume (must be done from AWS Console or CLI)
# Via AWS Console:
# EC2 → Volumes → Select volume → Actions → Modify Volume → Increase size

# Via AWS CLI:
aws ec2 modify-volume --volume-id <VOLUME_ID> --size 500

# 3. Extend filesystem after AWS volume modification
# Wait for modification to complete, then:
sudo growpart /dev/nvme0n1 1  # Extend partition
sudo resize2fs /dev/nvme0n1p1  # Resize filesystem

# Verify new size
df -h

# 4. Or add new EBS volume
aws ec2 create-volume --size 500 --availability-zone <AZ> --volume-type gp3
aws ec2 attach-volume --volume-id <NEW_VOLUME_ID> --instance-id <INSTANCE_ID> --device /dev/sdf

# Format and mount
sudo mkfs.ext4 /dev/nvme1n1
sudo mkdir -p /mnt/additional-storage
sudo mount /dev/nvme1n1 /mnt/additional-storage
```

#### Issue: AWS Security Group Blocks Access

**Symptoms:**
- Cannot access web interface
- DICOM upload fails
- Timeout when accessing services

**Solutions:**
```bash
# 1. Check current security group rules
aws ec2 describe-security-groups --group-ids <SG_ID>

# 2. Add missing rules
# Allow HTTP
aws ec2 authorize-security-group-ingress --group-id <SG_ID> --protocol tcp --port 80 --cidr 0.0.0.0/0

# Allow HTTPS
aws ec2 authorize-security-group-ingress --group-id <SG_ID> --protocol tcp --port 443 --cidr 0.0.0.0/0

# Allow DICOM
aws ec2 authorize-security-group-ingress --group-id <SG_ID> --protocol tcp --port 11112 --cidr 0.0.0.0/0

# 3. Test connectivity
telnet <PUBLIC_IP> 443
curl -I https://<PUBLIC_IP>
```

#### Issue: High AWS Costs

**Solutions:**
```bash
# 1. Check current costs
aws ce get-cost-and-usage \
  --time-period Start=$(date +%Y-%m-01),End=$(date +%Y-%m-%d) \
  --granularity MONTHLY \
  --metrics UnblendedCost

# 2. Stop instance when not in use
aws ec2 stop-instances --instance-ids <INSTANCE_ID>

# 3. Delete unused snapshots
aws ec2 describe-snapshots --owner-ids self
aws ec2 delete-snapshot --snapshot-id <SNAPSHOT_ID>

# 4. Delete unused volumes
aws ec2 describe-volumes --filters "Name=status,Values=available"
aws ec2 delete-volume --volume-id <VOLUME_ID>

# 5. Consider reserved instance or savings plan
# AWS Console → EC2 → Reserved Instances → Purchase Reserved Instances
```

### Common Kaapana Issues

#### Issue 1: Pods Not Starting
**Symptoms:**
- Pods stuck in "Pending" or "ContainerCreating" state
- Pod events show image pull errors

**Solutions:**
- Verify container registry credentials
- Check internet connectivity
- Review pod events: `kubectl describe pod <pod-name>`
- Verify sufficient resources (CPU, memory, disk)

#### Issue 2: MicroK8s Not Starting
**Symptoms:**
- MicroK8s status shows errors
- Node not ready
- Services not accessible

**Solutions:**
- Verify system reboot completed
- Check firewall rules not blocking MicroK8s ports
- Review MicroK8s logs: `microk8s.kubectl logs`
- Restart MicroK8s: `microk8s.stop && microk8s.start`

#### Issue 3: Web Interface Not Accessible
**Symptoms:**
- Cannot connect to HTTPS interface
- Certificate errors
- Login page not loading

**Solutions:**
- Verify ingress controller pods running
- Check DNS resolution for domain name
- Confirm firewall allows ports 80 and 443
- Test with IP address instead of domain
- Review ingress logs

#### Issue 4: DICOM Upload Fails
**Symptoms:**
- Upload errors in UI
- Files not appearing in dataset browser
- dcm4chee not receiving data

**Solutions:**
- Verify dcm4chee pods running
- Check DICOM port 11112 accessible
- Validate DICOM file format
- Review dcm4chee logs for errors
- Confirm storage space available

#### Issue 5: Workflow Execution Fails
**Symptoms:**
- Airflow DAG fails
- Task errors in Airflow UI
- Worker pods crash

**Solutions:**
- Review task logs in Airflow
- Check worker pod logs: `kubectl logs <worker-pod>`
- Verify worker resources sufficient
- Confirm input data valid
- Check service connectivity (Airflow → MinIO, dcm4chee)

#### Issue 6: Out of Memory
**Symptoms:**
- Pods being OOMKilled
- System slowness
- Swap usage high

**Solutions:**
- Increase VM memory allocation
- Reduce number of parallel workflows
- Adjust pod resource limits
- Monitor memory usage patterns
- Consider vertical scaling

#### Issue 7: Out of Disk Space
**Symptoms:**
- Cannot upload more data
- Pods fail to start
- Database errors

**Solutions:**
- Check disk usage: `df -h`
- Clean up old workflow data
- Expand storage volumes
- Implement data retention policies
- Archive old studies to external storage

---

## Post-POC Next Steps

### Transition to Testing Phase (December 2025)

#### Testing Environment Setup
1. **Scale Infrastructure**
   - Increase VM resources if needed
   - Add additional storage for larger datasets
   - Enable backup mechanisms

2. **Enhanced Monitoring**
   - Enable Prometheus/Grafana
   - Configure alerting
   - Set up log aggregation

3. **Security Hardening**
   - Change default credentials
   - Configure SSL certificates (Let's Encrypt)
   - Implement network policies
   - Enable audit logging

4. **User Onboarding**
   - Create production user accounts
   - Conduct user training
   - Develop user documentation
   - Set up support channels

### Preparation for Production (January 2025)

#### Production Readiness Checklist
- [ ] **Scalability**
  - Multi-node Kubernetes cluster (if needed)
  - Load balancing configured
  - Auto-scaling policies

- [ ] **High Availability**
  - Database replication
  - Backup and recovery procedures
  - Disaster recovery plan

- [ ] **Data Management**
  - Data retention policies
  - Archive strategy for old studies
  - DICOM storage capacity planning (hundreds of millions of records for dcm4chee)

- [ ] **Security and Compliance**
  - HIPAA/GDPR compliance review (if applicable)
  - Security audit
  - Penetration testing
  - Access control review

- [ ] **Operations**
  - Monitoring and alerting
  - Incident response procedures
  - Maintenance windows
  - SLA definitions

- [ ] **Documentation**
  - Administrator guide
  - User guide
  - API documentation
  - Runbook for common operations

---

## Success Criteria Summary

### POC Completion Criteria

#### Technical Success
- ✅ Kaapana platform fully deployed
- ✅ All core modules operational (dcm4chee, MinIO, Airflow, OpenSearch)
- ✅ DICOM data successfully uploaded and stored
- ✅ AI segmentation workflow (nnU-Net) executes successfully
- ✅ User authentication and access control functional
- ✅ System persistence validated (survives restart)
- ✅ Performance meets minimum acceptable thresholds

#### Documentation Success
- ✅ Complete installation documentation
- ✅ Configuration parameters documented
- ✅ Access credentials recorded (securely)
- ✅ Verification checklist completed
- ✅ Demo materials prepared
- ✅ Troubleshooting guide created

#### Business Success
- ✅ POC completed within 2-week timeline
- ✅ Demo-ready for stakeholder presentation
- ✅ Confidence in system stability
- ✅ Clear path to testing phase
- ✅ Understanding of resource requirements for production
- ✅ Foundation for scaling to hundreds of millions of records

---

## Resource Contacts

### Kaapana Community
- **Documentation:** https://kaapana.readthedocs.io/en/latest/
- **GitHub:** https://github.com/kaapana/kaapana
- **Slack:** Kaapana Community Workspace
- **Email:** Contact DKFZ team for container registry access

### Cloud Provider Support
- **AWS:** AWS Support Console
- **DigitalOcean:** DigitalOcean Support Portal

### Sample Data Sources
- **TCIA:** https://www.cancerimagingarchive.net/
- **DICOM Library:** https://www.dicomlibrary.com/
- **Medical Segmentation Decathlon:** http://medicaldecathlon.com/

---

## Appendix

### A. AWS-Specific Operations

#### Managing EC2 Instance

**Stop instance (to save costs when not in use):**
```bash
# From AWS CLI
aws ec2 stop-instances --instance-ids <INSTANCE_ID>

# Or via console:
# EC2 → Instances → Select instance → Instance State → Stop
```

**Start instance:**
```bash
# From AWS CLI
aws ec2 start-instances --instance-ids <INSTANCE_ID>

# Note: If you don't have Elastic IP, public IP will change
# Check new IP after start:
aws ec2 describe-instances --instance-ids <INSTANCE_ID> --query 'Reservations[0].Instances[0].PublicIpAddress'
```

**Create AMI (snapshot) for backup:**
```bash
# Create AMI from running instance
aws ec2 create-image \
  --instance-id <INSTANCE_ID> \
  --name "kaapana-poc-backup-$(date +%Y%m%d)" \
  --description "Kaapana POC backup"

# List your AMIs
aws ec2 describe-images --owners self
```

**Create EBS snapshot:**
```bash
# Get volume ID
VOLUME_ID=$(aws ec2 describe-instances --instance-ids <INSTANCE_ID> --query 'Reservations[0].Instances[0].BlockDeviceMappings[0].Ebs.VolumeId' --output text)

# Create snapshot
aws ec2 create-snapshot \
  --volume-id $VOLUME_ID \
  --description "Kaapana POC data backup $(date +%Y%m%d)"

# List snapshots
aws ec2 describe-snapshots --owner-ids self
```

#### Cost Optimization

**Monitor costs:**
```bash
# Check current month costs (requires AWS CLI with cost explorer enabled)
aws ce get-cost-and-usage \
  --time-period Start=$(date +%Y-%m-01),End=$(date +%Y-%m-%d) \
  --granularity MONTHLY \
  --metrics UnblendedCost

# Set up billing alerts:
# AWS Console → Billing → Billing Preferences → Alert Preferences
```

**Stop instance automatically at night (cost saving):**
```bash
# On EC2 instance, create stop script
cat > ~/stop-at-night.sh << 'EOF'
#!/bin/bash
# Stop instance at 10 PM every day
INSTANCE_ID=$(ec2-metadata --instance-id | cut -d " " -f 2)
aws ec2 stop-instances --instance-ids $INSTANCE_ID --region <YOUR_REGION>
EOF

chmod +x ~/stop-at-night.sh

# Add to crontab
crontab -e
# Add line:
# 0 22 * * * /home/ubuntu/stop-at-night.sh
```

**Use Spot Instances (70-90% cost reduction for non-critical workloads):**
```bash
# Request spot instance
aws ec2 request-spot-instances \
  --spot-price "0.30" \
  --instance-count 1 \
  --type "one-time" \
  --launch-specification file://spot-specification.json
```

### B. Command Quick Reference

#### AWS CLI Commands
```bash
# Check instance status
aws ec2 describe-instance-status --instance-ids <INSTANCE_ID>

# Get instance public IP
aws ec2 describe-instances --instance-ids <INSTANCE_ID> --query 'Reservations[0].Instances[0].PublicIpAddress' --output text

# Modify instance type (stop instance first)
aws ec2 modify-instance-attribute --instance-id <INSTANCE_ID> --instance-type "{\"Value\": \"r5.4xlarge\"}"

# Add more storage
aws ec2 create-volume --size 500 --availability-zone <AZ> --volume-type gp3
aws ec2 attach-volume --volume-id <VOLUME_ID> --instance-id <INSTANCE_ID> --device /dev/sdf

# Tag resources
aws ec2 create-tags --resources <INSTANCE_ID> --tags Key=Project,Value=Kaapana-POC
```

#### MicroK8s Commands
```bash
# Check status
microk8s.status

# View pods
microk8s.kubectl get pods --all-namespaces

# View logs
microk8s.kubectl logs <pod-name> -n <namespace>

# Describe pod
microk8s.kubectl describe pod <pod-name> -n <namespace>

# Check node status
microk8s.kubectl get nodes

# View resource usage
microk8s.kubectl top nodes
microk8s.kubectl top pods --all-namespaces
```

#### Deployment Commands
```bash
# Deploy platform
sudo ./deploy_platform.sh

# Undeploy platform
sudo ./deploy_platform.sh --undeploy

# Check Helm releases
helm list --all-namespaces

# View Helm release details
helm status <release-name> -n <namespace>
```

### B. Port Reference

| Service | Port | Protocol | Purpose |
|---------|------|----------|---------|
| HTTP | 80 | TCP | Redirects to HTTPS |
| HTTPS | 443 | TCP | Web interface and APIs |
| DICOM | 11112 | TCP | DICOM DIMSE protocol |
| SSH | 22 | TCP | Server administration |
| Kubernetes API | 16443 | TCP | MicroK8s API (internal) |

### C. Default Credentials (Dev Mode)

**⚠️ Change these in production!**

| Service | Username | Password |
|---------|----------|----------|
| Kaapana UI | kaapana | kaapana |
| Keycloak Admin | admin | Kaapana2020 |
| MinIO | kaapanaminio | Kaapana2020 |
| Grafana | admin | admin |

### D. Storage Directory Structure

```
/home/kaapana/
├── fast_data/          # SSD storage for databases and temporary files
│   ├── postgres/       # PostgreSQL data
│   ├── opensearch/     # OpenSearch indices
│   ├── workflows/      # Airflow workflow data
│   └── cache/          # Temporary processing cache
└── slow_data/          # HDD storage for long-term DICOM storage
    ├── dcm4chee/       # PACS image storage
    ├── archives/       # Archived studies
    └── exports/        # Exported data
```

**Check storage usage:**
```bash
# Overall disk usage
df -h

# Storage by directory
du -sh /home/kaapana/*

# Detailed breakdown
du -h --max-depth=2 /home/kaapana/

# Find large files
find /home/kaapana -type f -size +100M -exec ls -lh {} \;

# Monitor disk usage in real-time
watch df -h
```

### E. Milestone Alignment

| Milestone | POC Phase | Duration | Deliverable |
|-----------|-----------|----------|-------------|
| Milestone 1 | Phase 1 | 2-3 days | Working Kubernetes environment on AWS |
| Milestone 2 | Phase 2 | 1-2 days | Kaapana base platform deployed |
| Milestone 3 | Phase 3 | 3-4 days | Core modules operational |
| Milestone 4 | Phase 4 | 2-3 days | POC documentation and demo |

### F. AWS Cost Breakdown (Monthly Estimates)

**POC Configuration (r5.2xlarge):**
```
EC2 Instance (r5.2xlarge):     $368.00/month (on-demand)
EBS Storage (200GB gp3):       $ 17.00/month
Data Transfer (first 100GB):   $  0.00/month
Elastic IP:                    $  0.00/month (when attached)
───────────────────────────────────────────
Total:                         ~$385.00/month
```

**Cost Optimization Options:**
```
1. Reserved Instance (1 year):  -40% = $231/month
2. Savings Plan (1 year):       -35% = $239/month
3. Stop at night (12h/day):     -50% = $193/month
4. Spot Instance:               -70% = $116/month (with interruption risk)
```

**Production Configuration (r5.4xlarge):**
```
EC2 Instance (r5.4xlarge):     $736.00/month (on-demand)
EBS Storage (500GB gp3):       $ 42.50/month
Additional volumes as needed:   Variable
Data Transfer (> 100GB):       ~$  9.00/month per 100GB
───────────────────────────────────────────
Total:                         ~$787.50/month+
```

---

## Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | Nov 11, 2025 | AI Assistant | Initial POC demo setup plan |
| 1.1 | Nov 11, 2025 | AI Assistant | Updated with AWS-specific instructions and detailed commands |

---

**Document Status:** Ready for Use  
**Target Cloud Provider:** Amazon Web Services (AWS)  
**Next Review Date:** After POC completion  
**Owner:** Development Team

---

## Quick Start Summary

**For experienced users, here's the quick path:**

1. **AWS Setup** (30 min):
   ```bash
   # Launch r5.2xlarge Ubuntu 22.04 instance with 200GB gp3 storage
   # Configure security group: ports 22, 80, 443, 11112
   # Allocate Elastic IP
   ```

2. **System Preparation** (30 min):
   ```bash
   ssh -i key.pem ubuntu@<IP>
   git clone https://github.com/kaapana/kaapana.git
   cd kaapana/server-installation
   sudo ./server_installation.sh
   sudo reboot
   ```

3. **Deploy Platform** (20 min):
   ```bash
   cd ~/kaapana/platforms
   cp deploy_platform_template.sh deploy_platform.sh
   nano deploy_platform.sh  # Edit config
   sudo ./deploy_platform.sh
   watch kubectl get pods -A  # Wait for all Running
   ```

4. **Access** (5 min):
   ```
   Browser: https://<PUBLIC_IP>
   Login: kaapana / kaapana
   ```

5. **Upload Data & Test** (30 min):
   ```
   Download DICOM samples → Upload via UI → View in OHIF
   ```

**Total Time: ~2 hours for basic working POC**
