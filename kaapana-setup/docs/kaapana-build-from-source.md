# Kaapana Build from Source Guide

**Alternative for Pre-built Container Access**

If you cannot access the Slack channel to get pre-built container registry credentials, this guide will walk you through building Kaapana from source. This is a fully supported and official approach.

---

## Table of Contents

1. [Contact Kaapana Team (Primary Option)](#contact-kaapana-team-primary-option)
2. [Build from Source (Alternative Path)](#build-from-source-alternative-path)
3. [Build Requirements](#build-requirements)
4. [Step-by-Step Build Process](#step-by-step-build-process)
5. [Deploy Using Built Containers](#deploy-using-built-containers)
6. [Troubleshooting Build Issues](#troubleshooting-build-issues)

---

## Contact Kaapana Team (Primary Option)

Before building from source, try these official contact methods:

### Email
```
kaapana@dkfz-heidelberg.de

Subject: Request for Container Registry Access
Body: 
- Explain your use case (POC, research, etc.)
- Mention you cannot access Slack channel
- Request registry credentials or pre-built tarball
```

### Slack (Alternative Invites)
- **Public Slack Channel:** https://join.slack.com/t/kaapana/shared_invite/zt-hilvek0w-ucabihas~jn9PDAM0O3gVQ/
- Channel: **#general** or **#support**

### Mailing Address
```
Kaapana Team Heidelberg
German Cancer Research Center (DKFZ)
Division of Medical Image Computing (MIC)
Deutsches Krebsforschungszentrum
Radiologisches Forschungs- und Entwicklungszentrum
Im Neuenheimer Feld 280
69120 Heidelberg
Germany
```

**Expected Response Time:** 1-3 business days

---

## Build from Source (Alternative Path)

### Why Build from Source?

✅ **Advantages:**
- Full control over the build process
- Can customize components if needed
- No dependency on external registry access
- All code visible and auditable
- Supported by Kaapana team

⚠️ **Considerations:**
- Takes ~1 hour on good hardware
- Requires ~90GB disk space during build
- Requires ~80GB more for offline tarball
- Separate build machine recommended

### Typical Workflow

```
┌─────────────────────────────┐
│   Build Machine (Ubuntu)    │  Step 1: Clone repo
│   - Clone Kaapana repo      │  Step 2: Configure build
│   - Install dependencies    │  Step 3: Run build
│   - Run build process       │  Step 4: Generate artifacts
│   - (Takes ~1 hour)         │
└──────────────┬──────────────┘
               │ Results: Docker images + Helm charts
               ▼
┌─────────────────────────────┐
│   Deployment Server (AWS)   │  Step 5: Transfer artifacts
│   - Receive build outputs   │  Step 6: Deploy to Kubernetes
│   - Deploy to Kubernetes    │
└─────────────────────────────┘
```

---

## Build Requirements

### Build Machine Specifications

**Recommended (to avoid issues):**
- **OS:** Ubuntu 24.04 LTS or Ubuntu 22.04 LTS (x64)
- **CPU:** 8+ cores
- **RAM:** 16GB+ (32GB recommended)
- **Storage:** 
  - Main drive: 200GB SSD minimum (for OS + Docker cache)
  - Additional storage: 90GB+ for full build (during build)
  - If creating offline tarball: 80GB more temporary space
- **Network:** Good internet connection (10+ Mbps recommended)

**NOT Recommended:**
- Other Linux distributions (not officially tested)
- ARM/Mac systems (Kaapana is x64 only)
- Virtual machines with <8GB RAM
- Systems with <100GB free disk space

### Important Notes

⚠️ **Architecture Limitation:**
- Kaapana can ONLY be built on **x64 systems**
- Building on other architectures (ARM, Mac M1/M2, etc.) is NOT supported
- Official support not provided for non-x64 systems

### Pre-Build Checklist

```bash
# Verify system specifications
uname -m  # Should output: x86_64

lscpu | grep "Core(s)"  # Check CPU cores (8+ recommended)

free -h  # Check RAM (16GB+ recommended)

df -h | head -5  # Check disk space (200GB+ free)

# Check internet connectivity
ping -c 1 github.com
ping -c 1 docker.io
```

---

## Step-by-Step Build Process

### Step 1: Prepare Build Machine

**Update system:**
```bash
sudo apt update
sudo apt upgrade -y
sudo apt install -y nano curl git python3 python3-pip python3-venv
```

**Verify Ubuntu version:**
```bash
lsb_release -a
# Should show: Ubuntu 22.04 or 24.04
```

### Step 2: Install Build Dependencies

**Install Snap (if not installed):**
```bash
sudo apt install -y snapd

# Verify snap installation
snap help --all

# Reboot if snap is newly installed
sudo reboot
```

**Install Docker via Snap:**
```bash
sudo snap install docker --classic --channel=latest/stable

# Verify Docker installation
docker --version  # Should show: Docker version X.X.X

# Test Docker (should work without sudo)
docker run hello-world
```

If you get permission error, configure user permissions:
```bash
sudo groupadd docker || true
sudo usermod -aG docker $USER
newgrp docker

# Test again
docker run hello-world
```

**Install Helm:**
```bash
sudo snap install helm --classic --channel=latest/stable

# Verify Helm installation
helm version

# Install Helm kubeval plugin
helm plugin install https://github.com/instrumenta/helm-kubeval
```

**Optional Reboot (recommended after Snap changes):**
```bash
sudo reboot
```

### Step 3: Clone Kaapana Repository

**Create working directory:**
```bash
mkdir -p ~/kaapana-build
cd ~/kaapana-build
```

**Clone repository:**
```bash
git clone -b master https://github.com/kaapana/kaapana.git

# Verify clone
ls -la kaapana/
ls -la kaapana/build-scripts/
```

### Step 4: Set Up Python Virtual Environment

**Create virtual environment (recommended for Python dependencies):**
```bash
cd ~/kaapana-build

# Create venv
python3 -m venv kaapana/.venv

# Activate venv
source kaapana/.venv/bin/activate

# Verify activation (prompt should show (.venv))
which python

# Install Python build requirements
python3 -m pip install -r kaapana/build-scripts/requirements.txt

# Verify installation
python3 -m pip list | grep -E "docker|PyYAML|jinja"
```

### Step 5: Configure Build Settings

**Generate default build configuration:**
```bash
cd ~/kaapana-build

# Ensure venv is activated
source kaapana/.venv/bin/activate

# Generate config file
./kaapana/build-scripts/start_build.py
```

**This creates:** `kaapana/build-scripts/build-config.yaml`

**Review and edit configuration:**
```bash
nano kaapana/build-scripts/build-config.yaml
```

**Key Configuration Options for Build-Only:**

```yaml
# Option 1: Build WITH Local Registry (Recommended if you have GitLab)
default_registry: "registry.gitlab.com/<your-username>/<project-name>"
registry_username: "<your-gitlab-username>"
registry_password: "<your-gitlab-token>"  # Use access token, not password
container_engine: "docker"
enable_build_kit: true
build_only: false  # Set to false if you want to push to registry
push_to_microk8s: false
exit_on_error: true
enable_linting: true
parallel_processes: 2

# Option 2: Build WITHOUT Registry (Store locally, will inject into MicroK8s later)
default_registry: "localhost:5000"  # Local registry
registry_username: ""
registry_password: ""
container_engine: "docker"
build_only: true  # Only build, don't push
push_to_microk8s: false  # Will inject after deployment
exit_on_error: true
enable_linting: true
parallel_processes: 2

# Option 3: Create Offline Tarball (for transfer without registry)
default_registry: "localhost:5000"
registry_username: ""
registry_password: ""
container_engine: "docker"
build_only: true
create_offline_installation: true  # Create ~80GB tarball
push_to_microk8s: false
exit_on_error: true
enable_linting: true
parallel_processes: 2
```

**Important Configuration Notes:**

- **`build_only: true`** - Only build, don't push (if no registry)
- **`push_to_microk8s: false`** - Don't inject (inject manually later)
- **`create_offline_installation: true`** - Create tarball for transfer (needs extra 80GB space)
- **`parallel_processes`** - Adjust based on CPU cores (2-4 recommended)
- **`enable_linting: true`** - Validates Helm charts during build

### Step 6: Start Build Process

**Verify configuration looks correct:**
```bash
# Check configuration
cat kaapana/build-scripts/build-config.yaml

# Verify disk space before starting
df -h | grep "/$\|/var\|/$\|/mnt"
# Should show 150GB+ free space
```

**Start the build:**

**Option A: Build with Registry (GitLab, Docker Hub, etc.):**
```bash
cd ~/kaapana-build

# Ensure venv is activated
source kaapana/.venv/bin/activate

# Run build with credentials
./kaapana/build-scripts/start_build.py -u <registry-username> -p <registry-access-token>

# Example:
# ./kaapana/build-scripts/start_build.py -u myusername -p glpat-xxxxxxxxxx
```

**Option B: Build Locally (No Registry):**
```bash
cd ~/kaapana-build

# Ensure venv is activated
source kaapana/.venv/bin/activate

# Run build (no credentials needed)
./kaapana/build-scripts/start_build.py

# If prompted for credentials, press Enter to skip
```

**Monitor Build Progress:**

```bash
# In a separate terminal, monitor Docker images
watch docker images | grep kaapana

# Monitor disk usage
watch df -h

# Monitor build logs
tail -f ~/kaapana-build/kaapana/build/build.log
```

**Expected Build Output:**
```
Starting Kaapana build process...
Building: kaapana-backend-image
Building: dcm4chee-arc-image
Building: opensearch-image
Building: airflow-webserver-image
...
[Multiple container builds]...
Pushing images to registry...
Generating Helm charts...
Build completed successfully!
Results saved to: ~/kaapana-build/kaapana/build/
```

**Build Duration:** ~45-90 minutes (depending on hardware and internet speed)

### Step 7: Verify Build Artifacts

**After build completes, verify output:**

```bash
# Check generated files
ls -la ~/kaapana-build/kaapana/build/

# Expected files/directories:
# - kaapana-admin-chart/        (Helm chart)
# - deploy_platform.sh          (Deployment script)
# - build_info.json             (Build metadata)
# - build.log                   (Build log)

# List generated Docker images
docker images | grep kaapana

# Count images
docker images | grep kaapana | wc -l
# Should show 20+ images
```

**Check image details:**
```bash
# View image sizes
docker images --format "table {{.Repository}}\t{{.Size}}" | grep kaapana

# Total size of all images
docker images --format "{{.Size}}" | grep -v SIZE | awk '{sum += $(NF-1)} END {print "Total: " sum}'
```

### Step 8: Transfer Build Artifacts to Deployment Server

**Option A: Using Registry (Recommended if available)**

If you built with registry credentials, images are already pushed to registry. On deployment server:
- Use the same registry credentials in deploy_platform.sh
- Images will be pulled automatically during deployment

**Option B: Copy Deploy Script & Use Local Docker**

```bash
# On build machine, compress and transfer
cd ~/kaapana-build

# Copy deploy script
cp kaapana/build/kaapana-admin-chart/deploy_platform.sh deploy_platform_built.sh

# Transfer to deployment server
scp -i ~/.ssh/aws-key.pem deploy_platform_built.sh ubuntu@<AWS_PUBLIC_IP>:~/

# Also transfer the Helm chart
scp -i ~/.ssh/aws-key.pem -r kaapana/build/kaapana-admin-chart ubuntu@<AWS_PUBLIC_IP>:~/

# Transfer Docker images (large file)
docker save kaapana-backend | gzip > kaapana-backend.tar.gz
scp -i ~/.ssh/aws-key.pem kaapana-backend.tar.gz ubuntu@<AWS_PUBLIC_IP>:~/

# Repeat for other critical images
```

**Option C: Create Offline Tarball (if configured)**

If you set `create_offline_installation: true`:

```bash
# Check for offline tarball
ls -lh ~/kaapana-build/kaapana/build/*.tar.gz

# Transfer to deployment server
scp -i ~/.ssh/aws-key.pem kaapana-offline-installer.tar.gz ubuntu@<AWS_PUBLIC_IP>:~/

# On deployment server, extract
cd ~
tar -xzf kaapana-offline-installer.tar.gz

# Follow standard deployment process with extracted files
```

---

## Deploy Using Built Containers

### On AWS Deployment Server

**After transferring build artifacts:**

```bash
# Connect to AWS server
ssh -i kaapana-poc-key.pem ubuntu@<PUBLIC_IP>

# If using copied deploy script
cd ~
chmod +x deploy_platform_built.sh

# Edit configuration
nano deploy_platform_built.sh

# For built containers (not using registry):
# Set up local Docker or use transferred images

# If using offline tarball, extract first
tar -xzf kaapana-offline-installer.tar.gz
cd kaapana-offline-installer
chmod +x deploy_platform.sh
```

**Deploy using built artifacts:**

```bash
# Run deployment script (same as regular deployment)
sudo ./deploy_platform.sh

# Or if using offline tarball
sudo ./kaapana-offline-installer/deploy_platform.sh
```

---

## Troubleshooting Build Issues

### Issue: Disk Space Running Out During Build

**Problem:** Build fails with "No space left on device"

**Solution:**
```bash
# 1. Check current disk usage
df -h

# 2. Clean Docker cache
docker system prune -a --volumes

# 3. Remove old images if needed
docker rmi $(docker images -q)

# 4. Check build directory
du -sh ~/kaapana-build

# 5. Move to larger disk or cleanup other files
# Or use external SSD for Docker storage
```

**Prevent Issue:**
- Ensure 200GB+ free space before starting build
- Don't run other large processes during build
- Consider using fast SSD for Docker storage

### Issue: Out of Memory During Build

**Problem:** Build hangs or gets killed with OOM error

**Solution:**
```bash
# 1. Check available memory
free -h

# 2. Reduce parallel processes in build-config.yaml
parallel_processes: 1  # Reduce from default

# 3. Increase system swap (if needed)
sudo fallocate -l 16G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile

# 4. Verify swap is enabled
swapon --show
```

### Issue: Registry Credentials Not Working

**Problem:** Build fails with "unauthorized: authentication required"

**Solution:**
```bash
# 1. Verify credentials are correct
# Use access token instead of password
# GitLab: Settings → Access Tokens → Create token
# Docker Hub: Account Settings → Security → Create Access Token

# 2. Test registry access manually
docker login -u <username> -p <token> <registry-url>

# 3. If using GitLab token, ensure it has proper scope:
# - api (for API access)
# - read_registry (to pull/push images)
# - write_registry (to push images)

# 4. Check credentials in build-config.yaml
# Ensure no spaces or special characters in credentials
```

### Issue: Build Takes Too Long

**Problem:** Build is still running after 2+ hours

**Symptoms:** Stuck on one particular image build

**Solution:**
```bash
# 1. Check build logs
tail -f ~/kaapana-build/kaapana/build/build.log

# 2. Check if processes are hanging
docker ps -a

# 3. Can safely stop and restart
./kaapana/build-scripts/start_build.py

# 4. Use skip feature for previously built images (if available)
# Check build-config.yaml for skip options

# 5. Increase parallel processes (if you have spare CPU/memory)
# Change parallel_processes: 4 in build-config.yaml
```

### Issue: Cannot Connect to GitHub During Clone

**Problem:** Git clone fails with network error

**Solution:**
```bash
# 1. Check internet connectivity
ping github.com

# 2. If behind proxy, configure Git
git config --global http.proxy [proxy-url]

# 3. Try cloning again
git clone -b master https://github.com/kaapana/kaapana.git

# 4. If still failing, use SSH instead (if SSH key configured)
git clone -b master git@github.com:kaapana/kaapana.git
```

### Issue: Docker Not Running as Non-Root

**Problem:** Getting permission denied when running docker commands

**Solution:**
```bash
# 1. Add user to docker group
sudo usermod -aG docker $USER

# 2. Apply group changes (no logout needed)
newgrp docker

# 3. Verify
docker run hello-world
```

---

## Next Steps After Build

1. **Transfer artifacts to deployment server** (see Step 8)

2. **Install server dependencies** (same as before):
   ```bash
   sudo ~/kaapana/server-installation/server_installation.sh
   sudo reboot
   ```

3. **Deploy platform** using built containers (see deploy section)

4. **Continue with data upload and testing** (as per main setup plan)

---

## Support & Additional Resources

- **Official Build Guide:** https://kaapana.readthedocs.io/en/latest/installation_guide/build.html
- **Advanced Build System:** https://kaapana.readthedocs.io/en/latest/installation_guide/advanced_build_system.html
- **Contact:** kaapana@dkfz-heidelberg.de
- **Slack:** https://join.slack.com/t/kaapana/shared_invite/zt-hilvek0w-ucabihas~jn9PDAM0O3gVQ/

---

## Cost Comparison: Build vs Pre-built

| Approach | Time | Cost | Hardware |
|----------|------|------|----------|
| **Pre-built Registry** | ~30 min (download) | Free (registry access) | Deployment server only |
| **Build Locally** | ~2 hours | Cost of build machine | Build machine + deployment server |
| **Build + Offline Tarball** | ~3 hours | Cost of build machine + storage | Build machine + large storage |

**Recommendation:** If you have access to registry credentials (via email), request those first. If absolutely unable to get registry access, building from source is a fully supported alternative.

---

**Document Status:** Ready to Use  
**Last Updated:** November 12, 2025
