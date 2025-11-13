# 03 - Kaapana Build Process

**Phase:** 2 - Build  
**Duration:** 1-2 hours (mostly automated)  
**Prerequisite:** 02-build-machine-preparation.md completed

---

## Overview

This guide walks through building Kaapana from source. The build process:
- Compiles ~90 Docker containers
- Creates Helm charts for deployment
- Generates platform installation scripts
- Requires ~90GB disk space during build
- Takes 1-2 hours depending on hardware and network speed

---

## Build Architecture

Kaapana uses a modular build system:
```
build-scripts/
├── start_build.py          # Main build orchestrator
├── build-config-template.yaml  # Build configuration
├── requirements.txt         # Python dependencies
└── build_helper/           # Build modules
    ├── build/              # Build logic
    ├── cli/                # CLI interface
    ├── configs/            # Config handlers
    ├── container/          # Container builds
    └── helm/               # Helm chart generation
```

---

## Step 1: Configure Build Settings

### Navigate to Build Scripts Directory
```bash
# SSH to your build machine
cd ~/kaapana-build
source kaapana-venv/bin/activate
cd kaapana/build-scripts
```

### Create Build Configuration
```bash
# Copy template
cp build-config-template.yaml build-config.yaml

# Edit configuration
nano build-config.yaml
```

### Minimal Build Configuration

**For POC, use this minimal config:**
```yaml
# build-config.yaml - Minimal POC Configuration

# Build Options
default_container_registry: "local"  # Build locally, not push to registry
build_platform: "linux/amd64"        # x86_64 architecture
enable_build_kit: true               # Use Docker BuildKit (faster)
parallel_processes: 4                # Parallel builds (adjust based on CPU)

# Platform Configuration
platform_name: "kaapana-poc"
platform_version: "0.3.0"            # Match repository version

# Components to Build (all required for minimal setup)
components:
  base:
    enabled: true      # Base Python images
  services:
    enabled: true      # Core services (Airflow, OpenSearch, etc.)
  operators:
    enabled: true      # Airflow operators
  workflows:
    enabled: true      # Workflow DAGs
  applications:
    enabled: true      # Web applications (OHIF, etc.)

# Registry Settings (not used for local build)
registry:
  url: ""              # Empty for local build
  username: ""
  project: ""

# Build Cache
cache:
  enabled: true        # Use Docker cache (speeds up rebuilds)
  
# Output
output_dir: "./builds"  # Build artifacts location

# Logging
log_level: "INFO"      # DEBUG for verbose output
```

**Save and exit:** `Ctrl+O`, `Enter`, `Ctrl+X`

---

## Pre-Build Checklist (CRITICAL - Do This Before Starting)

Before running the build, verify all prerequisites:

```bash
# Navigate to build scripts directory
cd ~/kaapana/build-scripts

# 1. Check disk space (CRITICAL - need 200GB+ free)
df -h /
df -h /var/snap/docker/common/
# MUST show: 200GB+ available (500GB recommended)
# If less than 200GB, STOP and expand volume first!

# 2. Check Docker permissions (CRITICAL - docker must work without sudo)
docker run hello-world
# If this fails, see "Docker permission denied" in Troubleshooting

# 3. Check Docker authentication with ECR
docker login -u AWS -p $(aws ecr get-login-password --region us-east-1) 223271671018.dkr.ecr.us-east-1.amazonaws.com
# Should show: Login Succeeded

# 4. Verify virtual environment
source ~/kaapana/.venv/bin/activate
which python3
# Should show: /home/ubuntu/kaapana/.venv/bin/python3

# 5. Verify build config file exists
ls -la build-config-ecr.yaml

# 6. Verify YAML is valid
python3 -c "import yaml; yaml.safe_load(open('build-config-ecr.yaml'))" && echo "✓ YAML valid" || echo "✗ YAML invalid"

# 7. Check system resources
echo "CPU: $(nproc) cores"
echo "RAM: $(free -h | grep Mem | awk '{print $2}')"
echo "Available disk: $(df -h / | tail -1 | awk '{print $4}')"

# 8. Verify internet connectivity
ping -c 2 8.8.8.8

# If all checks pass, you're ready to build!
echo "✓ All pre-build checks passed!"
```

**If any check fails, DO NOT proceed. Fix the issue first (see Troubleshooting section).**

---

## Step 3: Start Build Process

**⚠️ Important:** 
- The build takes 1-2 hours
- Requires 200GB+ free disk space
- Use `screen` or `tmux` to prevent SSH disconnection from stopping the build
- Monitor disk space during build - if it runs out, build will fail

### Option A: Using screen (RECOMMENDED - survives SSH disconnect)

