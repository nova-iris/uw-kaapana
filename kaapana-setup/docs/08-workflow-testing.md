# 08 - Workflow and AI Processing Testing

**Phase:** 4 - Test & Verify  
**Duration:** 60-90 minutes  
**Prerequisite:** 07-data-upload-testing.md completed  
**Related Milestone:** Milestone 3 - Core Modules Configuration

---

## Overview 

This guide tests Kaapana's workflow orchestration system, following the official [Workflows documentation](https://kaapana.readthedocs.io/en/latest/user_guide/workflows.html):

### Kaapana Workflow Management System (WMS)

Starting from version 0.2.0, Kaapana includes a comprehensive Workflow Management System that binds together:
- **Workflows** - Semantic container for multiple jobs and their data
- **Jobs** - Individual processing tasks executed by Airflow DAGs
- **Datasets** - Collections of DICOM series for processing
- **Projects** - Data isolation boundary for workflows

**Key Components:**
- **Workflow Execution** - Configure and launch workflows on data
- **Workflow List** - Monitor running and completed workflows
- **Instance Overview** - Manage local and remote instances (for federated execution)
- **Airflow** - Underlying orchestration engine (DAG-based)

### What You'll Test

- **Workflow Execution via Datasets** - Launching workflows from selected data
- **Workflow Configuration** - Setting parameters and options
- **Workflow Monitoring** - Tracking execution status and logs
- **Output Verification** - Checking results in MinIO and metadata
- **Airflow DAG Management** - Understanding the underlying engine
- **Service Workflows** - Automatic background processing

**Official Documentation:**
- Workflows Overview: https://kaapana.readthedocs.io/en/latest/user_guide/workflows.html
- Workflow Execution: https://kaapana.readthedocs.io/en/latest/user_guide/workflow_management_system/workflow_execution.html
- Workflow List: https://kaapana.readthedocs.io/en/latest/user_guide/workflow_management_system/workflow_list.html
- Airflow System: https://kaapana.readthedocs.io/en/latest/user_guide/system/airflow.html

---

## Prerequisites Check

```bash
# SSH to AWS server
ssh -i kaapana-poc-key.pem ubuntu@52.23.80.12

# Verify Airflow running
kubectl get pods -n services | grep airflow

# Verify DICOM data exists
curl -k -s -u admin:admin https://kaapana.novairis.site/opensearch-api/meta-index/_count | grep count

# Should show count > 0
```

---

## Step 1: Execute Workflow from Datasets (Primary Method)

### Understanding Workflow Execution

**The Workflow Execution component is the ONLY place to start executable workflow instances.** You can access it two ways:
1. Workflows → Workflow Execution (direct)
2. Workflows → Datasets → Select series → Execute Workflow (recommended)

**Workflow Configuration Steps:**
1. Select runner instance(s) - where jobs execute
2. Select Airflow DAG - the workflow to run
3. Select dataset - the data to process

 **Important:** All resources (workflows, datasets, series) are separated by **projects**. The WMS only shows items associated with the currently selected project.

### Execute Your First Workflow

#### Step 1.1: Select Data in Datasets

**Open browser:**
```
https://kaapana.novairis.site/
```

**Navigate to Workflows → Datasets**

**Select series for processing:**
1. Ensure correct project selected (top-right): `admin` or your test project
2. Search for your uploaded data: `POC*`
3. **Select series** - Click thumbnails (hold Ctrl/Cmd for multiple)
4. Should see "X Items Selected" indicator

#### Step 1.2: Launch Workflow Execution

**Click "Execute Workflow" button**

**Workflow Execution panel opens showing:**
- **Runner Instances** section
- **Workflow Selection** section
- **Dataset** section
- **Configuration Parameters** section

#### Step 1.3: Configure Workflow

**1. Select Runner Instance:**
- Choose **"Local" instance** (your current Kaapana instance)
- For federated execution, you'd select remote instances here

