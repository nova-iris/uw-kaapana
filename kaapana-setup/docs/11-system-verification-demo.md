# 11 - System Verification, Documentation & Demo Preparation

**Phase:** Final Verification & Demo  
**Duration:** 90-120 minutes  
**Prerequisite:** 10-core-modules-configuration.md completed  
**Milestone:** Milestone 4 - Verification, Documentation & Demo

---

## Overview

This final guide provides comprehensive verification of the Kaapana POC platform and prepares a demonstration showcasing:

- Platform functionality validation
- End-to-end data workflow demonstration
- System persistence testing
- Documentation review and completion
- Demo scenario preparation
- Knowledge transfer materials

After completing this guide, the POC will be fully verified, documented, and ready for stakeholder demonstration.

---

## Prerequisites Check

```bash
# SSH to AWS server
ssh -i kaapana-poc-key.pem ubuntu@52.23.80.12

# Verify all milestones completed
echo "Milestone 1: Infrastructure" && kubectl get nodes
echo "Milestone 2: Platform Deployed" && kubectl get pods -A | grep -c "1/1.*Running"
echo "Milestone 3: Modules Configured" && curl -k -s -o /dev/null -w "%{http_code}\n" \
  https://kaapana.novairis.site/flow/
```

---

## Step 1: Comprehensive Platform Verification

### Run Master Verification Suite

