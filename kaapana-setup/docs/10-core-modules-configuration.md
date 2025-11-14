# 10 - Core Modules Configuration & Validation

**Phase:** Post-Deployment Configuration  
**Duration:** 60-90 minutes  
**Prerequisite:** 06-platform-deployment.md completed  
**Milestone:** Milestone 3 - Core Modules Configuration

---

## Overview

This guide configures and validates the core Kaapana modules that form the platform's backbone:

- **dcm4chee** - DICOM storage and PACS server
- **OpenSearch/Dashboards** - Metadata indexing and visualization
- **MinIO** - Object storage backend for non-DICOM data
- **Airflow** - Workflow orchestration engine
- **Keycloak** - Authentication and user management
- **Projects** - Data isolation and multi-tenancy

After completing this guide, all core modules will be operational, integrated, and verified.

- Minio console: https://kaapana.novairis.site/web/store/minio
- OHIF Viewer: https://kaapana.novairis.site/web/store/ohif
- OpenSearch Dashboards: https://kaapana.novairis.site/web/meta/osdashboard0
- Airflow UI: https://kaapana.novairis.site/web/system/airflow
- Keycloak Admin Console: https://kaapana.novairis.site/web/system/keycloak
- Traefik: https://kaapana.novairis.site/web/system/traefik
- PACS server: https://kaapana.novairis.site/web/system/pacs
- Grafana: https://kaapana.novairis.site/web/system/grafana


---

## Step 1: Configure and Verify dcm4chee (PACS)

### Understanding dcm4chee

dcm4chee is Kaapana's internal PACS (Picture Archiving and Communication System) that stores all DICOM data. It provides:
- DICOM storage via DIMSE protocol (port 11112)
- WADO-RS/QIDO-RS/STOW-RS (DICOMweb) services
- Web-based administration interface

### Access dcm4chee Admin UI

**Open browser:**
```
https://kaapana.novairis.site/dcm4chee-arc/ui2/
```

**Login credentials:**
- Username: `admin`
- Password: `admin`

### Configure dcm4chee Settings

1. **Navigate to Configuration**
   - Click "Configuration" in left menu
   - Select "Devices" → "dcm4chee-arc"

2. **Verify Network Configuration**
   - Click "Connections" tab
   - Verify DICOM listener on port 11112
   - Verify HTTP listener on port 8080

3. **Check Application Entities (AE Titles)**
   - Click "Application Entities"
   - Should see: `DCM4CHEE` (default AE Title)
   - Note: AE Title is used for DICOM DIMSE communication

4. **Verify Storage Configuration**
   - Click "Archive Device" → "Storage"
   - Check storage directories configured
   - Verify connection to object storage (MinIO)

### Test DICOM Connectivity

```bash
# On AWS server, test DICOM service
# Install DCMTK if not already installed
sudo apt update && sudo apt install -y dcmtk

# Test DICOM echo (verify service responds)
dcmecho -v kaapana.novairis.site 11112

# Expected output:
# I: Requesting Association
# I: Association Accepted (Max Send PDV: 16372)
# I: Sending Echo Request
# I: Received Echo Response (Success)
```

### Verify dcm4chee in Kubernetes

```bash
# Check dcm4chee pod status
kubectl get pods -n services | grep dcm4chee

# Check dcm4chee logs
kubectl logs -n services deployment/dcm4chee-arc --tail=50

# Verify dcm4chee service endpoints
kubectl get svc -n services | grep dcm4chee

# Should show:
# - ClusterIP for internal communication
# - Ports: 8080 (HTTP), 11112 (DICOM)
```

### dcm4chee Configuration Checklist

- [ ] Admin UI accessible at https://kaapana.novairis.site/dcm4chee-arc/ui2/
- [ ] Can login with admin credentials
- [ ] DICOM listener on port 11112 verified
- [ ] AE Title `DCM4CHEE` configured
- [ ] Storage configuration valid
- [ ] DICOM echo test successful
- [ ] Pod running without errors

---

## Step 2: Configure and Verify OpenSearch

### Understanding OpenSearch in Kaapana

OpenSearch (fork of Elasticsearch) indexes all DICOM metadata, enabling:
- Fast search and filtering of medical images
- Metadata visualization in dashboards
- Support for the Datasets Gallery View
- Custom analytics and reporting

### Access OpenSearch Dashboards