**2. Select Workflow (DAG):**
- Browse available workflows or search
- Choose a simple workflow first: `dicom-to-nifti` or similar data processing DAG
- Read workflow description

**3. Dataset (Pre-filled):**
- Should show "Temporary Dataset" with your selected series
- Or optionally create a named dataset first

**4. Configure Parameters:**
- Each workflow has specific parameters
- Common parameters:
  - `batch_size` - Number of series processed in parallel
  - `output_format` - Result format (DICOM, NIfTI, JSON)
  - Workflow-specific options
- Use defaults for first test

#### Step 1.4: Execute

**Click "Run Workflow" or "Execute" button**

**Expected behavior:**
- Confirmation message appears
- Redirected to Workflow List automatically
- Workflow appears with "Running" status

---

## Step 2: Monitor Workflow Execution

### Access Workflow List

**Navigate to: Workflows → Workflow List**

**You should see:**
- Your running workflow at the top
- Status indicator (Running, Success, Failed)
- Start time and duration
- Dataset information
- Action buttons (View, Abort, etc.)

### View Workflow Details

**Click on your workflow entry**

**Workflow Detail View shows:**
- **Workflow Graph** - Visual representation of tasks
- **Task Status** - Each task's state (Running, Success, Failed)
- **Execution Timeline**
- **Logs** - Task-level logs
- **Results** - Output locations

### Monitor Progress

**Watch execution:**
- Tasks turn green when completed successfully
- Tasks turn red if failed
- Logs update in real-time
- Duration counter shows elapsed time

**Typical execution time:**
- Simple workflows: 2-5 minutes
- Complex workflows: 10-30+ minutes depending on data size

---

## Step 4: Understanding Airflow (Underlying Engine)

### What is Airflow's Role?

**Apache Airflow** is the underlying workflow orchestration engine. While users primarily interact with Kaapana's Workflow Execution interface, administrators and developers work with Airflow directly.

**Airflow concepts:**
- **DAG** (Directed Acyclic Graph) - Workflow definition
- **Task** - Individual step in a workflow
- **Operator** - Python class that performs a task (e.g., `DcmConverterOperator`)
- **DAG Run** - Execution instance of a DAG
- **Scheduler** - Manages DAG execution
- **Worker** - Executes tasks

### Access Airflow Admin UI

**Open browser:**
```
https://kaapana.novairis.site/flow/
```

**Login:**
- Username: `kaapana`
- Password: `kaapana`

**You should see:**
- Airflow dashboard with complete DAG list
- Toggle switches for enabling/disabling DAGs
- Links to browse, graph, tree, logs, code
- Recent DAG runs and their status

 **Note:** Most DAGs should remain "Off" (paused). **Service DAGs** (prefix `service-`) should be "On" for automatic processing.

---

## Step 5: Explore Available DAGs

### Understanding Kaapana DAGs

**Kaapana provides several workflow types:**

| DAG Type | Purpose | Example DAGs |
|----------|---------|--------------|
| **Data Processing** | DICOM processing, format conversion | `dicom-to-nifti`, `anonymization` |
| **AI Inference** | nnU-Net segmentation, classification | `nnunet-predict`, `total-segmentator` |
| **Data Export** | Export processed data | `export-to-minio`, `dicom-send` |
| **Admin** | System maintenance | `cleanup-old-data`, `reindex-opensearch` |

### List Available DAGs

**In Airflow UI:**

1. **View DAG List**
   - Main page shows all available DAGs
   - Look for DAGs with prefixes:
     - `processing-*`
     - `nnunet-*`
     - `segmentation-*`
     - `export-*`

2. **Check DAG Status**
   - **Off (gray):** DAG disabled
   - **On (blue):** DAG enabled and scheduled
   - **Running (green):** Currently executing
   - **Failed (red):** Execution failed

### Enable Key DAGs

**Turn on these DAGs for testing:**
- `dicom-to-nifti` - Convert DICOM to NIfTI format
- `nnunet-predict` - nnU-Net segmentation (if available)
- Any preprocessing DAGs