```bash
# Install screen (one-time only)
sudo apt install -y screen

# Start screen session
screen -S kaapana-build

# Inside screen: activate venv and start build
cd ~/kaapana
source ~/.venv/bin/activate
cd build-scripts

# Clean old artifacts (if retrying build)
rm -rf ./build/
rm -f ./build.log

# Get ECR password
ECR_PASSWORD=$(aws ecr get-login-password --region us-east-1)

# Start build
python3 start_build.py \
  --config build-config-ecr.yaml \
  --username AWS \
  --password "$ECR_PASSWORD" \
  --parallel 4 | tee build.log

# Build is now running! It will continue even if you disconnect.
```

**To detach from screen while build runs:**
- Press `Ctrl+A` then `D`
- SSH connection can now close safely

**To reattach to screen later:**
```bash
screen -r kaapana-build

# Or if multiple sessions, list them:
screen -ls
screen -r kaapana-build
```

**To stop build (if needed):**
```bash
# Inside screen:
# Press Ctrl+C to stop the build

# Or from outside screen:
screen -S kaapana-build -X quit
```

### Option B: Direct execution (simpler, but build stops if SSH disconnects)

```bash
# Activate venv and navigate to build-scripts
cd ~/kaapana
source ~/.venv/bin/activate
cd build-scripts

# Clean old artifacts
rm -rf ./build/
rm -f ./build.log

# Get ECR password
ECR_PASSWORD=$(aws ecr get-login-password --region us-east-1)

# Start build
python3 start_build.py \
  --config build-config-ecr.yaml \
  --username AWS \
  --password "$ECR_PASSWORD" \
  --parallel 4 | tee build.log

# Build runs in foreground - keep SSH session open
# If connection drops, build will stop
```

### Option C: Build Locally First (Two-step approach)

```bash
# Step 1: Build all containers locally without pushing
cd ~/kaapana
source ~/.venv/bin/activate
cd build-scripts

# Clean old artifacts
rm -rf ./build/
rm -f ./build.log

# Start build (containers only, no push)
python3 start_build.py \
  --config build-config-ecr.yaml \
  --build-only \
  --parallel 4 | tee build.log

# Step 2: After build completes, push to ECR
# (See "Push Images to ECR" section later in this guide)
```

---

## Step 4: Monitor Build Progress

**⚠️ CRITICAL:** Monitor disk space throughout the build. If it reaches 100%, the build will fail.

### Check Build Logs

**If using screen:**
```bash
# Reattach to screen to see logs
screen -r kaapana-build

# Scroll up to see earlier logs
# Press Ctrl+A then Esc, then arrow keys to scroll
# Press Q to exit scrolling mode

# Or tail the log file from another SSH session
tail -f ~/kaapana/build-scripts/build.log
```

**Follow build progress:**
```bash
# Live tail of build log
tail -f ~/kaapana/build-scripts/build.log

# Count containers built so far
grep "container builds successfully" ~/kaapana/build-scripts/build.log | wc -l

# Look for errors
grep -i "ERROR\|FAILED" ~/kaapana/build-scripts/build.log
```

**Expected log output:**
```
[INFO] Starting Kaapana build process...
[INFO] Build configuration loaded: build-config-ecr.yaml
[INFO] Registry: 223271671018.dkr.ecr.us-east-1.amazonaws.com/kaapana-poc-poc
[INFO] Build mode: build and push to ECR
[INFO] Parallel processes: 4
[INFO] Starting component: base
[INFO] Building base-python-cpu...
[INFO] Building base-python-gpu...
[INFO] Starting component: services
[INFO] Building dcm4chee-arc...
[INFO] Building airflow...
[INFO] Building opensearch...
... (continues for 1-2 hours)
```

### Monitor System Resources (CRITICAL - Watch Disk Space!)

**In a SEPARATE SSH session:**

```bash
# Watch available disk space continuously
watch -n 60 'df -h / | tail -1 && echo "---" && du -sh /var/snap/docker/common/var-lib-docker/'

# Or use simpler command
while true; do df -h /; du -sh /var/snap/docker/common/var-lib-docker/; sleep 60; done

# If disk space is decreasing and approaching 100%, BUILD WILL FAIL!
# See "Out of disk space" in Troubleshooting section
```

**Monitor CPU and memory:**
```bash
# Watch CPU and memory usage
htop

# Or use top
top

# Docker images being built
watch -n 30 'docker images | wc -l'
```

**Monitor Docker image count:**
```bash
# Count Docker images as they build
docker images | wc -l

# Should start at 0 and grow to 90+ over the 1-2 hours
```

### Expected Build Timeline