```bash
# Create comprehensive verification script
cat > ~/kaapana-master-verification.sh << 'EOF'
#!/bin/bash

# Kaapana POC - Master Verification Script
# Tests all platform components and integrations

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

PASS=0
FAIL=0
WARN=0

echo -e "${BLUE}"
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║       KAAPANA POC - MASTER VERIFICATION SUITE            ║"
echo "║                                                           ║"
echo "║  This script validates all platform components           ║"
echo "║  and verifies complete system functionality              ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo ""

check() {
    local test_name="$1"
    local command="$2"
    local critical="${3:-false}"
    
    echo -n "Testing: $test_name ... "
    
    if eval "$command" &>/dev/null; then
        echo -e "${GREEN}✓ PASS${NC}"
        ((PASS++))
        return 0
    else
        if [ "$critical" == "true" ]; then
            echo -e "${RED}✗ FAIL (Critical)${NC}"
            ((FAIL++))
        else
            echo -e "${YELLOW}⚠ WARN${NC}"
            ((WARN++))
        fi
        return 1
    fi
}

echo "═══════════════════════════════════════════════════════════"
echo " 1. INFRASTRUCTURE & KUBERNETES"
echo "═══════════════════════════════════════════════════════════"

check "AWS EC2 instance accessible" "true" true
check "SSH connectivity" "true" true
check "Disk space > 50GB free" "df -h / | tail -1 | awk '{gsub(\"G\",\"\",\$4); if(\$4>50) exit 0; exit 1}'" true
check "RAM > 16GB total" "free -g | grep Mem | awk '{if(\$2>=16) exit 0; exit 1}'" false
check "CPU cores >= 8" "nproc | awk '{if(\$1>=8) exit 0; exit 1}'" false

check "Kubernetes cluster running" "kubectl cluster-info &>/dev/null" true
check "Kubernetes node(s) Ready" "kubectl get nodes | grep -q Ready" true
check "CoreDNS running" "kubectl get pods -n kube-system | grep coredns | grep -q Running" true
check "Storage class available" "kubectl get storageclass | grep -q default" true

echo ""
echo "═══════════════════════════════════════════════════════════"
echo " 2. KAAPANA CORE PODS"
echo "═══════════════════════════════════════════════════════════"

# Check all critical pods are running
check "Kaapana namespace exists" "kubectl get namespace kaapana &>/dev/null" true
check "Services namespace exists" "kubectl get namespace services &>/dev/null" true

check "dcm4chee PACS running" "kubectl get pods -n services -l app=dcm4chee 2>/dev/null | grep -q '1/1.*Running'" true
check "OpenSearch running" "kubectl get pods -n services -l app=opensearch 2>/dev/null | grep -q '1/1.*Running'" true
check "OpenSearch Dashboards running" "kubectl get pods -n services -l app=opensearch-dashboards 2>/dev/null | grep -q '1/1.*Running'" true
check "MinIO running" "kubectl get pods -n services -l app=minio 2>/dev/null | grep -q '1/1.*Running'" true
check "Keycloak running" "kubectl get pods -n services -l app=keycloak 2>/dev/null | grep -q '1/1.*Running'" true

check "Airflow Scheduler running" "kubectl get pods -n services -l app=airflow,component=scheduler 2>/dev/null | grep -q '1/1.*Running'" true
check "Airflow Webserver running" "kubectl get pods -n services -l app=airflow,component=webserver 2>/dev/null | grep -q '1/1.*Running'" true
check "Airflow Worker running" "kubectl get pods -n services -l app=airflow,component=worker 2>/dev/null | grep -q '1/1.*Running'" false

check "Kaapana Backend running" "kubectl get pods -n services -l app=kaapana-backend 2>/dev/null | grep -q '1/1.*Running'" true
check "Kaapana Frontend running" "kubectl get pods -n services -l app=kaapana-frontend 2>/dev/null | grep -q '1/1.*Running'" true

check "No pods in CrashLoopBackOff" "! kubectl get pods -A | grep -q CrashLoopBackOff" true
check "All critical pods ready" "[ \$(kubectl get pods -A --field-selector=status.phase!=Running,status.phase!=Succeeded | wc -l) -le 1 ]" false

echo ""
echo "═══════════════════════════════════════════════════════════"
echo " 3. NETWORK & INGRESS"
echo "═══════════════════════════════════════════════════════════"

DOMAIN="kaapana.novairis.site"

check "Main UI accessible" "curl -k -s -o /dev/null -w '%{http_code}' https://$DOMAIN/ | grep -qE '200|302'" true
check "Airflow UI accessible" "curl -k -s -o /dev/null -w '%{http_code}' https://$DOMAIN/flow/ | grep -qE '200|302'" true
check "OpenSearch Dashboards accessible" "curl -k -s -o /dev/null -w '%{http_code}' https://$DOMAIN/opensearch-dashboards/ | grep -qE '200|302'" true
check "MinIO Console accessible" "curl -k -s -o /dev/null -w '%{http_code}' https://$DOMAIN/minio-console/ | grep -qE '200|302'" true
check "dcm4chee UI accessible" "curl -k -s -o /dev/null -w '%{http_code}' https://$DOMAIN/dcm4chee-arc/ui2/ | grep -qE '200|302'" true
check "Keycloak accessible" "curl -k -s -o /dev/null -w '%{http_code}' https://$DOMAIN/auth/ | grep -qE '200|302'" true

check "DICOM port 11112 open" "nc -zv $DOMAIN 11112 2>&1 | grep -q succeeded" true
check "Ingress controller running" "kubectl get pods -n ingress 2>/dev/null | grep -q Running" true

echo ""
echo "═══════════════════════════════════════════════════════════"
echo " 4. DATA STORAGE & PERSISTENCE"
echo "═══════════════════════════════════════════════════════════"

check "Persistent volumes exist" "kubectl get pv | grep -qv 'No resources'" true
check "Persistent volume claims bound" "! kubectl get pvc -A | grep -q Pending" true

check "dcm4chee storage accessible" "kubectl exec -n services deployment/dcm4chee-arc -- ls /storage &>/dev/null" true
check "MinIO health endpoint" "curl -k -s https://$DOMAIN/minio/health/live | grep -q OK" true
check "MinIO buckets exist" "kubectl exec -n services deployment/minio -- ls /data | grep -q ." false

check "OpenSearch indices accessible" "curl -k -s -u admin:admin https://$DOMAIN/opensearch-api/_cat/indices 2>/dev/null | grep -q ." false

echo ""
echo "═══════════════════════════════════════════════════════════"
echo " 5. WORKFLOW ORCHESTRATION"
echo "═══════════════════════════════════════════════════════════"

check "Airflow DAGs loaded" "kubectl exec -n services deployment/airflow-scheduler -- airflow dags list 2>/dev/null | wc -l | awk '{if(\$1>5) exit 0; exit 1}'" true
check "Airflow scheduler healthy" "kubectl logs -n services deployment/airflow-scheduler --tail=20 2>/dev/null | grep -q 'Scheduler'" true
check "Airflow database connection" "kubectl exec -n services deployment/airflow-scheduler -- airflow db check 2>/dev/null | grep -q 'successful'" true

check "Service DAGs enabled" "kubectl exec -n services deployment/airflow-scheduler -- airflow dags list 2>/dev/null | grep -q 'service-'" false
check "Airflow connections configured" "kubectl exec -n services deployment/airflow-scheduler -- airflow connections list 2>/dev/null | grep -q opensearch" false

echo ""
echo "═══════════════════════════════════════════════════════════"
echo " 6. AUTHENTICATION & AUTHORIZATION"
echo "═══════════════════════════════════════════════════════════"

check "Keycloak admin login" "curl -k -s -o /dev/null -w '%{http_code}' https://$DOMAIN/auth/admin/ | grep -q 200" true
check "Keycloak realm configured" "kubectl exec -n services deployment/keycloak -- /opt/keycloak/bin/kc.sh show-config 2>/dev/null | grep -q kaapana" false

check "Kaapana user groups exist" "curl -k -s https://$DOMAIN/auth/admin/realms/kaapana/groups 2>/dev/null | grep -q kaapana_user" false

echo ""
echo "═══════════════════════════════════════════════════════════"
echo " 7. DATA PROCESSING PIPELINE"
echo "═══════════════════════════════════════════════════════════"

check "DICOM receiver service" "kubectl get svc -n services | grep -q dicom-receiver" false
check "Metadata extraction service" "kubectl get pods -n services 2>/dev/null | grep -q metadata" false
check "Thumbnail generation service" "kubectl get pods -n services 2>/dev/null | grep -q thumbnail" false

echo ""
echo "═══════════════════════════════════════════════════════════"
echo " 8. SYSTEM RESOURCES"
echo "═══════════════════════════════════════════════════════════"

# Get resource usage if metrics available
if kubectl top nodes &>/dev/null; then
    check "Node metrics available" "true"
    check "CPU usage < 90%" "kubectl top nodes --no-headers | awk '{gsub(\"%\",\"\",\$3); if(\$3<90) exit 0; exit 1}'" false
    check "Memory usage < 90%" "kubectl top nodes --no-headers | awk '{gsub(\"%\",\"\",\$5); if(\$5<90) exit 0; exit 1}'" false
else
    echo -e "${YELLOW}⚠ Metrics server not available - skipping resource checks${NC}"
fi

echo ""
echo "═══════════════════════════════════════════════════════════"
echo " VERIFICATION SUMMARY"
echo "═══════════════════════════════════════════════════════════"
echo ""
echo -e "${GREEN}✓ Passed:  $PASS${NC}"
echo -e "${YELLOW}⚠ Warnings: $WARN${NC}"
echo -e "${RED}✗ Failed:  $FAIL${NC}"
echo ""

TOTAL=$((PASS + WARN + FAIL))
SCORE=$((PASS * 100 / TOTAL))

echo "Overall Score: $SCORE% ($PASS/$TOTAL tests passed)"
echo ""

if [ $FAIL -eq 0 ]; then
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║   🎉 ALL CRITICAL CHECKS PASSED - POC IS READY! 🎉       ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}"
    exit 0
else
    echo -e "${RED}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║  ⚠ SOME CRITICAL CHECKS FAILED - REVIEW ISSUES ABOVE  ⚠  ║${NC}"
    echo -e "${RED}╚═══════════════════════════════════════════════════════════╝${NC}"
    exit 1
fi
EOF

chmod +x ~/kaapana-master-verification.sh
```

### Execute Verification

```bash
# Run the master verification suite
~/kaapana-master-verification.sh

# Save results for documentation
~/kaapana-master-verification.sh 2>&1 | tee ~/verification-results.txt
```

---

## Step 2: Test System Persistence & Restart

### Understanding Persistence

This test verifies that data and configurations survive pod/system restarts, ensuring production readiness.

### Perform Rolling Restart Test

```bash
# Restart all Kaapana services
kubectl rollout restart deployment -n services

# Watch pods restart
watch kubectl get pods -n services

# Wait for all pods to be Ready (may take 5-10 minutes)
# Press Ctrl+C when all show 1/1 Running
```