**Open browser:**
```
https://kaapana.novairis.site/web/meta/osdashboard0
```

### Verify Index Patterns

1. **Navigate to Index Management**
   - Click hamburger menu (☰) → "Management" → "Index Management"

2. **Check Indices**
   - Should see indices like:
     - `meta-index` - DICOM metadata
     - `dicom-*` - Project-specific DICOM data
     - `audit-*` - Audit logs

3. **View Index Details**
   - Click on an index name
   - Check "Documents" count (should be > 0 after data upload)
   - Verify "Health" status (green or yellow)

### Configure Index Patterns (if not exist)

1. **Navigate to Index Patterns**
   - Click hamburger menu → "Management" → "Index Patterns"

2. **Create Index Pattern for DICOM Metadata**
   - Click "Create index pattern"
   - Index pattern: `meta-index*` or `dicom-*`
   - Time field: `0008103A` (Content Date/Time) or `@timestamp`
   - Click "Create index pattern"

### Test Search Functionality

1. **Navigate to Discover**
   - Click "Discover" in left menu

2. **Select Index Pattern**
   - Choose `meta-index*` or `dicom-*`

3. **Test Query**
   - Search for: `*` (wildcard for all documents)
   - Should see DICOM metadata documents (if data uploaded)
   - Available fields: PatientName, PatientID, StudyDate, Modality, etc.

### Verify OpenSearch in Kubernetes

```bash
# Check OpenSearch pod status
kubectl get pods -n services | grep opensearch

# Check OpenSearch logs
kubectl logs -n services deployment/opensearch --tail=50

# Verify OpenSearch health
kubectl port-forward -n services svc/opensearch 9200:9200 &
curl -u admin:admin https://localhost:9200/_cluster/health?pretty -k
kill %1

# Expected output:
# {
#   "cluster_name" : "opensearch",
#   "status" : "green" or "yellow",
#   "number_of_nodes" : 1,
#   ...
# }
```

### OpenSearch Configuration Checklist

- [ ] OpenSearch Dashboards accessible
- [ ] Can login with admin credentials
- [ ] Indices created and visible
- [ ] Index patterns configured
- [ ] Search functionality works
- [ ] Cluster health is green/yellow
- [ ] Pod running without errors

---

## Step 3: Configure and Verify MinIO

### Understanding MinIO in Kaapana

MinIO provides S3-compatible object storage for:
- Non-DICOM workflow outputs (NIfTI, JSON, reports)
- Thumbnails and preview images
- Workflow artifacts and logs
- Data export staging

### Access MinIO Console

**Open browser:**
```
https://kaapana.novairis.site/minio-console/
```

**Login credentials:**
- Username: `minio`
- Password: `minio123`

### Verify Buckets Configuration

1. **Navigate to Buckets**
   - Click "Buckets" in left menu

2. **Check Default Buckets**
   - Should see buckets like:
     - `kaapana-data` - Main data bucket
     - `uploads` - Data upload staging
     - `workflows` - Workflow outputs
     - Project-specific buckets (e.g., `admin-project`)

3. **Verify Bucket Settings**
   - Click on a bucket name
   - Check "Access Policy" (should be restricted)
   - Verify versioning settings
   - Check lifecycle rules (if configured)

### Create Test Bucket (Optional)

```bash
# Install MinIO client (mc) on server
wget https://dl.min.io/client/mc/release/linux-amd64/mc
chmod +x mc
sudo mv mc /usr/local/bin/

# Configure MinIO client
mc alias set kaapana-minio https://kaapana.novairis.site/minio \
  minio minio123 --insecure

# List buckets
mc ls kaapana-minio

# Create test bucket
mc mb kaapana-minio/test-bucket

# Upload test file
echo "Test file content" > test.txt
mc cp test.txt kaapana-minio/test-bucket/

# Verify upload
mc ls kaapana-minio/test-bucket/

# Download file to verify
mc cp kaapana-minio/test-bucket/test.txt downloaded-test.txt
cat downloaded-test.txt

# Clean up
mc rm kaapana-minio/test-bucket/test.txt
mc rb kaapana-minio/test-bucket
rm test.txt downloaded-test.txt
```

### Verify MinIO in Kubernetes

```bash
# Check MinIO pod status
kubectl get pods -n services | grep minio

# Check MinIO logs
kubectl logs -n services deployment/minio --tail=50

# Verify MinIO service
kubectl get svc -n services | grep minio

# Test MinIO API endpoint
curl -I https://kaapana.novairis.site/minio/health/live -k

# Should return: HTTP/1.1 200 OK
```