| Phase | Duration | Description |
|-------|----------|-------------|
| Base Images | 10-15 min | Python, CUDA base images (~2-3GB) |
| Services | 30-40 min | dcm4chee, Airflow, OpenSearch, etc. (~30-40GB) |
| Operators | 15-20 min | Airflow operators for workflows (~10-15GB) |
| Applications | 10-15 min | OHIF viewer, admin tools (~5-10GB) |
| Helm Charts | 5-10 min | Deployment chart generation |
| ECR Push | 20-30 min | Push all images to ECR (depends on network) |
| **Total** | **1-2.5 hours** | Varies by hardware/network/disk performance |

### Disk Space Growth Expectation

```
Start: 200GB free
After 15 min: ~180GB free (base images complete)
After 50 min: ~120GB free (services in progress)
After 1 hour: ~80GB free (operators in progress)
After 1.5 hrs: ~40GB free (applications being pushed to ECR)
End: ~20-30GB free (finished, charts and scripts generated)
```

**If disk space drops below 20GB:**
```bash
# Immediately stop the build
# Go to separate SSH session and press Ctrl+C to stop build

# Then expand volume (see Troubleshooting section)
```

---

## Step 5: Verify Build Completion

**How to know when the build is complete:**

```bash
# Check final log output
tail -n 100 ~/kaapana/build-scripts/build.log

# Look for success message:
# [INFO] Build completed successfully!
# [INFO] Total images built: 90+
# [INFO] All artifacts ready for deployment
```

### Verify Docker Images

```bash
# Count total images built
docker images | wc -l
# Should show: 90+ images (including base and intermediate images)

# List only Kaapana images pushed to ECR
docker images | grep "223271671018.dkr.ecr"

# Check image sizes
docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}" | grep "kaapana-poc-poc" | head -20
```

**Expected images include:**
```
223271671018.dkr.ecr.us-east-1.amazonaws.com/kaapana-poc-poc/base-python-cpu          0.5.2    800MB
223271671018.dkr.ecr.us-east-1.amazonaws.com/kaapana-poc-poc/base-python-gpu          0.5.2    3.5GB
223271671018.dkr.ecr.us-east-1.amazonaws.com/kaapana-poc-poc/dcm4chee-arc             0.5.2    1.2GB
223271671018.dkr.ecr.us-east-1.amazonaws.com/kaapana-poc-poc/airflow                  0.5.2    1.5GB
223271671018.dkr.ecr.us-east-1.amazonaws.com/kaapana-poc-poc/opensearch               0.5.2    950MB
223271671018.dkr.ecr.us-east-1.amazonaws.com/kaapana-poc-poc/minio                    0.5.2    280MB
223271671018.dkr.ecr.us-east-1.amazonaws.com/kaapana-poc-poc/keycloak                 0.5.2    650MB
223271671018.dkr.ecr.us-east-1.amazonaws.com/kaapana-poc-poc/ohif-viewer              0.5.2    450MB
... (90+ total)
```

### Verify ECR Push

```bash
# List images pushed to ECR
aws ecr list-images --repository-name kaapana-poc-poc --region us-east-1 --output table

# Count ECR images
aws ecr list-images --repository-name kaapana-poc-poc --region us-east-1 --query 'imageIds' --output text | wc -w

# Should show: 90+ images with tags like 0.5.2, latest, etc.
```

**Expected output:**
```
|                                           IMAGEID                                               |
|--------------------------------------|
|  imageDigest: sha256:abc123...       |
|  imageTag: 0.5.2                     |
|  imageTag: latest                    |
|  imageDigest: sha256:def456...       |
|  imageTag: 0.5.2                     |
|  imageTag: latest                    |
... (90+ images)
```

### Verify Helm Charts

```bash
# Check build output directory for Helm charts
ls -lh ~/kaapana/build-scripts/build/

# Should contain:
# - kaapana-platform-chart-*.tgz
# - kaapana-admin-chart-*.tgz
# - Various service charts (*.tgz files)

# List all Helm charts generated
find ~/kaapana/build-scripts/build/ -name "*.tgz" | wc -l

# Should show: 15+ chart files
```

### Verify Deployment Scripts

```bash
# Check for installation scripts
ls -la ~/kaapana/server-installation/

# Should contain:
# - server_installation.sh
# - Various configuration scripts

# Check platform deployment scripts
ls -la ~/kaapana/platforms/

# Should contain:
# - deploy_platform.sh
# - kaapana-platform-chart/
# - kaapana-admin-chart/
```

### Test ECR Image Pull

```bash
# Verify images can be pulled from ECR
docker pull 223271671018.dkr.ecr.us-east-1.amazonaws.com/kaapana-poc-poc/base-python-cpu:0.5.2

# List pulled images (should show in docker images)
docker images | grep kaapana-poc-poc

# If pull succeeds, ECR push was successful
```

### Final Build Verification Checklist

Before proceeding to deployment, verify:

```bash
# Run comprehensive verification
echo "=== Build Completion Verification ==="

# 1. Check Docker images
DOCKER_COUNT=$(docker images | grep "223271671018.dkr.ecr" | wc -l)
echo "✓ Docker images built: $DOCKER_COUNT (should be 80+)"

# 2. Check ECR push
ECR_COUNT=$(aws ecr list-images --repository-name kaapana-poc-poc --region us-east-1 --query 'length(imageIds)' --output text)
echo "✓ ECR images pushed: $ECR_COUNT (should be 90+)"

# 3. Check Helm charts
CHART_COUNT=$(find ~/kaapana/build-scripts/build/ -name "*.tgz" 2>/dev/null | wc -l)
echo "✓ Helm charts generated: $CHART_COUNT (should be 15+)"

# 4. Check deployment scripts
if [ -f ~/kaapana/server-installation/server_installation.sh ]; then
  echo "✓ Deployment scripts ready"
else
  echo "✗ Deployment scripts missing"
fi

# 5. Check build log for errors
if grep -q "ERROR\|FAILED" ~/kaapana/build-scripts/build.log; then
  echo "⚠ Warnings/Errors found in build log"
  grep "ERROR\|FAILED" ~/kaapana/build-scripts/build.log | head -5
else
  echo "✓ Build completed without critical errors"
fi

# 6. Disk usage summary
echo ""
echo "Disk Usage:"
df -h / | tail -1
du -sh /var/snap/docker/common/var-lib-docker/

echo ""
echo "=== Verification Complete ==="
```

---

## Step 6: Check Disk Usage After Build

```bash
# Check total disk usage
df -h /
df -h /var/snap/docker/common/

# Check Docker disk usage (images, containers, volumes, cache)
docker system df

# Expected output after build:
# TYPE            TOTAL     ACTIVE    SIZE      RECLAIMABLE
# Images          90+       90        85GB      0B (0%)
# Containers      0         0         0B        0B
# Local Volumes   2         0         1.2GB     1.2GB (100%)
# Build Cache     120       0         15GB      15GB (100%)
```

**Optional: Clean build cache to free up space (safe after successful build):**

```bash
# Remove Docker build cache (not the images themselves)
docker builder prune -af

# Check space freed
df -h /

# This can free up ~15-20GB but doesn't affect the built images
```

**⚠️ Do NOT run `docker system prune -af` as it will delete the built images!**

---

## Step 7: Create Build Archive (Optional)

**If building on separate machine from deployment server:**

```bash
# Create compressed archive of build artifacts
cd ~/kaapana-build/kaapana

# Export Docker images to tar file
docker save $(docker images --format "{{.Repository}}:{{.Tag}}" | grep "local-only") \
  -o ~/kaapana-images.tar

# Compress (this takes time)
gzip ~/kaapana-images.tar

# Create archive of Helm charts and scripts
tar -czf ~/kaapana-charts.tar.gz \
  build-scripts/builds/ \
  server-installation/ \
  platforms/

# Check archive sizes
ls -lh ~ | grep kaapana
```

**Expected archive sizes:**
- `kaapana-images.tar.gz`: 30-40GB
- `kaapana-charts.tar.gz`: 500MB-1GB

---

## Troubleshooting

### Build fails: "Docker permission denied"

```bash
# Check if user is in docker group
id $USER
# Should show: groups=...,1001(docker),...

# If docker group not shown, add user and verify
sudo usermod -aG docker $USER
newgrp docker
id $USER  # Should now show docker group

# Fix socket permissions if still having issues
sudo chmod 666 /var/snap/docker/common/var-lib-docker.sock

# Or restart Docker daemon
sudo snap services docker
sudo snap restart docker --reload

# Test Docker
docker run hello-world

# Restart build if it was failing due to permissions
cd ~/kaapana
source ~/.venv/bin/activate
cd build-scripts
python3 start_build.py --config build-config-ecr.yaml --build-only --parallel 4
```

### Build fails: "Out of disk space"

**⚠️ CRITICAL:** This is a very common issue. Plan disk space BEFORE building.

```bash
# Check current space
df -h /

# Check Docker usage specifically
du -sh /var/snap/docker/common/var-lib-docker/
docker system df

# If approaching capacity or full:

# Option 1: Stop build and clean cache (if build is running)
docker builder prune -af

# Option 2: Expand AWS volume (recommended)
# 1. AWS Console → EC2 → Volumes → Select root volume
# 2. Click "Modify Volume" → increase to 300GB or 500GB
# 3. Wait 5-10 minutes for volume to expand
# 4. On server:
sudo growpart /dev/nvme0n1 1
sudo resize2fs /dev/nvme0n1p1
df -h /  # Verify new size

# Option 3: Use second AWS volume (if available)
# See "02-build-machine-preparation.md" - Disk Space Management section

# After fixing, restart build:
cd ~/kaapana
source ~/.venv/bin/activate
cd build-scripts
python3 start_build.py --config build-config-ecr.yaml --build-only --parallel 4
```