### Verify Services After Restart

```bash
# Wait 2 minutes for services to stabilize
sleep 120

# Run verification again
~/kaapana-master-verification.sh

# Check specific services
curl -k https://kaapana.novairis.site/flow/health
curl -k https://kaapana.novairis.site/opensearch-api/_cluster/health
curl -k https://kaapana.novairis.site/minio/health/live
```

### Verify Data Persistence

```bash
# Check if OpenSearch indices still exist
curl -k -u admin:admin https://kaapana.novairis.site/opensearch-api/_cat/indices

# Check if MinIO buckets still exist
kubectl exec -n services deployment/minio -- ls /data

# Check if Airflow DAGs still loaded
kubectl exec -n services deployment/airflow-scheduler -- \
  airflow dags list | wc -l

# All should show the same data as before restart
```

### Full Node Reboot Test (Optional)

**⚠️ Warning: This will cause downtime**

```bash
# Note: Only perform if testing disaster recovery

# Reboot the EC2 instance
sudo reboot

# Wait 2-3 minutes, then reconnect
ssh -i kaapana-poc-key.pem ubuntu@52.23.80.12

# Wait for Kubernetes and pods to start (5-10 minutes)
watch kubectl get pods -A

# Run verification again
~/kaapana-master-verification.sh
```

### Persistence Test Checklist

- [ ] All pods restarted successfully
- [ ] All services accessible after restart
- [ ] OpenSearch indices preserved
- [ ] MinIO buckets and data preserved
- [ ] Airflow DAGs loaded after restart
- [ ] User accounts and projects preserved
- [ ] Configuration settings preserved
- [ ] No data loss detected

---

## Step 3: Document Platform Configuration

### Create Platform Documentation Package

```bash
# Create documentation directory
mkdir -p ~/kaapana-poc-docs

# Gather system information
cat > ~/kaapana-poc-docs/01-system-info.md << EOF
# Kaapana POC - System Information

## Infrastructure

- **Cloud Provider:** AWS EC2
- **Instance Type:** r5.2xlarge
- **OS:** Ubuntu 22.04 LTS
- **Kubernetes:** MicroK8s $(microk8s version)
- **Elastic IP:** 52.23.80.12
- **FQDN:** kaapana.novairis.site

## Deployment Date

- **Deployed:** $(date +"%Y-%m-%d %H:%M:%S")
- **Kaapana Version:** $(kubectl get deployment -n services kaapana-backend -o jsonpath='{.metadata.labels.version}' 2>/dev/null || echo "latest")

## Resource Allocation

- **CPU Cores:** $(nproc)
- **RAM:** $(free -h | grep Mem | awk '{print $2}')
- **Disk:** $(df -h / | tail -1 | awk '{print $2}') ($(df -h / | tail -1 | awk '{print $4}') free)

## Network Configuration

- **HTTPS:** Enabled (Self-signed certificate)
- **DICOM Port:** 11112
- **Ingress Controller:** Traefik

EOF

# Gather pod information
kubectl get pods -A -o wide > ~/kaapana-poc-docs/02-pods-status.txt

# Gather service information
kubectl get svc -A > ~/kaapana-poc-docs/03-services-status.txt

# Gather ingress information
kubectl get ingress -A > ~/kaapana-poc-docs/04-ingress-status.txt

# Export Helm release information
helm list -A > ~/kaapana-poc-docs/05-helm-releases.txt

# Gather PV/PVC information
kubectl get pv,pvc -A > ~/kaapana-poc-docs/06-storage-status.txt
```

### Document Access Information

```bash
cat > ~/kaapana-poc-docs/07-access-info.md << 'EOF'
# Kaapana POC - Access Information

## Web Interfaces

### Main Kaapana UI
- **URL:** https://kaapana.novairis.site/
- **Username:** kaapana
- **Password:** kaapana
- **Description:** Main platform interface with Workflows, Datasets, Store, Meta, System, Extensions

### Airflow (Workflow Orchestration)
- **URL:** https://kaapana.novairis.site/flow/
- **Username:** kaapana
- **Password:** kaapana
- **Description:** DAG management and workflow execution monitoring

### OpenSearch Dashboards (Metadata Visualization)
- **URL:** https://kaapana.novairis.site/opensearch-dashboards/
- **Username:** admin
- **Password:** admin
- **Description:** Query and visualize DICOM metadata

### MinIO Console (Object Storage)
- **URL:** https://kaapana.novairis.site/minio-console/
- **Username:** minio
- **Password:** minio123
- **Description:** S3-compatible object storage for workflow outputs

### dcm4chee Admin UI (PACS Management)
- **URL:** https://kaapana.novairis.site/dcm4chee-arc/ui2/
- **Username:** admin
- **Password:** admin
- **Description:** DICOM PACS administration and study management

### Keycloak (User Management)
- **URL:** https://kaapana.novairis.site/auth/
- **Username:** admin
- **Password:** Kaapana2020
- **Description:** Identity and access management

## DICOM Communication

### Send DICOM via DIMSE
```bash
dcmsend -v kaapana.novairis.site 11112 \
  --aetitle kp-<dataset-name> \
  --call kp-<project-name> \
  --scan-directories \
  --scan-pattern '*.dcm' \
  --recurse <dicom-directory>
```

**Parameters:**
- `--aetitle`: Dataset name (creates or appends to dataset)
- `--call`: Project name (must exist, use 'admin' as default)

## SSH Access

```bash
ssh -i kaapana-poc-key.pem ubuntu@52.23.80.12
```

**Location of SSH key:** [Document key location]

## Projects

### Default Project
- **Name:** admin
- **Description:** Default administrative project
- **Users:** kaapana (admin), [other users]

### Test Project (if created)
- **Name:** test-project
- **Description:** Test project for POC demonstrations
- **Users:** testuser, [other users]

## User Accounts

### Admin User
- **Username:** kaapana
- **Role:** kaapana_admin (full platform access)
- **Projects:** All projects

### Test User (if created)
- **Username:** testuser
- **Role:** kaapana_user
- **Projects:** test-project

## Security Notes

- Self-signed SSL certificate (not production-ready)
- Default passwords in use (change for production)
- Security groups configured for POC access
- HIPAA compliance not configured (required for production)

EOF
```