### MinIO Configuration Checklist

- [ ] MinIO Console accessible
- [ ] Can login with minio credentials
- [ ] Default buckets created
- [ ] Can list bucket contents
- [ ] Upload/download test successful
- [ ] API health check returns 200
- [ ] Pod running without errors

---

## Step 4: Configure and Verify Airflow

### Understanding Airflow in Kaapana

Airflow orchestrates all data processing workflows through DAGs (Directed Acyclic Graphs). It manages:
- DICOM ingestion pipelines
- Data processing workflows
- AI/ML inference pipelines
- Data export and federation

### Access Airflow UI

**Open browser:**
```
https://kaapana.novairis.site/flow/
```

**Login credentials:**
- Username: `kaapana`
- Password: `kaapana`

### Verify Airflow Components

1. **Check Airflow Dashboard**
   - Should see list of DAGs
   - Verify DAG count > 0
   - Check scheduler status (green indicator)

2. **Verify Core DAGs Present**
   - Look for essential DAGs:
     - `service-process-incoming-dcm` - DICOM ingestion
     - `service-extract-metadata` - Metadata extraction
     - `service-generate-thumbnails` - Thumbnail generation
     - Data processing DAGs
     - Export DAGs

3. **Check DAG Status**
   - Most DAGs should be in "Off" (paused) state initially
   - Service DAGs (prefix `service-`) should be "On" (active)

### Configure Airflow Connections

**Verify connections to other services:**

1. **Navigate to Admin → Connections**
   - Check connections exist for:
     - `opensearch_default` - OpenSearch connection
     - `minio_default` - MinIO S3 connection
     - `postgres_default` - Airflow metadata database

2. **Test Connection (Optional)**
   - Click "Test" button for each connection
   - Should return success message

### Verify Airflow in Kubernetes

```bash
# Check Airflow pods status
kubectl get pods -n services | grep airflow

# Should see:
# - airflow-scheduler (orchestrates DAGs)
# - airflow-webserver (web UI)
# - airflow-worker (executes tasks)

# Check Airflow scheduler logs
kubectl logs -n services deployment/airflow-scheduler --tail=50

# Verify no errors in scheduler
kubectl logs -n services deployment/airflow-scheduler | grep -i error

# Check Airflow webserver
kubectl logs -n services deployment/airflow-webserver --tail=30
```

### Test DAG Execution

**Test a simple service DAG:**

```bash
# Via Airflow UI:
# 1. Find a simple DAG (e.g., 'test-dag' if exists)
# 2. Click play button (▶)
# 3. Click "Trigger DAG"
# 4. Monitor execution in "Graph" view
# 5. Check task logs for errors

# Via kubectl (alternative):
kubectl exec -n services deployment/airflow-scheduler -- \
  airflow dags list | head -20

# Trigger a DAG via CLI (example)
# kubectl exec -n services deployment/airflow-scheduler -- \
#   airflow dags trigger service-process-incoming-dcm
```

### Airflow Configuration Checklist

- [ ] Airflow UI accessible
- [ ] Can login with kaapana credentials
- [ ] DAGs loaded and visible (> 10 DAGs)
- [ ] Service DAGs are enabled
- [ ] Scheduler running without errors
- [ ] Webserver and worker pods running
- [ ] Connections to OpenSearch/MinIO configured
- [ ] Test DAG execution successful (if attempted)

---

## Step 5: Configure Keycloak Users and Access Control

### Understanding Keycloak in Kaapana

Keycloak manages authentication and authorization with three user roles:
- **kaapana_user** - Access to Workflows, Datasets, Store (project-specific)
- **kaapana_project_manager** - User role + project management
- **kaapana_admin** - Full platform access (all projects, system config)

### Access Keycloak Admin Console

**Open browser:**
```
https://kaapana.novairis.site/auth/
```

**Login credentials:**
- Username: `admin`
- Password: `Kaapana2020`

### Verify User Groups

1. **Navigate to Groups**
   - Click "Groups" in left menu

2. **Check Kaapana Groups Exist**
   - `kaapana_user`
   - `kaapana_project_manager`
   - `kaapana_admin`

### Create Test Users

#### Create Regular User

1. **Navigate to Users**
   - Click "Users" in left menu
   - Click "Add user"

