# 06 - Platform Deployment

**Phase:** 3 - Deploy
**Duration:** 30-45 minutes (mostly automated)
**Prerequisite:** 04-server-installation.md completed

---

## Overview

This guide deploys the Kaapana platform using the `deploy_platform.sh` script. You have two deployment options:

- **Option 1: Build from Source** - Use images built locally in [03-kaapana-build-process.md](03-kaapana-build-process.md)
- **Option 2: Pre-built Images** - Use pre-built images from GitLab registry

The deployment includes:
- dcm4chee (PACS server)
- Airflow (workflow orchestration)
- OpenSearch (metadata indexing)
- MinIO (object storage)
- Keycloak (authentication)
- OHIF viewer (DICOM viewing)
- Kaapana UI (management interface)

---

## Choose Your Deployment Option

### Option 1: Build from Source
- **Prerequisites**: Completed [03-kaapana-build-process.md](03-kaapana-build-process.md)
- **Script Location**: `~/kaapana/build/kaapana-admin-chart/deploy_platform.sh`
- **Registry**: Local images built during build process
- **Duration**: 30-45 minutes

### Option 2: Pre-built Images
- **Prerequisites**: GitLab registry credentials
- **Script Location**: `~/uw-kaapana/kaapana-setup/build/deploy_platform.sh`
- **Registry**: GitLab container registry
- **Duration**: 20-30 minutes (faster, no building required)

**⚠️ Important**: Choose only ONE option below based on your setup.

---

## Prerequisites Check

```bash
# SSH to AWS server
ssh -i kaapana-poc-key.pem ubuntu@$ELASTIC_IP

# Verify Kubernetes ready
kubectl get nodes
# Expected: 1 Ready node

# Check disk space
df -h /
# Should show: 80GB+ free
```

---

## Step 1: Locate and Configure Deployment Script

### Option 1: Build from Source Script

```bash
# Setup Deployment Script
export DEPLOY_SCRIPT=~/kaapana/build/kaapana-admin-chart/deploy_platform.sh
ls -la $DEPLOY_SCRIPT
```

### Option 2: Pre-built Images Script

```bash
# Verify script exists
export DEPLOY_SCRIPT=~/uw-kaapana/kaapana-setup/build/deploy_platform.sh
ls -la $DEPLOY_SCRIPT
```

### Configure GitLab Registry (Option 2 Only)

If using pre-built images, configure GitLab registry credentials:

```bash
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

---

## Step 2: Configure Deployment

### Review Deploy Script (Optional)

```bash
# View script to understand deployment process
less $DEPLOY_SCRIPT
```

**Key variables can be edited in the script:**
- `CONTAINER_REGISTRY_URL`: Registry URL (auto-set from build or GitLab)
- `DEV_MODE`: Development mode (default: true)
- `GPU_SUPPORT`: Enable GPU support (default: false)
- `Data directories`: FAST_DATA_DIR, SLOW_DATA_DIR

**Press `Q` to exit**

---

## Step 3: Run Deployment Script

```bash
# Make script executable
chmod +x $DEPLOY_SCRIPT

# Run deployment (script will prompt for inputs)
$DEPLOY_SCRIPT
```

### Deployment Inputs

The script will ask for:

```bash
# 1. Server domain (FQDN) or IP address
# Example: 3.94.145.230 (for IP-based access)
# or: kaapana.example.com (for FQDN)
# Keep in mind: valid SSL certificates only work with FQDN

# 2. Enable GPU support? (y/n)
# Answer: n (unless you have Nvidia GPU with drivers installed)

# 3. Container registry credentials (IMPORTANT for Option 2)
# For Option 1 (build from source): Leave blank, uses local images
# For Option 2 (pre-built images): Enter GitLab registry credentials:
#   - Registry URL: registry.gitlab.com
#   - Username: Your GitLab username
#   - Password: Your GitLab access token with registry permissions
```


### Migration Job Timeout Issue

**Common Problem:** During deployment, you may encounter a migration job timeout:

```
Waiting for migration job migration to complete...
Migration job did not complete within 180s
```

**Solution 1: Increase Timeout Value (Recommended)**
```bash
# Edit the deploy_platform.sh script to increase timeout
nano $DEPLOY_SCRIPT

# Find the migration timeout value (usually 180)
# Change to a higher value, like 600 (10 minutes):
MIGRATION_TIMEOUT=600

# Save and exit (Ctrl+X, Y, Enter)
```

**Solution 2: Rerun Deployment Script**
```bash
# If timeout occurs, simply rerun the script
$DEPLOY_SCRIPT
# The script will resume from where it left off
```

**Why this happens:** Migration jobs can take longer on slower systems or with large datasets. Increasing the timeout prevents the script from failing prematurely.

### Monitor Progress

```bash
# Watch pod creation
watch "kubectl get pods -A"
```

---

## Step 4: Verify Deployment

### Check Deployment Status

```bash
# Check pods are running (Kaapana uses multiple namespaces)
microk8s kubectl get pods -A

# Expected: All pods with STATUS=Running and READY=1/1
# This may take 10-30 minutes depending on image pull speed

# Check Helm releases
helm list -n default
# Should show: kaapana-platform-chart, kaapana-admin-chart deployed
```

---

## Step 5: Access Kaapana UI

### Get Access URL

```bash
# For IP-based access (POC)
echo "Access Kaapana at: http://$ELASTIC_IP"

# Or if using domain (production)
echo "Access Kaapana at: http://kaapana.example.com"
```

### Login to Kaapana

**Default credentials:**
- Username: `kaapana`
- Password: `kaapana`

**Expected UI:**
- Kaapana welcome page
- Navigation sidebar with links to:
  - OHIF Viewer (medical images)
  - Airflow (workflows)
  - Admin interfaces
  - Data upload

---

## Next Steps

✅ **Platform deployed and accessible!**

**Next:** [07-data-upload-testing.md](07-data-upload-testing.md)

You'll upload DICOM data and verify the platform can store and display medical images.

---

## Reference Documentation

Official Kaapana Deployment:
- https://kaapana.readthedocs.io/en/latest/installation_guide/deployment.html

---