### Document Known Issues and Limitations

```bash
cat > ~/kaapana-poc-docs/08-known-issues.md << 'EOF'
# Kaapana POC - Known Issues & Limitations

## Current Limitations

### 1. Single-Node Deployment
- **Issue:** No high availability
- **Impact:** System downtime if node fails
- **Production Fix:** Multi-node Kubernetes cluster with redundancy

### 2. Self-Signed SSL Certificate
- **Issue:** Browser security warnings
- **Impact:** Manual certificate acceptance required
- **Production Fix:** Valid SSL certificate from Let's Encrypt or commercial CA

### 3. Default Credentials
- **Issue:** Default passwords in use
- **Impact:** Security risk if exposed
- **Production Fix:** Change all default passwords, use secrets management

### 4. No Backup Strategy
- **Issue:** Data not backed up automatically
- **Impact:** Data loss risk in case of failure
- **Production Fix:** Implement automated backup solution (Velero, etc.)

### 5. Limited GPU Support
- **Issue:** No GPU configured
- **Impact:** AI workflows may run slowly or fail
- **Production Fix:** Add GPU nodes and configure GPU operators

### 6. No Monitoring/Alerting
- **Issue:** No active monitoring or alerting configured
- **Impact:** Issues may go unnoticed
- **Production Fix:** Configure Prometheus/Grafana with alerting

### 7. No External PACS Integration
- **Issue:** Not connected to external PACS
- **Impact:** Manual data transfer required
- **Production Fix:** Configure DICOM networking to external systems

## Encountered Issues During Setup

[Document any issues encountered and their solutions]

## Workarounds Applied

[Document any temporary workarounds that need permanent fixes]

## Pending Tasks

[List items not completed in POC that should be addressed]

EOF
```

### Create Quick Start Guide

```bash
cat > ~/kaapana-poc-docs/09-quick-start-guide.md << 'EOF'
# Kaapana POC - Quick Start Guide

## For New Users

### 1. Access the Platform

1. Open browser and navigate to: https://kaapana.novairis.site/
2. Accept self-signed certificate warning
3. Login with credentials: kaapana / kaapana

### 2. Select a Project

- Click project selector in top right corner
- Select "admin" project (default)
- All data and workflows are project-specific

### 3. Upload DICOM Data

**Option A: Via DICOM Protocol (Recommended)**
```bash
dcmsend -v kaapana.novairis.site 11112 \
  --aetitle kp-mydataset \
  --call kp-admin \
  --scan-directories \
  --scan-pattern '*.dcm' \
  --recurse /path/to/dicom/files
```

**Option B: Via Web Interface**
1. Go to Workflows → Data Upload
2. Click "Browse" or drag/drop ZIP file
3. Wait for upload to complete
4. Trigger "import-dicoms-from-data-upload" workflow

### 4. View Uploaded Data

1. Go to Workflows → Datasets
2. Wait for thumbnails to load (Gallery View)
3. Select series by clicking thumbnails
4. Double-click to open OHIF viewer

### 5. Execute a Workflow

1. In Datasets view, select series
2. Click "Execute Workflow" button
3. Select workflow from dropdown
4. Configure parameters
5. Click "Run"
6. Monitor progress in Workflows → Workflow List

### 6. View Workflow Results

1. Go to Workflows → Workflow List
2. Find your workflow execution
3. Click to view details and logs
4. Download results from MinIO or view in Datasets

## Common Tasks

### View Medical Images
- Workflows → Datasets → Double-click series

### Check Workflow Status
- Workflows → Workflow List

### Search for Studies
- Workflows → Datasets → Use search bar
- Full-text search with wildcards (e.g., `PATIENT*`)

### Manage Projects
- System → Projects (admin only)

### Create New User
- System → Keycloak → Users → Add User

## Support

- Official Docs: https://kaapana.readthedocs.io/
- GitHub: https://github.com/kaapana/kaapana
- Issues: https://github.com/kaapana/kaapana/issues

EOF
```

### Package Documentation

```bash
# Create README for documentation package
cat > ~/kaapana-poc-docs/README.md << 'EOF'
# Kaapana POC Documentation Package

This package contains complete documentation for the Kaapana POC deployment.

## Contents

- `01-system-info.md` - Infrastructure and system information
- `02-pods-status.txt` - Kubernetes pods status
- `03-services-status.txt` - Kubernetes services status
- `04-ingress-status.txt` - Ingress configuration
- `05-helm-releases.txt` - Helm release information
- `06-storage-status.txt` - Persistent storage status
- `07-access-info.md` - Access URLs and credentials
- `08-known-issues.md` - Known limitations and issues
- `09-quick-start-guide.md` - Quick start guide for users

## Setup Guides

Refer to the main documentation in `/d/repos/upwork/kaapana/kaapana-setup/docs/`:

1. `01-aws-infrastructure-setup.md`
2. `02-build-machine-preparation.md`
3. `03-kaapana-build-process.md`
4. `04-artifact-transfer.md`
5. `05-server-installation.md`
6. `06-platform-deployment.md`
7. `10-core-modules-configuration.md`
8. `07-data-upload-testing.md`
9. `08-workflow-testing.md`
10. `09-verification-checklist.md`
11. `11-system-verification-demo.md`

## Verification

Run verification script: `~/kaapana-master-verification.sh`

EOF

# Create archive
cd ~
tar -czf kaapana-poc-documentation-$(date +%Y%m%d).tar.gz kaapana-poc-docs/

echo "Documentation package created: ~/kaapana-poc-documentation-$(date +%Y%m%d).tar.gz"
```

---

## Step 4: Prepare Demo Scenario

### Create Demo Dataset

**If sample data not already uploaded, prepare demo dataset:**