2. **Fill User Details**
   - Username: `testuser`
   - Email: `testuser@example.com`
   - First Name: `Test`
   - Last Name: `User`
   - Email Verified: `On`
   - Click "Create"

3. **Set Password**
   - Go to "Credentials" tab
   - Password: `TestPassword123!`
   - Temporary: `Off`
   - Click "Set Password"

4. **Assign to Group**
   - Go to "Groups" tab
   - Select `kaapana_user` from "Available Groups"
   - Click "Join"

5. **Assign to Project** (Important!)
   - This must be done via System → Projects in main UI
   - See Step 6 below

#### Create Project Manager (Optional)

Repeat above steps with:
- Username: `projectmanager`
- Assign to group: `kaapana_project_manager`

### Verify User Login

**Test new user login:**

1. **Logout from Kaapana UI**
2. **Login with test user**
   - Username: `testuser`
   - Password: `TestPassword123!`
3. **Verify Access**
   - Should see Workflows menu
   - Should NOT see System menu (admin only)

### Keycloak Configuration Checklist

- [ ] Keycloak admin console accessible
- [ ] User groups configured (kaapana_user, project_manager, admin)
- [ ] Test user created successfully
- [ ] Test user password set
- [ ] Test user assigned to kaapana_user group
- [ ] Test user login successful
- [ ] Access control verified (user vs admin)

---

## Step 6: Configure Projects and Data Isolation

### Understanding Projects in Kaapana

Projects provide data isolation and multi-tenancy. Key concepts:
- Each DICOM series belongs to one or more projects
- Users only see data from projects they're assigned to
- Workflows execute within project context
- Default project: `admin`

### Access Projects Management

**Requirements:**
- Must be logged in as admin or project_manager

**Open browser:**
```
https://kaapana.novairis.site/
```

**Navigate to System → Projects**

### Verify Default Admin Project

1. **Check Projects List**
   - Should see `admin` project
   - Status: Active

2. **View Admin Project Details**
   - Click on `admin` project
   - Check assigned users
   - Verify workflow execution enabled

### Create Test Project

1. **Click "Add Project"**

2. **Enter Project Details**
   - Project Name: `test-project`
   - Description: `Test project for POC`
   - Click "Create"

3. **Assign Users to Project**
   - Select `test-project`
   - Click "Manage Users"
   - Add `testuser` to project
   - Select role: `member` or `owner`
   - Click "Save"

4. **Enable Workflow Execution**
   - Verify "Workflow Execution" toggle is ON
   - This allows workflows to run on project data

### Test Project Switching

1. **Login as testuser**
2. **Click Project Selector** (top right, shows current project)
3. **Switch to test-project**
4. **Verify UI Updates**
   - Datasets view should be empty (no data yet)
   - Available workflows should appear

### Projects Configuration Checklist

- [ ] System → Projects accessible (as admin)
- [ ] Admin project exists and active
- [ ] Test project created successfully
- [ ] Users assigned to projects
- [ ] Project switching works
- [ ] Workflow execution enabled for projects
- [ ] User sees correct project data

---

## Step 7: Verify Module Integration

### Test End-to-End Data Flow

This test verifies all modules work together:

**Workflow:**
1. DICOM data arrives → dcm4chee
2. Metadata extracted → OpenSearch
3. Thumbnails generated → MinIO
4. Data visible in → Datasets UI

### Verify Service DAGs Running

```bash
# Check if service DAGs have run
kubectl exec -n services deployment/airflow-scheduler -- \
  airflow dags list-runs -d service-process-incoming-dcm --state success

# Should show successful runs
```

### Check Module Communication

```bash
# Test Airflow → OpenSearch
kubectl exec -n services deployment/airflow-scheduler -- \
  curl -s -u admin:admin http://opensearch:9200/_cluster/health

# Test Airflow → MinIO
kubectl exec -n services deployment/airflow-scheduler -- \
  curl -s http://minio:9000/minio/health/live

# Test dcm4chee → OpenSearch (check logs)
kubectl logs -n services deployment/dcm4chee-arc | grep -i "metadata\|index"
```

### Verify Data Flow Without Upload

**Check ingestion pipeline readiness:**

```bash
# Monitor ingestion service logs
kubectl logs -n services -l app=ctp --tail=50

# Check if CTP (Clinical Trial Processor) is listening
kubectl get svc -n services | grep ctp

# Verify port 11112 accessible
nc -zv kaapana.novairis.site 11112
```

