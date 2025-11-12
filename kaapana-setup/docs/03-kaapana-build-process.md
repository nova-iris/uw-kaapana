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

## Step 2: Pre-Build Verification

### Verify Configuration
```bash
# Ensure in build-scripts directory
pwd
# Should show: /home/ubuntu/kaapana-build/kaapana/build-scripts

# Verify config file exists
ls -la build-config.yaml

# Check Python environment
which python3
# Should show: /home/ubuntu/kaapana-build/kaapana-venv/bin/python3

# Test build script accessibility
python3 start_build.py --help
```

**Expected output:**
```
Usage: start_build.py [OPTIONS]

Options:
  --config PATH          Build configuration file
  --registry-url TEXT    Container registry URL
  --username TEXT        Registry username
  --password TEXT        Registry password
  --build-only          Build without pushing
  --parallel INTEGER     Parallel processes
  --help                Show this message and exit.
```

### Check System Resources
```bash
# Check disk space (need 200GB+ free)
df -h /
# Should show 200GB+ available

# Check RAM
free -h
# Should show 16GB+ total

# Check CPU
nproc
# Should show 8+

# Check Docker
docker info | grep "Docker Root Dir"
docker images  # Should be empty or minimal
```

---

## Step 3: Start Build Process

### Initiate Build

**⚠️ Important:** The build takes 1-2 hours. Use `screen` or `tmux` to keep running if SSH disconnects.

**Option A: Direct execution (simpler but risky):**
```bash
# Activate venv
cd ~/kaapana-build
source kaapana-venv/bin/activate
cd kaapana/build-scripts

# Start build
python3 start_build.py \
  --config build-config.yaml \
  --build-only \
  --parallel 4 | tee build.log
```

**Option B: Using screen (recommended):**
```bash
# Install screen
sudo apt install -y screen

# Start screen session
screen -S kaapana-build

# Inside screen: activate venv and build
cd ~/kaapana-build
source kaapana-venv/bin/activate
cd kaapana/build-scripts

python3 start_build.py \
  --config build-config.yaml \
  --build-only \
  --parallel 4 | tee build.log
```

**Detach from screen:** Press `Ctrl+A` then `D`

**Reattach to screen:**
```bash
screen -r kaapana-build
```

---

## Step 4: Monitor Build Progress

### Check Build Logs

**If using screen:**
```bash
# Reattach to screen
screen -r kaapana-build

# Or tail the log file from another terminal
tail -f ~/kaapana-build/kaapana/build-scripts/build.log
```

**Expected log output:**
```
[INFO] Starting Kaapana build process...
[INFO] Build configuration loaded: build-config.yaml
[INFO] Build mode: local (no registry push)
[INFO] Parallel processes: 4
[INFO] Starting component: base
[INFO] Building base-python-cpu...
[INFO] Building base-python-gpu...
[INFO] Starting component: services
[INFO] Building dcm4chee-arc...
[INFO] Building airflow...
[INFO] Building opensearch...
... (continues)
```

### Monitor System Resources

**In a separate SSH session:**
```bash
# Watch CPU and memory
htop

# Or use top
top

# Watch disk space
watch -n 60 df -h

# Watch Docker images
watch -n 60 "docker images | wc -l"
```

### Expected Build Timeline

| Phase | Duration | Description |
|-------|----------|-------------|
| Base Images | 10-15 min | Python, CUDA base images |
| Services | 30-40 min | dcm4chee, Airflow, OpenSearch, etc. |
| Operators | 15-20 min | Airflow operators for workflows |
| Applications | 10-15 min | OHIF viewer, admin tools |
| Helm Charts | 5-10 min | Deployment chart generation |
| **Total** | **1-2 hours** | Varies by hardware/network |

---

## Step 5: Verify Build Completion

### Check Build Status

**Build completion indicators:**
```bash
# Check final log output
tail -n 50 ~/kaapana-build/kaapana/build-scripts/build.log

# Should show:
[INFO] Build completed successfully!
[INFO] Total images built: 90+
[INFO] Build artifacts: ./builds/
[INFO] Helm charts: ./builds/kaapana-platform-*.tgz
```

### Verify Docker Images
```bash
# Count images
docker images | wc -l
# Should show: 90+ images

# List Kaapana images
docker images | grep -E "local-only|kaapana"

# Check image sizes
docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}" | head -20
```