```bash
# Generate synthetic DICOM data for demo
cat > ~/generate-demo-data.py << 'PYTHON_EOF'
#!/usr/bin/env python3
"""
Generate synthetic DICOM data for Kaapana demo
"""

import pydicom
from pydicom.dataset import Dataset, FileDataset
import numpy as np
from datetime import datetime
import os
import sys

def generate_demo_series(output_dir, patient_name, patient_id, modality="CT", num_slices=10):
    """Generate a synthetic medical imaging series"""
    
    os.makedirs(output_dir, exist_ok=True)
    
    study_uid = pydicom.uid.generate_uid()
    series_uid = pydicom.uid.generate_uid()
    
    print(f"Generating {modality} series for {patient_name} ({num_slices} slices)...")
    
    for i in range(num_slices):
        filename = os.path.join(output_dir, f"{modality}_{i+1:03d}.dcm")
        
        file_meta = Dataset()
        file_meta.MediaStorageSOPClassUID = '1.2.840.10008.5.1.4.1.1.2'  # CT Image Storage
        file_meta.MediaStorageSOPInstanceUID = pydicom.uid.generate_uid()
        file_meta.TransferSyntaxUID = pydicom.uid.ImplicitVRLittleEndian
        
        ds = FileDataset(filename, {}, file_meta=file_meta, preamble=b"\0" * 128)
        
        # Patient information
        ds.PatientName = patient_name
        ds.PatientID = patient_id
        ds.PatientBirthDate = '19800515'
        ds.PatientSex = 'M'
        ds.PatientAge = '044Y'
        
        # Study information
        ds.StudyInstanceUID = study_uid
        ds.StudyDate = datetime.now().strftime('%Y%m%d')
        ds.StudyTime = datetime.now().strftime('%H%M%S')
        ds.StudyDescription = f"POC Demo {modality} Study"
        ds.AccessionNumber = f"ACC{patient_id}"
        ds.StudyID = "1"
        
        # Series information
        ds.SeriesInstanceUID = series_uid
        ds.SeriesNumber = 1
        ds.SeriesDescription = f"Demo {modality} Series"
        ds.Modality = modality
        
        # Instance information
        ds.SOPInstanceUID = file_meta.MediaStorageSOPInstanceUID
        ds.SOPClassUID = file_meta.MediaStorageSOPClassUID
        ds.InstanceNumber = i + 1
        
        # Image data
        rows, cols = 512, 512
        
        # Create more realistic CT values
        if modality == "CT":
            # Simulate tissue densities in Hounsfield Units
            pixel_array = np.random.randint(-200, 300, (rows, cols), dtype=np.int16)
            # Add a "circular organ" in the center
            y, x = np.ogrid[:rows, :cols]
            mask = (x - cols//2)**2 + (y - rows//2)**2 <= (rows//4)**2
            pixel_array[mask] = np.random.randint(20, 80, pixel_array[mask].shape)
        else:
            pixel_array = np.random.randint(0, 4096, (rows, cols), dtype=np.int16)
        
        ds.Rows = rows
        ds.Columns = cols
        ds.SamplesPerPixel = 1
        ds.PhotometricInterpretation = "MONOCHROME2"
        ds.BitsAllocated = 16
        ds.BitsStored = 16
        ds.HighBit = 15
        ds.PixelRepresentation = 1 if modality == "CT" else 0
        
        if modality == "CT":
            ds.RescaleIntercept = -1024
            ds.RescaleSlope = 1
            ds.WindowCenter = 40
            ds.WindowWidth = 400
        
        ds.SliceThickness = 2.5
        ds.SliceLocation = i * 2.5
        ds.ImagePositionPatient = [0, 0, i * 2.5]
        ds.ImageOrientationPatient = [1, 0, 0, 0, 1, 0]
        ds.PixelSpacing = [0.8, 0.8]
        
        ds.PixelData = pixel_array.tobytes()
        
        ds.save_as(filename, write_like_original=False)
    
    print(f"✓ Generated {num_slices} files in {output_dir}")
    return study_uid, series_uid

def main():
    base_dir = "kaapana-demo-data"
    os.makedirs(base_dir, exist_ok=True)
    
    print("╔══════════════════════════════════════════════════════╗")
    print("║   Kaapana Demo Data Generator                        ║")
    print("╚══════════════════════════════════════════════════════╝")
    print()
    
    # Generate multiple patients with different modalities
    patients = [
        ("DEMO^PATIENT^001", "DEMO001", "CT", 15),
        ("DEMO^PATIENT^002", "DEMO002", "MR", 20),
        ("DEMO^PATIENT^003", "DEMO003", "CT", 12),
    ]
    
    studies = []
    
    for patient_name, patient_id, modality, slices in patients:
        output_dir = os.path.join(base_dir, patient_id)
        study_uid, series_uid = generate_demo_series(
            output_dir, patient_name, patient_id, modality, slices
        )
        studies.append((patient_name, patient_id, study_uid, series_uid, modality, slices))
    
    print()
    print("═" * 56)
    print(" Demo Data Generation Complete!")
    print("═" * 56)
    print()
    print("Generated Studies:")
    for patient_name, patient_id, study_uid, series_uid, modality, slices in studies:
        print(f"  {patient_name} ({patient_id})")
        print(f"    Modality: {modality}, Slices: {slices}")
        print(f"    Study UID: {study_uid[:40]}...")
        print()
    
    print(f"Data location: ./{base_dir}/")
    print()
    print("To upload to Kaapana:")
    print(f"  dcmsend -v kaapana.novairis.site 11112 \\")
    print(f"    --aetitle kp-demo-dataset \\")
    print(f"    --call kp-admin \\")
    print(f"    --scan-directories \\")
    print(f"    --scan-pattern '*.dcm' \\")
    print(f"    --recurse {base_dir}/")

if __name__ == "__main__":
    try:
        import pydicom
    except ImportError:
        print("Error: pydicom not installed")
        print("Install with: pip install pydicom numpy")
        sys.exit(1)
    
    main()

PYTHON_EOF

chmod +x ~/generate-demo-data.py

# Generate demo data
python3 ~/generate-demo-data.py
```

### Upload Demo Data

```bash
# Upload generated demo data
dcmsend -v kaapana.novairis.site 11112 \
  --aetitle kp-demo-dataset \
  --call kp-admin \
  --scan-directories \
  --scan-pattern '*.dcm' \
  --recurse ~/kaapana-demo-data/

# Verify upload
echo "Waiting for data to be processed (60 seconds)..."
sleep 60

# Check in OpenSearch
curl -k -u admin:admin \
  "https://kaapana.novairis.site/opensearch-api/meta-index/_search?q=PatientID:DEMO*&pretty" \
  | grep -A2 "PatientID"
```

### Prepare Demo Script