**To enable:**
- Click the toggle switch next to DAG name
- Should turn from Off (gray) to On (blue)

---

## Step 3: Test DICOM Processing Workflow

### Run DICOM to NIfTI Conversion

**This workflow converts DICOM series to NIfTI format for AI processing.**

#### Trigger DAG Manually

1. **Find DAG**
   - Locate `dicom-to-nifti` or similar preprocessing DAG

2. **Trigger DAG**
   - Click on DAG name to view details
   - Click "Play" button (▶) on the right
   - Select "Trigger DAG"

3. **Configure Run Parameters (if prompted)**
   - **Study Instance UID:** (optional, processes all if empty)
   - **Series Description Filter:** (optional, e.g., "CT")
   - **Output Location:** (default: MinIO bucket)
   - Click "Trigger"

4. **Monitor Execution**
   - DAG should appear in "Running" state
   - Refresh page to see progress
   - Execution time: 2-5 minutes depending on data size

#### View DAG Execution

**In Airflow UI:**

1. **Open DAG Details**
   - Click on DAG name

2. **View Graph**
   - Click "Graph" tab
   - Shows workflow structure and task dependencies
   - Colors indicate task status:
     - **Green:** Success
     - **Yellow:** Running
     - **Red:** Failed
     - **Gray:** Not started

3. **View Logs**
   - Click on a task box in the graph
   - Select "Log"
   - View detailed execution logs

**Expected workflow steps:**
```
[Task 1] get_dicom_studies     -> Fetch study list from dcm4chee
[Task 2] download_dicom        -> Download DICOM files
[Task 3] validate_dicom        -> Validate DICOM structure
[Task 4] convert_to_nifti      -> Convert to NIfTI format
[Task 5] upload_to_storage     -> Upload NIfTI to MinIO
[Task 6] update_metadata       -> Update OpenSearch metadata
```

#### Verify Conversion Output

```bash
# On AWS server, check MinIO for output

# Get MinIO credentials
kubectl get secret minio-secret -n kaapana \
  -o jsonpath='{.data.accesskey}' | base64 -d
echo ""
kubectl get secret minio-secret -n kaapana \
  -o jsonpath='{.data.secretkey}' | base64 -d
echo ""

# Install MinIO client
wget https://dl.min.io/client/mc/release/linux-amd64/mc
chmod +x mc
sudo mv mc /usr/local/bin/

# Configure MinIO client
mc alias set kaapana-minio http://localhost:9000 <accesskey> <secretkey>

# List NIfTI outputs
mc ls kaapana-minio/kaapana-data/nifti/

# Download sample NIfTI to verify
mc cp kaapana-minio/kaapana-data/nifti/<filename>.nii.gz ~/nifti-sample.nii.gz
ls -lh ~/nifti-sample.nii.gz
```

---

## Step 4: Test nnU-Net Segmentation (if available)

### Check nnU-Net Availability

```bash
# Check if nnU-Net operators exist
kubectl get pods -n kaapana | grep -i nnunet

# Check Airflow DAGs for nnU-Net
# In Airflow UI, search for "nnunet" or "segmentation"
```

### Run nnU-Net Segmentation Workflow

**⚠️ Note:** nnU-Net requires GPU and pre-trained models. If not available, skip to Step 5.

#### Trigger nnU-Net DAG

1. **Find nnU-Net DAG**
   - Look for: `nnunet-predict`, `nnunet-inference`, or `total-segmentator`

2. **Trigger DAG**
   - Click on DAG name
   - Click "Play" button (▶)
   - Select "Trigger DAG"

3. **Configure Parameters**
   - **Input Study UID:** Study to segment
   - **Model:** Select pre-trained model (e.g., Task001_BrainTumor)
   - **Output Format:** DICOM or NIfTI
   - Click "Trigger"

4. **Monitor Execution**
   - Execution time: 10-30 minutes depending on:
     - GPU availability
     - Model size
     - Input data size

#### View Segmentation Results