### Build fails with YAML config errors

```bash
# Common issue: YAML parsing errors with empty strings or special characters

# Check error message:
tail -50 build.log

# Common mistakes in build-config-ecr.yaml:
# ❌ WRONG: registry_password:        (no value)
# ✅ RIGHT: registry_password: ''      (empty string in single quotes)

# ❌ WRONG: platform_filter: kaapana-admin-chart  (unquoted)
# ✅ RIGHT: platform_filter: ''        (empty to build ALL, or 'kaapana-platform-chart')

# ❌ WRONG: http_proxy: ""             (double quotes)
# ✅ RIGHT: http_proxy: ''             (single quotes)

# Verify YAML syntax:
python3 -c "import yaml; yaml.safe_load(open('build-config-ecr.yaml'))" && echo "✓ YAML valid" || echo "✗ YAML invalid"

# If invalid, check formatting carefully
```

### Build fails: "No such file or directory - build-config.yaml"

```bash
# Ensure you're in the correct directory:
pwd
# Should show: /home/ubuntu/kaapana/build-scripts

# Verify config file exists:
ls -la build-config-ecr.yaml

# If file doesn't exist, create it:
# Copy the template from earlier in this guide
cp build-config-template.yaml build-config-ecr.yaml
# Then edit with proper ECR configuration

# Then try build again:
python3 start_build.py --config build-config-ecr.yaml --build-only --parallel 4
```

### Build fails with "platform_filter" issues

```bash
# Most common error: platform_filter is set to 'kaapana-admin-chart'
# This causes build to SKIP all containers and only build one chart

# Check your config:
grep "platform_filter:" build-config-ecr.yaml

# It should be EMPTY to build everything:
# platform_filter: ''

# If it has a value, edit the config:
sed -i "s/platform_filter: .*/platform_filter: ''/g" build-config-ecr.yaml

# Verify fix:
grep "platform_filter:" build-config-ecr.yaml
# Should show: platform_filter: ''

# Restart build:
rm -rf ./build/
python3 start_build.py --config build-config-ecr.yaml --build-only --parallel 4
```

### Build fails: "ECR repository does not exist"

```bash
# If seeing errors like: "repository with name 'kaapana-poc-poc' does not exist"

# Check if repository exists:
aws ecr describe-repositories --repository-names kaapana-poc-poc --region us-east-1

# If not found, create it:
aws ecr create-repository \
  --repository-name kaapana-poc-poc \
  --region us-east-1 \
  --image-scanning-configuration scanOnPush=true

# Verify creation:
aws ecr describe-repositories --repository-names kaapana-poc-poc --region us-east-1

# Re-authenticate Docker:
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 223271671018.dkr.ecr.us-east-1.amazonaws.com

# Restart build:
python3 start_build.py --config build-config-ecr.yaml --build-only --parallel 4
```

### Build fails on specific image

```bash
# Check error in log
tail -100 build.log | grep -i "error\|failed"

# Common causes:
# - Network timeout: Retry build
# - Missing dependency: Check base image built successfully
# - Syntax error in Dockerfile: Check Kaapana version compatibility
# - Out of disk space: See disk space troubleshooting above

# Build single image for debugging:
cd ~/kaapana/services/<service-name>
docker build -t test-image .

# If single image builds fine but full build fails, might be:
# - Parallel process issues: reduce parallel processes
# - Network issues: increase timeouts
# - Resource constraints: reduce parallel processes
```

### Build hangs or takes too long

```bash
# Check system resources
htop
df -h

# Check Docker processes
docker ps -a

# Check build log for progress
tail -f build.log

# If build appears stuck:
# 1. Press Ctrl+C (if in screen: Ctrl+A then K)

# 2. Check what was running:
docker ps -a

# 3. Clean up any stuck containers:
docker container prune -f

# 4. Reduce parallel processes and restart:
python3 start_build.py --config build-config-ecr.yaml --build-only --parallel 2
```

### Python import errors or venv issues

```bash
# Ensure venv is activated
source ~/kaapana/.venv/bin/activate

# Verify activation (prompt should show (.venv))
which python3
# Should show: /home/ubuntu/kaapana/.venv/bin/python3

# Reinstall requirements
cd ~/kaapana/build-scripts
python3 -m pip install --upgrade pip
python3 -m pip install -r requirements.txt

# Verify key packages installed
pip list | grep -E "PyYAML|jinja2|docker"

# Restart build:
python3 start_build.py --config build-config-ecr.yaml --build-only --parallel 4
```

---

## Build Complete Checklist

Before proceeding to deployment, verify:

- [x] Build process completed without errors
- [x] 90+ Docker images created (check: `docker images | wc -l`)
- [x] Helm charts generated in `build-scripts/builds/`
- [x] `kaapana-platform-*.tgz` exists
- [x] `server_installation.sh` script exists
- [x] `deploy_platform.sh` script exists
- [x] Sufficient disk space remaining (50GB+)
- [x] All images tagged with `local-only/*`

**If pushing to ECR:**
- [x] ECR repository created (via Terraform)
- [x] AWS CLI configured with appropriate permissions
- [x] Docker authenticated with ECR
- [x] All 90+ images pushed to ECR
- [x] Test pull from ECR successful

---

## Step 8: Build and Push Images to ECR (Recommended)

**This step is recommended for production deployments.** Building and pushing to ECR provides:
- Centralized image storage in AWS
- Version control and rollback capabilities
- Image scanning for security vulnerabilities
- Easy sharing across multiple AWS accounts/regions
- Integration with AWS deployment tools

### Prerequisites

**ECR repository must exist and be configured:**
```bash
# If using Terraform deployment from this project:
cd /d/repos/upwork/kaapana/aws-infra
terraform apply

# Get ECR repository URL
terraform output -raw ecr_repository_url
# Expected: 223271671018.dkr.ecr.us-east-1.amazonaws.com/kaapana-poc-poc
```

### Configure EC2 Instance for ECR

**AWS CLI Setup (already completed in Step 2):**
```bash
# Install AWS CLI (if not already installed)
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Verify AWS credentials (should work via IAM role)
aws sts get-caller-identity
```

**Docker Login to ECR:**
```bash
# Login to ECR using IAM role (no AWS credentials needed)
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 223271671018.dkr.ecr.us-east-1.amazonaws.com
```

### Update Build Configuration for ECR

**Create `build-config-ecr.yaml`:**

```yaml
# build-config-ecr.yaml - ECR Build Configuration with Containers AND Charts
# This config builds ALL containers and Helm charts, pushing containers to ECR
# Note: Helm charts are pushed to ECR as OCI artifacts (ECR supports OCI-compatible charts)

# Build Options
http_proxy: ''
default_registry: '223271671018.dkr.ecr.us-east-1.amazonaws.com/kaapana-poc-poc'
registry_username: 'AWS'
registry_password: ''
container_engine: 'docker'
enable_build_kit: true
log_level: 'INFO'
build_only: false                      # Build AND push to ECR
enable_linting: false                  # Disable for faster build
exit_on_error: false                   # Continue even if some images fail
platform_filter: ''                    # EMPTY = build all platforms (IMPORTANT!)
parallel_processes: 4

# Components to Build - ALL REQUIRED
components:
  base:
    enabled: true
  services:
    enabled: true
  operators:
    enabled: true
  workflows:
    enabled: true
  applications:
    enabled: true

# Build Cache - helps speed up rebuilds
cache:
  enabled: true

# Output
output_dir: './builds'

# Logging
log_level: 'INFO'

# Build Installer Scripts
build_installer_scripts: true

# Create Offline Installation (optional - requires ~80GB additional space)
create_offline_installation: false
```

**⚠️ IMPORTANT Configuration Notes:**

1. **platform_filter: ''** (empty string in single quotes)
   - MUST be empty or removed to build ALL platforms
   - If set to 'kaapana-admin-chart', only that chart is built (skips all containers)

2. **registry_password: ''** (empty in config)
   - Password will be provided via command line during build
   - Never hardcode credentials in config files

3. **Helm Charts in ECR:**
   - ECR supports OCI-compatible Helm charts (v2.8.0+)
   - Helm charts will be pushed as OCI artifacts
   - Charts are stored in the same ECR repository alongside container images

4. **YAML Format:**
   - Use single quotes for empty strings: `''` (not empty or None)
   - Use single quotes for string values to avoid parsing issues
   - No special characters in unquoted values

### Authenticate with ECR

**Method A: Using AWS CLI with EC2 IAM Role (Recommended for AWS)**

```bash
# Install AWS CLI if not present
sudo apt update && sudo apt install -y awscli

# Verify AWS credentials are available (via IAM role)
aws sts get-caller-identity
# Should return your account and role information

# Get login token and authenticate Docker
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 223271671018.dkr.ecr.us-east-1.amazonaws.com

# Verify Docker authentication
docker info | grep Registry
# Should show your ECR registry

# Authenticate Helm for ECR (supports OCI-compatible charts in v2.8.0+)
aws ecr get-login-password --region us-east-1 | helm registry login --username AWS --password-stdin 223271671018.dkr.ecr.us-east-1.amazonaws.com
```

**Method B: Using AWS Access Keys (if IAM role not available)**

```bash
# Configure AWS credentials
aws configure
# Enter AWS Access Key ID
# Enter AWS Secret Access Key
# Enter default region: us-east-1
# Enter default output format: json

# Login to ECR
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 223271671018.dkr.ecr.us-east-1.amazonaws.com

# Verify login
docker login status
```