**Expected images include:**
```
local-only/base-python-cpu          0.3.0    800MB
local-only/base-python-gpu          0.3.0    3.5GB
local-only/dcm4chee-arc             0.3.0    1.2GB
local-only/airflow                  0.3.0    1.5GB
local-only/opensearch               0.3.0    950MB
local-only/minio                    0.3.0    280MB
local-only/keycloak                 0.3.0    650MB
local-only/ohif-viewer              0.3.0    450MB
... (90+ total)
```

### Verify Helm Charts
```bash
# Check build output directory
ls -lh ~/kaapana-build/kaapana/build-scripts/builds/

# Should contain:
# - kaapana-platform-*.tgz (main platform chart)
# - kaapana-admin-*.tgz (admin chart)
# - Various service charts

# List Helm charts
find ~/kaapana-build/kaapana/build-scripts/builds/ -name "*.tgz"
```

### Verify Deployment Scripts
```bash
# Check for deployment scripts
ls -la ~/kaapana-build/kaapana/server-installation/
ls -la ~/kaapana-build/kaapana/platforms/

# Key files:
# - server-installation/server_installation.sh
# - platforms/deploy_platform.sh
# - platforms/kaapana-platform-chart/
```

---

## Step 6: Check Disk Usage

```bash
# Check total disk usage
df -h

# Check Docker disk usage
docker system df

# Should show something like:
# TYPE            TOTAL     ACTIVE    SIZE      RECLAIMABLE
# Images          90        90        85GB      0B (0%)
# Containers      0         0         0B        0B
# Local Volumes   2         0         1.2GB     1.2GB (100%)
# Build Cache     120       0         15GB      15GB (100%)
```

**Optional: Clean build cache to free space:**
```bash
# Remove build cache (safe after successful build)
docker builder prune -af

# Check space saved
df -h
```

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
# Add user to docker group
sudo usermod -aG docker $USER
newgrp docker

# Test Docker
docker run --rm hello-world

# Restart build
cd ~/kaapana-build/kaapana/build-scripts
source ~/kaapana-build/kaapana-venv/bin/activate
python3 start_build.py --config build-config.yaml --build-only --parallel 4
```

### Build fails: "Out of disk space"
```bash
# Check space
df -h

# Clean Docker cache
docker system prune -af

# If AWS: expand volume
# 1. AWS Console → EC2 → Volumes → Modify Volume (increase to 500GB)
# 2. On server:
sudo growpart /dev/nvme0n1 1
sudo resize2fs /dev/nvme0n1p1
df -h  # Verify

# Restart build
```

### Build fails on specific image
```bash
# Check error in log
tail -100 ~/kaapana-build/kaapana/build-scripts/build.log

# Common issues:
# - Network timeout: Retry build
# - Missing dependency: Check base image built successfully
# - Syntax error: Check Kaapana version compatibility

# Build single image for debugging:
cd ~/kaapana-build/kaapana/services/<service-name>
docker build -t test-image .
```

### Build hangs
```bash
# Check system resources
htop
df -h

# Check Docker processes
docker ps -a

# Check build log
tail -f ~/kaapana-build/kaapana/build-scripts/build.log

# If stuck, kill and restart:
# Ctrl+C (if in screen: Ctrl+A then K)
python3 start_build.py --config build-config.yaml --build-only --parallel 2
# (Reduce parallel processes if resource constrained)
```

### Python import errors
```bash
# Ensure venv activated
source ~/kaapana-build/kaapana-venv/bin/activate
which python3

# Reinstall requirements
pip install -r requirements.txt

# Restart build
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

---

## Next Steps

✅ **Build complete!**

**Scenario A: Built on AWS deployment server:**
- **Next:** [05-server-installation.md](05-server-installation.md)
- Skip artifact transfer (already on deployment machine)

**Scenario B: Built on separate machine:**
- **Next:** [04-artifact-transfer.md](04-artifact-transfer.md)
- Transfer images and charts to AWS deployment server

---

## Quick Reference

**Check build status:**
```bash
screen -r kaapana-build  # If using screen
tail -f ~/kaapana-build/kaapana/build-scripts/build.log
```

**Count images:**
```bash
docker images | wc -l
```

**Check disk usage:**
```bash
df -h
docker system df
```

**Restart build if interrupted:**
```bash
cd ~/kaapana-build
source kaapana-venv/bin/activate
cd kaapana/build-scripts
python3 start_build.py --config build-config.yaml --build-only --parallel 4
```

---

**Document Status:** ✅ Complete  
**Next Document:** 04-artifact-transfer.md OR 05-server-installation.md