**In OHIF Viewer:**
```
http://YOUR_ELASTIC_IP/ohif/
```

1. **Open Processed Study**
   - Should see original study plus new segmentation series

2. **View Segmentation Overlay**
   - Select segmentation series
   - Should display colored overlay on original images
   - Each color represents a segmented structure

**In MinIO:**
```bash
# List segmentation outputs
mc ls kaapana-minio/kaapana-data/segmentations/

# Download segmentation mask
mc cp kaapana-minio/kaapana-data/segmentations/<seg-file>.nii.gz ~/segmentation.nii.gz
```

---

## Step 5: Test Data Export Workflow

### Export Processed Data

#### Trigger Export DAG

1. **Find Export DAG**
   - Look for: `export-to-minio`, `batch-export`, or `dicom-send`

2. **Trigger DAG**
   - Click on DAG name
   - Click "Play" button (▶)
   - Select "Trigger DAG"

3. **Configure Export Parameters**
   - **Export Format:** DICOM, NIfTI, or JSON
   - **Studies to Export:** All or specific Study UIDs
   - **Destination:** MinIO bucket path
   - Click "Trigger"

4. **Monitor Export**
   - Should complete in 2-5 minutes

#### Verify Export

```bash
# Check export directory in MinIO
mc ls kaapana-minio/kaapana-data/exports/

# Download exported data
mc mirror kaapana-minio/kaapana-data/exports/ ~/exports/
ls -la ~/exports/
```

---

## Step 6: Create Custom Simple Workflow

### Create Test DAG

**This demonstrates Kaapana extensibility.**

```bash
# On AWS server, create custom DAG directory
kubectl exec -it deployment/airflow-scheduler -n kaapana -- bash

# Inside Airflow pod:
cd /opt/airflow/dags/

# Create simple test DAG
cat > test_workflow.py << 'EOF'
from airflow import DAG
from airflow.operators.bash import BashOperator
from datetime import datetime, timedelta

default_args = {
    'owner': 'kaapana',
    'depends_on_past': False,
    'start_date': datetime(2024, 1, 1),
    'email_on_failure': False,
    'email_on_retry': False,
    'retries': 1,
    'retry_delay': timedelta(minutes=5),
}

dag = DAG(
    'test_simple_workflow',
    default_args=default_args,
    description='Simple test workflow',
    schedule_interval=None,  # Manual trigger only
    catchup=False,
)

# Task 1: Print hello
task1 = BashOperator(
    task_id='print_hello',
    bash_command='echo "Hello from Kaapana POC!"',
    dag=dag,
)

# Task 2: Show date
task2 = BashOperator(
    task_id='show_date',
    bash_command='date',
    dag=dag,
)

# Task 3: List DICOM studies
task3 = BashOperator(
    task_id='count_studies',
    bash_command='curl -s -u admin:admin http://opensearch:9200/dicom-*/_count | grep count',
    dag=dag,
)

# Define dependencies
task1 >> task2 >> task3
EOF

exit  # Exit from pod
```

### Refresh DAGs in Airflow

**Airflow should auto-detect the new DAG within 30-60 seconds.**

**In Airflow UI:**
1. Wait 1-2 minutes for DAG to appear
2. Refresh browser
3. Should see `test_simple_workflow` in DAG list

### Run Custom DAG

1. **Enable DAG**
   - Toggle `test_simple_workflow` to On

2. **Trigger DAG**
   - Click "Play" button (▶)
   - Select "Trigger DAG"

3. **View Execution**
   - Click on DAG name
   - View Graph and Logs
   - All three tasks should succeed

---

## Step 7: Monitor Workflow Performance

### View DAG Statistics

**In Airflow UI:**

1. **Browse → DAG Runs**
   - Shows all DAG executions
   - Sortable by date, duration, state

2. **View Task Duration**
   - Click on DAG name
   - Click "Task Duration" tab
   - See average execution time per task

3. **View Success Rate**
   - Click "Landing Times" tab
   - Shows DAG execution timeline