**Troubleshooting ECR Authentication:**

```bash
# If getting "access denied" errors:
# 1. Verify credentials
aws sts get-caller-identity

# 2. Re-authenticate
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 223271671018.dkr.ecr.us-east-1.amazonaws.com

# 3. Check IAM role permissions (if using role):
# Ensure role has these permissions:
# - ecr:GetAuthorizationToken
# - ecr:InitiateLayerUpload
# - ecr:UploadLayerPart
# - ecr:CompleteLayerUpload
# - ecr:PutImage
# - ecr:BatchGetImage (for pulling)

# 4. Check if repository exists
aws ecr describe-repositories --repository-names kaapana-poc-poc --region us-east-1
```

### Push Images to ECR

**Recommended: Build and Push in One Step with Proper ECR Credentials**

```bash
# Step 0: Ensure prerequisites
# - Docker and Helm authenticated with ECR (see above)
# - Virtual environment activated
# - Build config file created (build-config-ecr.yaml)

cd ~/kaapana
source ~/.venv/bin/activate
cd build-scripts

# Step 1: Clean old build artifacts (optional but recommended)
rm -rf ./build/
rm -f ./build.log

# Step 2: Get ECR login password
ECR_PASSWORD=$(aws ecr get-login-password --region us-east-1)

# Step 3: Start build with ECR credentials
# This will:
# - Build all 90+ Docker containers
# - Generate Helm charts
# - Push containers to ECR
# - Push charts to ECR as OCI artifacts

python3 start_build.py \
  --config build-config-ecr.yaml \
  --username AWS \
  --password "$ECR_PASSWORD" \
  --parallel 4 | tee build.log

# The build will take 1-2 hours depending on hardware
```

**Alternative: Build Locally, Then Push (if you prefer two steps)**

```bash
# Step 1: Build locally without pushing
cd ~/kaapana
source ~/.venv/bin/activate
cd build-scripts

python3 start_build.py \
  --config build-config-ecr.yaml \
  --build-only \
  --parallel 4 | tee build.log

# Step 2: After build completes, push to ECR
# Note: Charts are now in ./build/ directory
# Push containers using ECR credentials from Step 2 above

cd ~/kaapana

# Tag and push each container
IMAGES=$(docker images --format "{{.Repository}}:{{.Tag}}" | grep "223271671018.dkr.ecr")

for IMAGE in $IMAGES; do
  docker push "$IMAGE"
  echo "Pushed: $IMAGE"
done

# Push Helm charts as OCI artifacts
helm registry login --username AWS --password "$ECR_PASSWORD" 223271671018.dkr.ecr.us-east-1.amazonaws.com

# Charts are in build-scripts/build/
# For each chart, push to ECR as OCI artifact
```

**Troubleshooting Push Issues:**

```bash
# If push fails with "no basic auth credentials":
# Re-authenticate:
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 223271671018.dkr.ecr.us-east-1.amazonaws.com

# If push fails with "repository does not exist":
# Verify repository exists
aws ecr describe-repositories --repository-names kaapana-poc-poc --region us-east-1

# If repository doesn't exist, create it:
aws ecr create-repository --repository-name kaapana-poc-poc --region us-east-1 --image-scanning-configuration scanOnPush=true

# If you get network timeouts:
export DOCKER_CLIENT_TIMEOUT=120
export COMPOSE_HTTP_TIMEOUT=120
# Then retry push or build

# Check network connectivity to ECR:
curl -I https://223271671018.dkr.ecr.us-east-1.amazonaws.com
```

### Verify ECR Push

**Check images in ECR:**
```bash
# List images in ECR repository
aws ecr list-images --repository-name kaapana-poc-poc --region <region>

# Count images
aws ecr list-images --repository-name kaapana-poc-poc --region <region> --query 'imageIds' --output text | wc -l

# Should show: 90+ images
```

**Expected output:**
```json
{
    "imageIds": [
        {"imageTag": "0.3.0", "imageDigest": "sha256:..."},
        {"imageTag": "latest", "imageDigest": "sha256:..."},
        ...
    ]
}
```

### Test ECR Image Pull

**Verify images can be pulled:**
```bash
# Pull a test image
docker pull <account_id>.dkr.ecr.<region>.amazonaws.com/kaapana-poc-poc/base-python-cpu:0.3.0

# List pulled images
docker images | grep kaapana-poc-poc
```

### Troubleshooting ECR Issues

**"no basic auth credentials" error:**
```bash
# Re-authenticate with ECR
aws ecr get-login-password --region <region> | docker login --username AWS --password-stdin <account_id>.dkr.ecr.<region>.amazonaws.com
```