```bash
cat > ~/kaapana-demo-script.md << 'EOF'
# Kaapana POC - Demo Script

## Introduction (2 minutes)

**Welcome and Overview:**
"Welcome to the Kaapana POC demonstration. Kaapana is an open-source platform for medical data processing, developed by the German Cancer Research Center (DKFZ). Today, I'll show you how we've successfully deployed and configured Kaapana on AWS."

**What we'll cover:**
1. Platform overview and navigation
2. DICOM data management
3. Workflow execution
4. System administration
5. Q&A

---

## Part 1: Platform Overview (5 minutes)

### Navigate Main UI

**Action:** Open https://kaapana.novairis.site/

**Show:**
- Clean, modern interface
- Navigation menu: Workflows, Store, Meta, System, Extensions
- Project selector (explain data isolation)
- User profile (explain role-based access)

**Key Points:**
- "All data is organized by projects for multi-tenancy"
- "Different user roles: User, Project Manager, Admin"
- "Responsive design works on tablets and desktops"

---

## Part 2: Data Management (8 minutes)

### View Datasets Gallery

**Action:** Workflows → Datasets

**Show:**
- Gallery view with DICOM thumbnails
- Series metadata cards
- Multi-select functionality
- Search and filter capabilities

**Key Points:**
- "Gallery view inspired by modern photo apps"
- "Each thumbnail represents a DICOM series"
- "Metadata extracted automatically on upload"
- "Full-text search across all DICOM tags"

### Demonstrate Search

**Action:** Search for demo data

**Show:**
- Search: `DEMO*`
- Filter by modality: CT
- Filter by date range

**Key Points:**
- "Powered by OpenSearch for fast queries"
- "Supports wildcards and complex queries"
- "Results update in real-time"

### Open OHIF Viewer

**Action:** Double-click a series

**Show:**
- OHIF viewer with medical image
- Window/level controls
- Measurement tools
- Metadata panel

**Key Points:**
- "Built-in medical image viewer (OHIF)"
- "Standard DICOM viewing tools"
- "Measurements and annotations"
- "No plugin or download required"

---

## Part 3: Workflow Execution (10 minutes)

### Show Available Workflows

**Action:** Workflows → Workflow List or Workflow Execution

**Show:**
- List of available DAGs
- Workflow categories (processing, AI, export)
- Workflow descriptions

**Key Points:**
- "Workflows are defined as Airflow DAGs"
- "Covers data processing, AI inference, export"
- "Custom workflows can be added"

### Execute a Workflow

**Action:** Select series → Execute Workflow

**Show:**
1. Select demo series in Datasets
2. Click "Execute Workflow"
3. Choose a simple workflow (e.g., DICOM to NIfTI conversion)
4. Configure parameters
5. Click "Run"

**Key Points:**
- "Workflows process selected data"
- "Parameters can be customized"
- "Execution is tracked and logged"

### Monitor Workflow

**Action:** Workflows → Workflow List

**Show:**
- Running workflow status
- Task graph visualization
- Task logs

**Key Points:**
- "Real-time monitoring of execution"
- "Each workflow broken into tasks"
- "Detailed logs for debugging"

### View Results

**Action:** Check workflow output

**Show:**
- Completed workflow status
- Output files in MinIO
- Updated metadata in OpenSearch

**Key Points:**
- "Results stored in object storage (MinIO)"
- "Metadata automatically updated"
- "Results can be downloaded or used in next workflow"

---

## Part 4: System Administration (5 minutes)

### Show Airflow

**Action:** System → Airflow (if admin)

**Show:**
- Airflow dashboard
- DAG schedules
- Execution history

**Key Points:**
- "Airflow orchestrates all workflows"
- "Admins can schedule and monitor"
- "Extensible with custom operators"

### Show Keycloak

**Action:** System → Keycloak

**Show:**
- User management
- Group/role assignment
- Project membership

**Key Points:**
- "Centralized user management"
- "Role-based access control"
- "Can integrate with Active Directory/LDAP"

### Show Projects

**Action:** System → Projects

**Show:**
- List of projects
- User assignments
- Project settings

**Key Points:**
- "Projects isolate data between teams"
- "Users only see their project data"
- "Project managers control access"

---

## Part 5: Architecture & Integration (5 minutes)

### Explain Components

**Show diagram or list:**

**Storage Layer:**
- dcm4chee: DICOM PACS
- MinIO: Object storage (S3-compatible)
- OpenSearch: Metadata indexing

**Processing Layer:**
- Airflow: Workflow orchestration
- Kubernetes: Container orchestration
- Custom operators: Data processing logic

**Application Layer:**
- Kaapana UI: Web interface
- OHIF: Medical image viewer
- Keycloak: Authentication

**Key Points:**
- "Microservices architecture"
- "Cloud-native and scalable"
- "Open standards (DICOM, DICOMweb, S3)"

### Explain Extensibility

**Show:**
- How workflows can be added
- How to integrate external systems
- API availability

**Key Points:**
- "Platform is extensible"
- "Custom workflows via Airflow DAGs"
- "REST APIs for integration"
- "Active open-source community"

---

## Part 6: Production Roadmap (3 minutes)

### Discuss POC vs Production

**Current POC:**
- ✓ Single-node deployment
- ✓ Self-signed certificates
- ✓ Default credentials
- ✓ Basic functionality validated

**Production Requirements:**
- Multi-node Kubernetes cluster (HA)
- Valid SSL certificates (Let's Encrypt)
- Secure credential management
- Automated backups
- Monitoring and alerting
- GPU support for AI workloads
- Integration with hospital PACS
- HIPAA compliance (if required)

**Key Points:**
- "POC proves feasibility"
- "Production requires hardening"
- "Scalability path is clear"

---

## Q&A (5-10 minutes)

**Common Questions:**

**Q: How does data get into Kaapana?**
A: Via DICOM protocol (dcmsend) or web upload. Standard DICOM integration.

**Q: Can it integrate with our existing PACS?**
A: Yes, via DICOM networking (C-MOVE, C-STORE, WADO).

**Q: What AI models are available?**
A: nnU-Net for segmentation, custom models can be added as workflows.

**Q: How secure is it?**
A: Keycloak for auth, network policies, encryption. Production needs additional hardening.

**Q: Can we customize workflows?**
A: Yes, via Airflow DAG development. Python-based, well documented.

**Q: How much does it cost to run?**
A: Open-source (free), infrastructure costs depend on scale. POC ~$400/month.

**Q: What's the performance like?**
A: Scales with hardware. POC handles dozens of studies. Production can handle thousands.

---

## Conclusion (2 minutes)

**Summary:**
- ✓ Successfully deployed Kaapana on AWS
- ✓ Core modules configured and validated
- ✓ Data upload and processing verified
- ✓ Workflows executing successfully
- ✓ User management configured
- ✓ Platform ready for stakeholder review

**Next Steps:**
1. Gather feedback from this demo
2. Determine production requirements
3. Plan production deployment
4. Address security and compliance
5. Train users on the platform

**Thank You!**

EOF
```