### Check Resource Usage

```bash
# On AWS server

# Check pod CPU/memory usage
kubectl top pods -n kaapana

# Check node resources
kubectl top nodes

# View Airflow worker logs
kubectl logs -l app=airflow-worker -n kaapana --tail=100

# Check for errors
kubectl logs -l app=airflow-scheduler -n kaapana | grep -i error
```

---

## Testing Checklist

Verify the following:

### Airflow Access
- [x] Successfully logged into Airflow UI
- [x] Can view DAG list
- [x] Can enable/disable DAGs

### Workflow Execution
- [x] Successfully triggered DICOM processing workflow
- [x] Workflow completed without errors
- [x] Can view workflow graph and task status
- [x] Can access task logs

### Data Processing
- [x] DICOM to NIfTI conversion successful
- [x] Output files created in MinIO
- [x] Metadata updated in OpenSearch

### AI Processing (if available)
- [x] nnU-Net segmentation DAG available
- [x] Segmentation workflow executed successfully
- [x] Segmentation masks generated
- [x] Results viewable in OHIF

### Custom Workflows
- [x] Created custom test DAG
- [x] DAG appeared in Airflow UI
- [x] Successfully executed custom workflow

---

## Troubleshooting

### DAG not appearing in Airflow
```bash
# Check Airflow scheduler logs
kubectl logs -l app=airflow-scheduler -n kaapana --tail=50

# Check DAG file syntax
kubectl exec deployment/airflow-scheduler -n kaapana -- \
  python /opt/airflow/dags/test_workflow.py

# Restart Airflow scheduler
kubectl rollout restart deployment airflow-scheduler -n kaapana
```

### Workflow fails: "Operator not found"
```bash
# Check if operator image exists
kubectl get pods -n kaapana | grep operator

# Check Airflow worker logs
kubectl logs -l app=airflow-worker -n kaapana | grep -i error

# Verify Docker images
docker images | grep operator
```

### Task fails with storage error
```bash
# Check MinIO accessibility
kubectl get svc minio -n kaapana
kubectl logs -l app=minio -n kaapana --tail=50

# Verify MinIO credentials in Airflow
kubectl get secret minio-secret -n kaapana -o yaml

# Test MinIO access from Airflow pod
kubectl exec deployment/airflow-worker -n kaapana -- \
  curl http://minio:9000/minio/health/live
```

### nnU-Net fails: "Model not found"
```bash
# Check if nnU-Net models installed
kubectl exec deployment/nnunet-operator -n kaapana -- \
  ls -la /models/

# If models missing, download pre-trained models:
# https://github.com/MIC-DKFZ/nnUNet#pretrained-models
# Then mount to nnU-Net pod
```

### OpenSearch indexing slow
```bash
# Check OpenSearch status
kubectl get pods -l app=opensearch -n kaapana

# Check indexing queue
curl -u admin:admin http://localhost:9200/_cat/indices?v

# Check OpenSearch performance
curl -u admin:admin http://localhost:9200/_cluster/stats?pretty
```

---

## Next Steps

✅ **Workflows tested and verified!**

**Next:** [09-verification-checklist.md](09-verification-checklist.md)

Complete final verification and document the POC setup.

---

## Quick Reference

**Access Airflow:**
```
http://YOUR_IP/flow/
Username: kaapana
Password: kaapana
```

**Trigger DAG via CLI:**
```bash
kubectl exec deployment/airflow-scheduler -n kaapana -- \
  airflow dags trigger <dag-id>
```

**View DAG logs:**
```bash
kubectl exec deployment/airflow-scheduler -n kaapana -- \
  airflow tasks logs <dag-id> <task-id> <execution-date>
```

**Check workflow status:**
```bash
kubectl exec deployment/airflow-scheduler -n kaapana -- \
  airflow dags list-runs -d <dag-id>
```

---

**Document Status:** ✅ Complete  
**Next Document:** 09-verification-checklist.md
