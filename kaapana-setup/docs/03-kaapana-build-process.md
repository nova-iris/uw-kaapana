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

## Step 1: Configure Build Settings

### Configure Registry and Build Configuration

**GitLab Registry (Recommended for POC)**
```bash
# Set environment variables (add to ~/.bashrc for persistence)
export REGISTRY_URL="registry.gitlab.com"
export REGISTRY_USERNAME="<gitlab-username>"
export REGISTRY_PROJECT="<gitlab-project-name>"
export REGISTRY_FULL="${REGISTRY_URL}/${REGISTRY_USERNAME}/${REGISTRY_PROJECT}"
export GITLAB_TOKEN="<gitlab-personal-access-token>"

# Login to GitLab registry
echo "$GITLAB_TOKEN" | docker login $REGISTRY_URL --username $REGISTRY_USERNAME --password-stdin
# Should show: Login Succeeded

# Helm login
helm registry login $REGISTRY_URL --username $REGISTRY_USERNAME --password $GITLAB_TOKEN
# Should show: Login Succeeded
```

### Configure Build Configuration

```bash
# Navigate to Build Scripts Directory
cd ~/kaapana
source .venv/bin/activate
cd build-scripts

# Copy template and update for gitlab registry:
cp build-config-template.yaml build-config-gitlab.yaml
```

**Configuration updates for GitLab registry:**
```yaml

# Registry Settings
default_registry: 'registry.gitlab.com/<gitlab-username>/<gitlab-project-name>'

# Build Settings
build_only: false                      # Build AND push to registry
parallel_processes: 4                  # Use 4 parallel processes

# Enable all components
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
```

---

### Pre-Build Checklist (CRITICAL - Do This Before Starting)

Before running the build, verify all prerequisites:

```bash
# Navigate to build scripts directory
cd ~/kaapana/build-scripts

# 1. Check disk space (CRITICAL - need 200GB+ free)
df -h /
df -h /var/snap/docker/common/
# MUST show: 200GB+ available (500GB recommended)
# If less than 200GB, STOP and expand volume first!

# 2. Verify YAML is valid
python3 -c "import yaml; yaml.safe_load(open('build-config-gitlab.yaml'))" && echo "✓ YAML valid" || echo "✗ YAML invalid"

# 3. Check system resources
echo "CPU: $(nproc) cores"
echo "RAM: $(free -h | grep Mem | awk '{print $2}')"
echo "Available disk: $(df -h / | tail -1 | awk '{print $4}')"

# 4. Verify internet connectivity
ping -c 2 8.8.8.8
```

**If any check fails, DO NOT proceed. Fix the issue first (see Troubleshooting section).**

---

## Step 2: Start Build Process

**⚠️ Important Build Notes:**
- The build takes approximately 1 hour depending on hardware
- **Images are pushed to GitLab registry AS THEY ARE BUILT** (not at the end)
- Requires 200GB+ free disk space

### Start the Build

```bash
# Navigate to build scripts directory
cd ~/kaapana/build-scripts

# Start build with GitLab registry
./start_build.py -u $REGISTRY_USERNAME -p $GITLAB_TOKEN --config build-config-gitlab.yaml --parallel 4

# Build is now running! Images will be pushed to GitLab as they complete.
```
---

## Step 3: Monitor Build Progress

### Check Build Logs

```bash
# Monitor build logs
tail -f ~/kaapana/build/build.log

# Or check recent logs
tail -50 ~/kaapana/build/build.log
```

### Build Results

**Build logs and results are available at:**
```bash
# Build artifacts location
ls -la ~/kaapana/build/

# Check build completion
tail -20 ~/kaapana/build/build.log | grep -i "complete\|success\|finish"
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
[INFO] Build configuration loaded: build-config-gitlab.yaml
[INFO] Registry: registry.gitlab.com/trongtruong2509/kaapana-registry
[INFO] Build mode: build and push to GitLab registry
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

### Expected Build Timeline

| Phase | Duration | Description |
|-------|----------|-------------|
| Base Images | 10-15 min | Python, CUDA base images (~2-3GB) |
| Services | 30-40 min | dcm4chee, Airflow, OpenSearch, etc. (~30-40GB) |
| Operators | 15-20 min | Airflow operators for workflows (~10-15GB) |
| Applications | 10-15 min | OHIF viewer, admin tools (~5-10GB) |
| Helm Charts | 5-10 min | Deployment chart generation |
| GitLab Push | 20-30 min | Push all images to GitLab (depends on network) |
| **Total** | **1-2.5 hours** | Varies by hardware/network/disk performance |

---

## Step 4: Verify Build Completion

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

# List only Kaapana images pushed to registry (using environment variable)
docker images | grep "$REGISTRY_URL"

# Check image sizes
docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}" | grep "$(basename $REGISTRY_URL)" | head -20
```

**Expected images include (GitLab example):**
```
registry.gitlab.com/trongtruong2509/kaapana-registry/base-python-cpu          0.5.2    800MB
registry.gitlab.com/trongtruong2509/kaapana-registry/base-python-gpu          0.5.2    3.5GB
registry.gitlab.com/trongtruong2509/kaapana-registry/dcm4chee-arc             0.5.2    1.2GB
registry.gitlab.com/trongtruong2509/kaapana-registry/airflow                  0.5.2    1.5GB
registry.gitlab.com/trongtruong2509/kaapana-registry/opensearch               0.5.2    950MB
registry.gitlab.com/trongtruong2509/kaapana-registry/minio                    0.5.2    280MB
registry.gitlab.com/trongtruong2509/kaapana-registry/keycloak                 0.5.2    650MB
registry.gitlab.com/trongtruong2509/kaapana-registry/ohif-viewer              0.5.2    450MB
... (90+ total)
```

### Verify Registry Push

```bash
# For GitLab registry: Check via Docker images
if [[ "$REGISTRY_URL" == *"gitlab.com"* ]]; then
  echo "GitLab registry images:"
  docker images | grep "$REGISTRY_URL" | wc -l
  docker images --format "table {{.Repository}}\t{{.Tag}}" | grep "$REGISTRY_URL"
fi

# List GitLab registry images
echo "GitLab registry images:"
docker images | grep "$REGISTRY_URL"
GITLAB_COUNT=$(docker images | grep "$REGISTRY_URL" | wc -l)
echo "Total GitLab images: $GITLAB_COUNT"

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

## Step 5: Create Build Archive (Optional)

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

## Reference Documentation

This guide is based on the official Kaapana documentation:
- **Kaapana Build Guide:** https://kaapana.readthedocs.io/en/latest/installation_guide/build.html