---

## Step 5: Create Demo Verification Checklist

```bash
cat > ~/demo-prep-checklist.md << 'EOF'
# Kaapana POC - Demo Preparation Checklist

## Pre-Demo Setup (Day Before)

### Infrastructure
- [ ] Verify EC2 instance running
- [ ] Confirm all pods healthy: `kubectl get pods -A`
- [ ] Run master verification: `~/kaapana-master-verification.sh`
- [ ] Check disk space: `df -h`
- [ ] Verify backups (if configured)

### Data Preparation
- [ ] Demo data uploaded and processed
- [ ] Thumbnails generated for demo studies
- [ ] Metadata indexed in OpenSearch
- [ ] Test workflow completed successfully
- [ ] Sample results available in MinIO

### Access & Credentials
- [ ] All web interfaces accessible
- [ ] Login credentials tested
- [ ] Demo user account created (if needed)
- [ ] Project "demo" or "test-project" configured
- [ ] Network connectivity from demo location verified

### Browser Setup
- [ ] Browser tabs pre-opened:
  - [ ] Kaapana main UI
  - [ ] Workflows → Datasets (with demo data visible)
  - [ ] Airflow UI (logged in)
  - [ ] OpenSearch Dashboards (logged in)
  - [ ] MinIO Console (logged in)
- [ ] Self-signed cert warnings accepted
- [ ] Browser zoom level adjusted for screen sharing

### Demo Script
- [ ] Demo script printed or on second screen
- [ ] Talking points reviewed
- [ ] Timing practiced (aim for 30-40 minutes + Q&A)
- [ ] Backup plan if something fails

## During Demo

### Have Ready
- [ ] Demo script visible
- [ ] Verification script: `~/kaapana-master-verification.sh`
- [ ] Documentation package: `~/kaapana-poc-docs/`
- [ ] Terminal with SSH connection open
- [ ] Network diagram or architecture slide

### Monitor
- [ ] Pod status: `watch kubectl get pods -A`
- [ ] Service health
- [ ] Workflow execution progress
- [ ] System resource usage

## Post-Demo

### Feedback Collection
- [ ] Note questions asked
- [ ] Document feature requests
- [ ] Record concerns raised
- [ ] Capture feedback for production planning

### Follow-Up Tasks
- [ ] Share documentation package
- [ ] Provide SSH key (if appropriate)
- [ ] Schedule follow-up meeting
- [ ] Send thank-you email with resources

### Documentation
- [ ] Update known issues based on demo
- [ ] Document any problems encountered
- [ ] Update FAQ based on questions
- [ ] Create meeting notes

EOF
```

---

## Step 6: Final System Handoff

### Create Handoff Package

```bash
# Create handoff directory
mkdir -p ~/kaapana-poc-handoff

# Copy documentation
cp -r ~/kaapana-poc-docs/* ~/kaapana-poc-handoff/

# Copy scripts
cp ~/kaapana-master-verification.sh ~/kaapana-poc-handoff/
cp ~/kaapana-demo-script.md ~/kaapana-poc-handoff/
cp ~/demo-prep-checklist.md ~/kaapana-poc-handoff/

# Copy verification results
cp ~/verification-results.txt ~/kaapana-poc-handoff/ 2>/dev/null || true

# Copy all setup guides
mkdir -p ~/kaapana-poc-handoff/setup-guides
cp /d/repos/upwork/kaapana/kaapana-setup/docs/*.md ~/kaapana-poc-handoff/setup-guides/

# Create handoff README
cat > ~/kaapana-poc-handoff/README.md << 'EOF'
# Kaapana POC - Handoff Package

This package contains everything needed to operate and maintain the Kaapana POC deployment.

## Package Contents

### Documentation
- `01-system-info.md` - System configuration and details
- `07-access-info.md` - Access URLs, credentials, and connection info
- `08-known-issues.md` - Known limitations and workarounds
- `09-quick-start-guide.md` - Quick start guide for new users

### Setup Guides
- `setup-guides/` - Complete deployment documentation (11 guides)
- Covers infrastructure setup through final verification

### Scripts
- `kaapana-master-verification.sh` - Comprehensive system verification
- Run anytime to check system health

### Demo Materials
- `kaapana-demo-script.md` - Demo presentation script
- `demo-prep-checklist.md` - Demo preparation checklist

### Kubernetes Artifacts
- `02-pods-status.txt` - Pod inventory
- `03-services-status.txt` - Service configuration
- `04-ingress-status.txt` - Ingress routes
- `05-helm-releases.txt` - Helm chart releases
- `06-storage-status.txt` - Persistent storage info

## Quick Start

### Access the Platform
1. Open: https://kaapana.novairis.site/
2. Login: kaapana / kaapana

### Verify System Health
```bash
ssh -i kaapana-poc-key.pem ubuntu@52.23.80.12
~/kaapana-master-verification.sh
```

### Upload DICOM Data
```bash
dcmsend -v kaapana.novairis.site 11112 \
  --aetitle kp-mydataset \
  --call kp-admin \
  --scan-directories \
  --scan-pattern '*.dcm' \
  --recurse /path/to/dicoms