**"repository does not exist" error:**
```bash
# Create repository manually
aws ecr create-repository --repository-name kaapana-poc-poc --region <region> --image-scanning-configuration scanOnPush=true
```

**"access denied" error:**
```bash
# Check IAM permissions
aws sts get-caller-identity

# Ensure user/role has:
# - ecr:GetAuthorizationToken
# - ecr:InitiateLayerUpload
# - ecr:UploadLayerPart
# - ecr:CompleteLayerUpload
# - ecr:PutImage
```

**Network timeouts:**
```bash
# Increase timeout and retry
export DOCKER_CLIENT_TIMEOUT=120
export COMPOSE_HTTP_TIMEOUT=120

# Use parallel processes 2 instead of 4 for stability
python3 start_build.py --config build-config.yaml --parallel 2
```

---

## Next Steps

✅ **Build complete!**

You have successfully:
- Built 90+ Docker containers
- Pushed all containers to AWS ECR
- Generated Helm charts locally
- Created deployment scripts

### Scenario A: Built with ECR (Most Common)

**Recommended Next Steps:**
1. **Deploy Server:** [05-server-installation.md](05-server-installation.md)
   - Install Kubernetes on deployment server
   - Configure access to ECR repository
   
2. **Deploy Platform:** [06-platform-deployment.md](06-platform-deployment.md)
   - Deploy Kaapana using Helm charts
   - Configure services and networking
   - Verify platform is running

### Scenario B: Built Locally (and need to transfer)

If you built on a separate machine from your deployment server:
1. **Transfer Artifacts:** [04-artifact-transfer.md](04-artifact-transfer.md)
   - Transfer Docker images to deployment server
   - Transfer Helm charts to deployment server
   
2. **Deploy Server:** [05-server-installation.md](05-server-installation.md)
3. **Deploy Platform:** [06-platform-deployment.md](06-platform-deployment.md)

### Quick Cleanup (Optional)

```bash
# Optional: Clean build cache to free space for deployment
docker builder prune -af

# Free up additional space if needed
df -h /  # Check current usage

# Optional: Archive Helm charts for backup
tar -czf ~/kaapana-charts-backup.tar.gz ~/kaapana/build-scripts/build/*.tgz
```

---

## Quick Reference

### Pre-Build
```bash
# Navigate to build scripts
cd ~/kaapana/build-scripts

# Activate venv
source ~/kaapana/.venv/bin/activate

# Verify disk space (CRITICAL - need 200GB+)
df -h /

# Verify Docker works
docker run hello-world

# Verify ECR access
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 223271671018.dkr.ecr.us-east-1.amazonaws.com
```

### Build (Using Screen - Recommended)
```bash
# Start screen session
screen -S kaapana-build

# Inside screen: build with ECR push
cd ~/kaapana && source ~/.venv/bin/activate && cd build-scripts
ECR_PASSWORD=$(aws ecr get-login-password --region us-east-1)
python3 start_build.py --config build-config-ecr.yaml --username AWS --password "$ECR_PASSWORD" --parallel 4

# Detach from screen: Ctrl+A then D
# Reattach later: screen -r kaapana-build
```

### Monitor Build
```bash
# From separate SSH session, tail build logs
tail -f ~/kaapana/build-scripts/build.log

# Watch disk space (CRITICAL - watch for 100%)
watch -n 60 'df -h / | tail -1'

# Count Docker images being built
docker images | wc -l

# Check for errors
grep "ERROR\|FAILED" ~/kaapana/build-scripts/build.log
```

### After Build Completion
```bash
# Count images
docker images | grep "223271671018.dkr.ecr" | wc -l

# List ECR images
aws ecr list-images --repository-name kaapana-poc-poc --region us-east-1

# Check Helm charts
find ~/kaapana/build-scripts/build/ -name "*.tgz" | wc -l

# Verify build log for success
tail -100 ~/kaapana/build-scripts/build.log | grep -i "success\|completed"
```

### Troubleshooting Quick Commands
```bash
# Docker permission denied
sudo usermod -aG docker $USER && newgrp docker

# Out of disk space - expand volume
# 1. AWS Console → Modify Volume to 300GB
# 2. sudo growpart /dev/nvme0n1 1 && sudo resize2fs /dev/nvme0n1p1

# YAML config errors
python3 -c "import yaml; yaml.safe_load(open('build-config-ecr.yaml'))" && echo "✓ Valid"

# Build hangs - check if process running
ps aux | grep start_build.py

# Kill hung build (in screen)
# Ctrl+C or in another session: screen -S kaapana-build -X quit

# Re-authenticate with ECR
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 223271671018.dkr.ecr.us-east-1.amazonaws.com

# Check Docker/Helm ECR access
docker info | grep Registry
helm registry list
```

---

**Document Status:** ✅ Complete  
**Next Document:** 04-artifact-transfer.md OR 05-server-installation.md
