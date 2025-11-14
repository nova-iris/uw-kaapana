# 06 - Platform Deployment

**Phase:** 3 - Deploy  
**Duration:** 30-45 minutes (mostly automated)  
**Prerequisite:** 05-server-installation.md completed

---

## Overview

This guide deploys the Kaapana platform using the `deploy_platform.sh` script. The deployment includes:
- dcm4chee (PACS server)
- Airflow (workflow orchestration)
- OpenSearch (metadata indexing)
- MinIO (object storage)
- Keycloak (authentication)
- OHIF viewer (DICOM viewing)
- Kaapana UI (management interface)

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

## Step 1: Locate Deployment Script

### Find Kaapana Directory

The platform is deployed using the script `deploy_platform.sh`, which is created during the build-process at `kaapana/build/kaapana-admin-chart/deploy_platform.sh`.

**Verify script exists:**
```bash
ls -la ~/kaapana/build/kaapana-admin-chart/deploy_platform.sh

# Should show executable deployment script
```

---

## Step 2: Configure Deployment

### Review Deploy Script (Optional)

```bash
# View script to understand deployment process
less ~/kaapana/build/kaapana-admin-chart/deploy_platform.sh

# Key variables can be edited in the script:
# - CONTAINER_REGISTRY_URL: Registry URL (auto-set from build)
# - DEV_MODE: Development mode (default: true)
# - GPU_SUPPORT: Enable GPU support (default: false)
# - Data directories: FAST_DATA_DIR, SLOW_DATA_DIR
```

**Press `Q` to exit**

---

## Step 3: Run Deployment Script

### Execute Installation

```bash
# Inside screen session:
cd ~/kaapana/build/kaapana-admin-chart

# Make script executable
chmod +x deploy_platform.sh

# Run deployment (script will prompt for inputs)
./deploy_platform.sh
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

# 3. Container registry credentials (if using private registry)
# If using local MicroK8s: leave blank and use defaults
```

### Monitor Progress

```bash
# Watch pod creation
watch "kubectl get pods -n kaapana"

# Check deployment log
tail -f $KAAPANA_DIR/platforms/deploy.log
```

**Expected deployment output:**
```
[INFO] Starting platform deployment...
[INFO] Loading deployment configuration...
[INFO] Creating Kubernetes namespaces...
[INFO] Deploying Helm charts...
[INFO] Waiting for pods to be ready...
[INFO] Deployment completed successfully!
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

### Wait for All Pods Ready

```bash
# Monitor pod readiness
watch kubectl get pods -n kaapana

# Once all pods show "1/1 Running", deployment is complete
# This can take 10-30 minutes on first run
```

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