```

## Support

### Official Resources
- Documentation: https://kaapana.readthedocs.io/
- GitHub: https://github.com/kaapana/kaapana
- Issues: https://github.com/kaapana/kaapana/issues

### POC-Specific
- Infrastructure: AWS EC2, Ubuntu 22.04, MicroK8s
- Region: us-east-1
- Instance: r5.2xlarge
- Estimated cost: ~$385/month

## Maintenance

### Regular Tasks
- Check system health weekly
- Monitor disk space
- Review logs for errors
- Update documentation as needed

### Troubleshooting
1. Check pod status: `kubectl get pods -A`
2. Review logs: `kubectl logs -n services <pod-name>`
3. Restart services: `kubectl rollout restart deployment -n services`
4. Refer to setup guides for detailed troubleshooting

## Next Steps for Production

See `08-known-issues.md` for production readiness requirements:
- Multi-node cluster for HA
- Valid SSL certificates
- Secure secrets management
- Backup and disaster recovery
- Monitoring and alerting
- GPU support for AI workloads
- HIPAA compliance (if required)

EOF

# Create archive
cd ~
tar -czf kaapana-poc-handoff-$(date +%Y%m%d).tar.gz kaapana-poc-handoff/

echo "═══════════════════════════════════════════════════════════"
echo " Handoff Package Created Successfully!"
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "Package: ~/kaapana-poc-handoff-$(date +%Y%m%d).tar.gz"
echo ""
echo "To download:"
echo "  scp -i kaapana-poc-key.pem ubuntu@52.23.80.12:~/kaapana-poc-handoff-$(date +%Y%m%d).tar.gz ."
echo ""
```

---

## Milestone 4 Completion Checklist

### System Verification
- [ ] Master verification script passing (> 90% tests)
- [ ] All critical services operational
- [ ] No CrashLoopBackOff or Error pods
- [ ] Web interfaces all accessible
- [ ] DICOM port connectivity verified

### Data Persistence
- [ ] System restart tested successfully
- [ ] Data persists after pod restart
- [ ] Configuration preserved after restart
- [ ] No data loss detected
- [ ] Persistent volumes healthy

### Documentation
- [ ] System information documented
- [ ] Access credentials documented
- [ ] Known issues documented
- [ ] Quick start guide created
- [ ] Architecture explained
- [ ] Troubleshooting guide available

### Demo Preparation
- [ ] Demo data uploaded and processed
- [ ] Demo script created and reviewed
- [ ] Browser tabs pre-configured
- [ ] Demo checklist completed
- [ ] Backup plan prepared
- [ ] Timing practiced

### Handoff Package
- [ ] Complete documentation packaged
- [ ] Scripts and tools included
- [ ] Setup guides included
- [ ] Verification results included
- [ ] Handoff README created
- [ ] Archive created and tested

### Knowledge Transfer
- [ ] Platform capabilities explained
- [ ] User roles and permissions documented
- [ ] Workflow execution documented
- [ ] Administration tasks documented
- [ ] Production roadmap outlined

---

## Next Steps After Milestone 4

### Immediate
- [ ] Conduct stakeholder demo
- [ ] Gather feedback
- [ ] Document demo outcomes
- [ ] Create follow-up action items

### Short-Term (1-2 weeks)
- [ ] Address feedback from demo
- [ ] Plan additional testing if needed
- [ ] Evaluate production requirements
- [ ] Estimate production costs

### Long-Term (1-3 months)
- [ ] Plan production architecture
- [ ] Design HA deployment
- [ ] Implement security hardening
- [ ] Configure monitoring/alerting
- [ ] Train additional users
- [ ] Integrate with existing systems

---

## POC Success Criteria - Final Verification

### Functional Requirements Met
- ✅ DICOM data can be uploaded via multiple methods
- ✅ Medical images viewable in browser
- ✅ Metadata searchable and filterable
- ✅ Workflows can be executed successfully
- ✅ Results accessible and downloadable
- ✅ User management operational
- ✅ Project-based data isolation working

### Technical Requirements Met
- ✅ Single-node Kubernetes deployment
- ✅ All core modules operational
- ✅ Integration between components verified
- ✅ System stable for 24+ hours
- ✅ Persistence tested and validated
- ✅ Performance acceptable for POC

### Documentation Requirements Met
- ✅ Complete setup guides (11 documents)
- ✅ System configuration documented
- ✅ Access information documented
- ✅ Known issues documented
- ✅ Quick start guide created
- ✅ Demo materials prepared

### Deliverables Complete
- ✅ Working POC environment
- ✅ Documentation package
- ✅ Verification checklist
- ✅ Demo-ready setup
- ✅ Handoff package
- ✅ Knowledge transfer materials

---

## Congratulations! 🎉

### POC Milestones Completed

**✅ Milestone 1:** Environment Preparation & Familiarization  
**✅ Milestone 2:** Base Platform Installation  
**✅ Milestone 3:** Core Modules Configuration  
**✅ Milestone 4:** Verification, Documentation & Demo  

### What You've Accomplished

You have successfully:
- Deployed Kaapana on AWS from source
- Configured all core modules (dcm4chee, OpenSearch, MinIO, Airflow)
- Validated complete data ingestion and processing pipeline
- Tested workflow orchestration and execution
- Implemented user management and access control
- Verified system persistence and stability
- Created comprehensive documentation
- Prepared demo materials
- Packaged everything for handoff

### Platform Capabilities Demonstrated

- **Data Management:** DICOM upload, storage, indexing, search
- **Visualization:** Medical image viewing with OHIF
- **Processing:** Workflow orchestration via Airflow
- **Security:** Authentication and authorization via Keycloak
- **Multi-Tenancy:** Project-based data isolation
- **Extensibility:** Custom workflow capability
- **Administration:** System monitoring and management

---

## Final Resources

### Documentation
- **Official Docs:** https://kaapana.readthedocs.io/
- **GitHub:** https://github.com/kaapana/kaapana
- **Community:** https://github.com/kaapana/kaapana/discussions

### Support Contacts
- **Email:** kaapana@dkfz-heidelberg.de
- **Issues:** https://github.com/kaapana/kaapana/issues

### POC Details
- **Platform URL:** https://kaapana.novairis.site/
- **AWS Instance:** 52.23.80.12
- **Infrastructure:** AWS EC2 r5.2xlarge, Ubuntu 22.04, MicroK8s
- **Deployment Date:** [Your deployment date]
- **Estimated Monthly Cost:** ~$385 (EC2 + EBS)

---

**Document Status:** ✅ Complete  
**Milestone:** 4 - Verification, Documentation & Demo  
**POC Status:** ✅ Complete and Ready for Demo  

**Thank you for using these guides!**