### Integration Verification Checklist

- [ ] Service DAGs are running automatically
- [ ] Airflow can connect to OpenSearch
- [ ] Airflow can connect to MinIO
- [ ] dcm4chee can communicate with OpenSearch
- [ ] CTP service listening on port 11112
- [ ] No errors in module logs
- [ ] All pods healthy and running

---

## Step 8: System Health Check

### Run Comprehensive Health Check

```bash
# Create health check script
cat > ~/kaapana-health-check.sh << 'EOF'
#!/bin/bash

echo "=== Kaapana Core Modules Health Check ==="
echo ""

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

check_service() {
    local name=$1
    local namespace=$2
    local selector=$3
    
    echo -n "Checking $name... "
    
    if kubectl get pods -n $namespace -l $selector 2>/dev/null | grep -q "1/1.*Running"; then
        echo -e "${GREEN}✓ Running${NC}"
        return 0
    else
        echo -e "${RED}✗ Not Running${NC}"
        return 1
    fi
}

# Check core services
check_service "dcm4chee" "services" "app=dcm4chee"
check_service "OpenSearch" "services" "app=opensearch"
check_service "MinIO" "services" "app=minio"
check_service "Airflow Scheduler" "services" "app=airflow,component=scheduler"
check_service "Airflow Webserver" "services" "app=airflow,component=webserver"
check_service "Airflow Worker" "services" "app=airflow,component=worker"
check_service "Keycloak" "services" "app=keycloak"

echo ""
echo "=== Endpoint Health Checks ==="

# Check endpoints
check_url() {
    local name=$1
    local url=$2
    
    echo -n "Checking $name... "
    
    if curl -k -s -o /dev/null -w "%{http_code}" "$url" | grep -qE "200|302"; then
        echo -e "${GREEN}✓ Accessible${NC}"
        return 0
    else
        echo -e "${RED}✗ Not Accessible${NC}"
        return 1
    fi
}

check_url "Main UI" "https://kaapana.novairis.site/"
check_url "Airflow" "https://kaapana.novairis.site/flow/"
check_url "OpenSearch Dashboards" "https://kaapana.novairis.site/opensearch-dashboards/"
check_url "MinIO Console" "https://kaapana.novairis.site/minio-console/"
check_url "dcm4chee UI" "https://kaapana.novairis.site/dcm4chee-arc/ui2/"
check_url "Keycloak" "https://kaapana.novairis.site/auth/"

echo ""
echo "=== Resource Usage ==="

kubectl top nodes 2>/dev/null || echo "Metrics server not available"

echo ""
echo "Health check complete!"
EOF

chmod +x ~/kaapana-health-check.sh
~/kaapana-health-check.sh
```

### Check Disk Space

```bash
# Check server disk space
df -h /

# Should have > 50GB free

# Check persistent volumes
kubectl get pv
kubectl describe pv | grep -E "Name:|Capacity:|Status:"
```

### Verify Network Connectivity

```bash
# Test inter-pod communication
kubectl run test-pod --image=busybox -it --rm --restart=Never -- sh

# Inside pod:
nslookup opensearch.services.svc.cluster.local
nslookup minio.services.svc.cluster.local
nslookup dcm4chee-arc.services.svc.cluster.local
exit
```

---

## Troubleshooting

### dcm4chee Issues

**Problem: DICOM echo fails**
```bash
# Check dcm4chee logs
kubectl logs -n services deployment/dcm4chee-arc --tail=100

# Verify port 11112 accessible
telnet kaapana.novairis.site 11112

# Check security group (AWS)
# Ensure inbound rule: TCP 11112 from your IP
```

**Problem: Admin UI not accessible**
```bash
# Check ingress configuration
kubectl get ingress -n services

# Verify dcm4chee service
kubectl get svc -n services dcm4chee-arc

# Check pod logs for errors
kubectl logs -n services deployment/dcm4chee-arc | grep -i error
```

### OpenSearch Issues

**Problem: Cluster status red**
```bash
# Check cluster health
curl -u admin:admin -k https://kaapana.novairis.site/opensearch-api/_cluster/health?pretty

# Check OpenSearch logs
kubectl logs -n services deployment/opensearch --tail=100

# Check disk space (OpenSearch needs adequate space)
df -h
```

**Problem: No indices visible**
```bash
# List all indices
curl -u admin:admin -k https://kaapana.novairis.site/opensearch-api/_cat/indices

# Indices are created when data is uploaded
# Normal to have no indices immediately after deployment
```

### MinIO Issues

**Problem: Cannot access console**
```bash
# Check MinIO pod status
kubectl get pods -n services -l app=minio

# Check MinIO logs
kubectl logs -n services deployment/minio --tail=50

# Verify credentials
kubectl get secret -n services minio-secret -o yaml
```

**Problem: Upload fails**
```bash
# Check MinIO health
curl -k https://kaapana.novairis.site/minio/health/live

# Check bucket permissions
mc admin policy list kaapana-minio
```

### Airflow Issues

**Problem: DAGs not loading**
```bash
# Check Airflow scheduler logs
kubectl logs -n services deployment/airflow-scheduler --tail=100 | grep -i dag

# Refresh DAGs
kubectl exec -n services deployment/airflow-scheduler -- \
  airflow dags list-import-errors

# Restart scheduler if needed
kubectl rollout restart -n services deployment/airflow-scheduler
```

**Problem: Connections not working**
```bash
# Test connections from Airflow
kubectl exec -n services deployment/airflow-scheduler -- \
  python -c "
from airflow.hooks.base import BaseHook
conn = BaseHook.get_connection('opensearch_default')
print(conn)
"
```

### Keycloak Issues

**Problem: Cannot create users**
```bash
# Check Keycloak logs
kubectl logs -n services deployment/keycloak --tail=50

# Verify Keycloak database connection
kubectl exec -n services deployment/keycloak -- \
  /opt/keycloak/bin/kc.sh show-config | grep -i database
```

**Problem: User cannot login**
```bash
# Check browser console for errors
# Verify user credentials in Keycloak admin console
# Ensure user is assigned to a project
# Clear browser cookies and try again
```

---

## Milestone 3 Completion Checklist

### Core Modules Validated

- [ ] **dcm4chee (PACS)**
  - [ ] Admin UI accessible
  - [ ] DICOM service listening on port 11112
  - [ ] Storage configuration valid
  - [ ] Pod running without errors

- [ ] **OpenSearch**
  - [ ] Dashboards accessible
  - [ ] Cluster health green/yellow
  - [ ] Index patterns configured
  - [ ] Pod running without errors

- [ ] **MinIO**
  - [ ] Console accessible
  - [ ] Default buckets created
  - [ ] Upload/download working
  - [ ] Pod running without errors

- [ ] **Airflow**
  - [ ] UI accessible
  - [ ] DAGs loaded (> 10 visible)
  - [ ] Service DAGs enabled
  - [ ] Scheduler and workers running

- [ ] **Keycloak**
  - [ ] Admin console accessible
  - [ ] User groups configured
  - [ ] Test users created
  - [ ] Authentication working

- [ ] **Projects**
  - [ ] Admin project exists
  - [ ] Test project created
  - [ ] Users assigned to projects
  - [ ] Project switching works

### Integration Verified

- [ ] All pods running (1/1 Ready)
- [ ] Module-to-module communication working
- [ ] Service DAGs active
- [ ] No critical errors in logs
- [ ] System health check passing

---

## Next Steps

✅ **Core modules configured and validated!**

**Next:** [07-data-upload-testing.md](07-data-upload-testing.md)

Upload DICOM data and verify the complete data ingestion pipeline.

---

## Quick Reference

**Access URLs:**
```
Main UI:      https://kaapana.novairis.site/
Airflow:      https://kaapana.novairis.site/flow/
OpenSearch:   https://kaapana.novairis.site/opensearch-dashboards/
MinIO:        https://kaapana.novairis.site/minio-console/
dcm4chee:     https://kaapana.novairis.site/dcm4chee-arc/ui2/
Keycloak:     https://kaapana.novairis.site/auth/
```

**Default Credentials:**
```
Kaapana UI:   kaapana / kaapana
Airflow:      kaapana / kaapana
OpenSearch:   admin / admin
MinIO:        minio / minio123
dcm4chee:     admin / admin
Keycloak:     admin / Kaapana2020
```

**Health Check:**
```bash
~/kaapana-health-check.sh
```

---

**Document Status:** ✅ Complete  
**Milestone:** 3 - Core Modules Configuration  
**Next Document:** 07-data-upload-testing.md
