# 07 - Data Upload and DICOM Testing

**Phase:** 4 - Test & Verify  
**Duration:** 30-60 minutes  
**Prerequisite:** 10-core-modules-configuration.md completed  
**Related Milestone:** Milestone 3 - Core Modules Configuration

---

## Overview

This guide tests Kaapana's complete data ingestion pipeline following the official [Data Upload documentation](https://kaapana.readthedocs.io/en/latest/user_guide/workflow_management_system/data_upload.html):

- **DICOM upload** via DICOM DIMSE protocol (port 11112) and web interface
- **Automatic processing** through Clinical Trial Processor (CTP)
- **Metadata extraction** and indexing in OpenSearch
- **Thumbnail generation** and storage in MinIO
- **Data validation** with dciodvfy/pydicom-validator
- **Visualization** in Datasets Gallery View and OHIF viewer
- **Project assignment** for data isolation

### Understanding Kaapana's Ingestion Pipeline

When DICOM data arrives at Kaapana (via DIMSE or web upload), the following happens automatically:

1. **CTP Reception:** Data received by Clinical Trial Processor
2. **PACS Storage:** Saved to dcm4chee PACS
3. **Metadata Indexing:** DICOM tags indexed in OpenSearch (project-specific)
4. **Series-Project Mapping:** Series associated with target project + admin project
5. **Thumbnail Generation:** Preview images created and stored in MinIO
6. **Validation:** DICOM compliance checked, warnings/errors recorded

**Official Documentation:**
- User Guide - Data Upload: https://kaapana.readthedocs.io/en/latest/user_guide/workflow_management_system/data_upload.html
- Store Components: https://kaapana.readthedocs.io/en/latest/user_guide/store.html

---

## Prerequisites Check

```bash
# SSH to AWS server
ssh -i kaapana-poc-key.pem ubuntu@52.23.80.12

# Verify all pods running
kubectl get pods -A | grep -E "services|kaapana"

# Verify Kaapana UI accessible
curl -k -s -o /dev/null -w "%{http_code}" https://kaapana.novairis.site/
# Should return: 200 or 302

# Verify DICOM receiver port
nc -zv kaapana.novairis.site 11112
# Should show: succeeded

# Ensure you're in admin project or have a project selected
```

---

## Step 0: Understanding Projects and Datasets

**Before uploading data, understand Kaapana's project-based data organization:**

### Projects in Kaapana

**Projects provide data isolation and multi-tenancy.** Each DICOM series belongs to one or more projects, and users only see data from their assigned projects.

**When uploading via DICOM DIMSE:**
- The `--call` parameter specifies the target project (e.g., `kp-admin`)
- Project must exist before upload
- Use `kp-admin` for the default admin project

**When uploading via web interface:**
- Data is uploaded to the currently selected project
- Select project from dropdown in top-right corner

**Learn more:**
- Projects Documentation: https://kaapana.readthedocs.io/en/latest/user_guide/system/projects.html

### Datasets View

After data upload, you'll view and interact with data in the **Datasets Gallery View**:

**Features:**
- Gallery-style thumbnails of DICOM series
- Metadata cards with patient/study/series information
- Multi-select for batch operations
- Full-text search across DICOM tags
- Filter by modality, date, patient, etc.
- Direct access to OHIF viewer
- Workflow execution from selected data

**Access:** Workflows → Datasets

**Learn more:**
- Datasets Documentation: https://kaapana.readthedocs.io/en/latest/user_guide/workflow_management_system/datasets.html

---

## Step 1: Obtain Sample DICOM Data

### Option A: Download from TCIA (Recommended)

**The Cancer Imaging Archive provides public DICOM datasets.**

```bash
# On AWS server, create downloads directory
mkdir -p ~/dicom-samples
cd ~/dicom-samples

# Download small CT dataset from TCIA
# Example: COVID-19 CT scans (small subset)
wget https://wiki.cancerimagingarchive.net/download/attachments/70230072/CT-0.zip

# Or use LIDC-IDRI sample
wget https://wiki.cancerimagingarchive.net/download/attachments/1966254/LIDC-IDRI-0001.zip

# Unzip
unzip CT-0.zip -d ct-sample/
# or
unzip LIDC-IDRI-0001.zip -d lidc-sample/

# Check DICOM files
find ct-sample/ -name "*.dcm" | head -10
```

### Option B: Use DICOM Library Sample

```bash
# Download Kaapana test dataset
cd ~/dicom-samples

git clone https://github.com/pydicom/pydicom.git
cd pydicom/pydicom/data/test_files/

# List sample DICOM files
ls -la *.dcm

# Copy to working directory
mkdir -p ~/dicom-samples/test-data
cp *.dcm ~/dicom-samples/test-data/
```

### Option C: Generate Synthetic DICOM

```bash
# Install dicom-generator
pip install pydicom pillow numpy

# Create synthetic DICOM script
cat > ~/dicom-samples/generate_dicom.py << 'EOF'
#!/usr/bin/env python3
import pydicom
from pydicom.dataset import Dataset, FileDataset
import numpy as np
from datetime import datetime
import os

def generate_ct_series(output_dir, num_slices=10):
    """Generate a synthetic CT series"""
    os.makedirs(output_dir, exist_ok=True)
    
    # Common metadata
    patient_name = "TEST^PATIENT^POC"
    patient_id = "POC001"
    study_uid = pydicom.uid.generate_uid()
    series_uid = pydicom.uid.generate_uid()
    
    for i in range(num_slices):
        # Create FileDataset
        filename = os.path.join(output_dir, f"CT_{i:03d}.dcm")
        
        file_meta = Dataset()
        file_meta.MediaStorageSOPClassUID = '1.2.840.10008.5.1.4.1.1.2'  # CT Image Storage
        file_meta.MediaStorageSOPInstanceUID = pydicom.uid.generate_uid()
        file_meta.TransferSyntaxUID = pydicom.uid.ImplicitVRLittleEndian
        
        ds = FileDataset(filename, {}, file_meta=file_meta, preamble=b"\0" * 128)
        
        # Patient info
        ds.PatientName = patient_name
        ds.PatientID = patient_id
        ds.PatientBirthDate = '19800101'
        ds.PatientSex = 'M'
        
        # Study info
        ds.StudyInstanceUID = study_uid
        ds.StudyDate = datetime.now().strftime('%Y%m%d')
        ds.StudyTime = datetime.now().strftime('%H%M%S')
        ds.StudyDescription = "POC Test CT Study"
        ds.AccessionNumber = "ACC001"
        
        # Series info
        ds.SeriesInstanceUID = series_uid
        ds.SeriesNumber = 1
        ds.SeriesDescription = "Test CT Series"
        ds.Modality = 'CT'
        
        # Instance info
        ds.SOPInstanceUID = file_meta.MediaStorageSOPInstanceUID
        ds.SOPClassUID = file_meta.MediaStorageSOPClassUID
        ds.InstanceNumber = i + 1
        
        # Image data (512x512 synthetic CT)
        rows, cols = 512, 512
        pixel_array = np.random.randint(-1000, 1000, (rows, cols), dtype=np.int16)
        
        ds.Rows = rows
        ds.Columns = cols
        ds.SamplesPerPixel = 1
        ds.PhotometricInterpretation = "MONOCHROME2"
        ds.BitsAllocated = 16
        ds.BitsStored = 16
        ds.HighBit = 15
        ds.PixelRepresentation = 1
        ds.RescaleIntercept = -1024
        ds.RescaleSlope = 1
        
        ds.SliceThickness = 1.0
        ds.SliceLocation = i * 1.0
        ds.ImagePositionPatient = [0, 0, i * 1.0]
        ds.ImageOrientationPatient = [1, 0, 0, 0, 1, 0]
        ds.PixelSpacing = [0.5, 0.5]
        
        ds.PixelData = pixel_array.tobytes()
        
        # Save
        ds.save_as(filename, write_like_original=False)
        print(f"Generated: {filename}")
    
    print(f"\nGenerated {num_slices} DICOM files in {output_dir}")

if __name__ == "__main__":
    generate_ct_series("./synthetic-ct-series", num_slices=20)
EOF

chmod +x ~/dicom-samples/generate_dicom.py

# Generate synthetic data
cd ~/dicom-samples
python3 generate_dicom.py

# Verify
ls -la synthetic-ct-series/*.dcm
```

---

## Step 2: Upload DICOM via UI

### Access Kaapana UI

**Open browser:**
```
http://YOUR_ELASTIC_IP/
```

**Login:**
- Username: `kaapana`
- Password: `kaapana`

### Upload Through Web Interface

**In Kaapana UI:**

1. **Navigate to Upload Section**
   - Click "Data Upload" or "DICOM Upload" in the menu

2. **Select Upload Method**
   - Choose "Browse Files" or "Drag & Drop"

3. **Select DICOM Files**
   - Navigate to your downloaded/generated DICOM files
   - Select all files (Ctrl+A or Cmd+A)
   - Click "Open"

4. **Initiate Upload**
   - Click "Upload" or "Start Upload"
   - Wait for upload to complete
   - Should see progress bar and success message

5. **Verify Upload Success**
   - Check for "Upload Complete" or similar success message
   - Note the Study Instance UID (if displayed)

---

## Step 3: Upload DICOM via DICOM Protocol (dcmsend) - Recommended

### Why DICOM DIMSE is Preferred

**DICOM DIMSE (port 11112) is the recommended upload method because:**
- Native DICOM protocol, standard in medical imaging
- Reliable and well-tested
- Used in production hospital environments
- Supports batch uploads with directory scanning
- Automatic retry and error handling

**Official Documentation Format:**

According to [Kaapana Data Upload docs](https://kaapana.readthedocs.io/en/latest/user_guide/workflow_management_system/data_upload.html#option-1-sending-images-via-dicom-dimse-preferred), the command format is:

```bash
dcmsend -v <ip-address-or-hostname-of-server> 11112 \
  --aetitle kp-<dataset-name> \
  --call kp-<project-name> \
  --scan-directories \
  --scan-pattern '*.dcm' \
  --recurse <data-dir-of-DICOM-images>
```

**Parameter Explanation:**
- `--aetitle kp-<dataset-name>`: Specifies the **dataset**. If the dataset exists, new images append to it
- `--call kp-<project-name>`: Specifies the **project**. Project must exist (use `admin` as default)
- `--scan-directories`: Recursively scan directories
- `--scan-pattern '*.dcm'`: Pattern for DICOM files
- `--recurse`: Scan subdirectories

 **Important:** Visit Workflows → Data Upload wizard in the web interface to get a command tailored to your deployment with correct hostname and parameters.

### Install DICOM Toolkit

```bash
# On AWS server or local machine
sudo apt update
sudo apt install -y dcmtk

# Verify installation
dcmsend --version
```

### Upload DICOM Files to Kaapana

#### Method 1: Direct Upload (From Any Machine)

```bash
# Navigate to your DICOM data directory
cd ~/dicom-samples/ct-sample  # or your DICOM directory

# Send to admin project with dataset name "poc-test-data"
dcmsend -v kaapana.novairis.site 11112 \
  --aetitle kp-poc-test-data \
  --call kp-admin \
  --scan-directories \
  --scan-pattern '*.dcm' \
  --recurse .

# Send all DICOM files
find . -name "*.dcm" -exec dcmsend localhost 11112 -aec DCM4CHEE {} +

# Or send single study
dcmsend localhost 11112 -aec DCM4CHEE *.dcm

# Expected output:
# I: Requesting Association
# I: Association Accepted (Max Send PDV: 16372)
# I: Sending file: CT_001.dcm
# I: Received Store SCP Response
# I: status code: 0 (Success)
# ... (repeated for each file)
# I: Releasing Association
```

**Expected Results:**
- All files uploaded successfully (status code: 0)
- Association established and released properly
- No errors in output

#### Method 2: Upload to Different Project

```bash
# If you created a test-project in Step 10:
dcmsend -v kaapana.novairis.site 11112 \
  --aetitle kp-test-dataset \
  --call kp-test-project \
  --scan-directories \
  --scan-pattern '*.dcm' \
  --recurse ~/dicom-samples/ct-sample/
```

### Verify Upload in Server Logs

```bash
# On AWS server, check CTP (Clinical Trial Processor) logs
kubectl logs -n services -l app=ctp --tail=50 | grep -i "received\|processed"

# Check dcm4chee logs for stored studies
kubectl logs -n services -l app=dcm4chee --tail=50 | grep -i "store"

# Should show entries like:
# DICOM Store Request received: StudyInstanceUID=1.2.3.4...
# Store completed successfully
```

### Wait for Processing

**Important:** After upload, Kaapana automatically processes the data:

```bash
# Wait 2-3 minutes for ingestion pipeline to complete:
# - Metadata extraction (to OpenSearch)
# - Thumbnail generation (to MinIO)
# - Validation (DICOM compliance check)

echo "Waiting for data processing (120 seconds)..."
sleep 120

# Check if metadata indexed
curl -k -u admin:admin \
  "https://kaapana.novairis.site/opensearch-api/meta-index/_search?q=PatientID:POC*&pretty" \
  | grep -A2 "PatientID"
```

---

## Step 4: View Data in Datasets Gallery (Primary Method)

### Understanding the Datasets View

The **Datasets Gallery View** is Kaapana's modern interface for data interaction, inspired by photo gallery apps. This is the primary way users interact with DICOM data.

**Official Documentation:** https://kaapana.readthedocs.io/en/latest/user_guide/workflow_management_system/datasets.html

### Access Datasets Gallery

**Open browser:**
```
https://kaapana.novairis.site/
```

**Steps:**
1. **Login** with kaapana / kaapana
2. **Select Project** from dropdown (top-right): Choose `admin`
3. **Navigate to** Workflows → Datasets

### Explore the Gallery View

**You should see:**
- **Thumbnails** of each DICOM series
- **Metadata cards** showing:
  - Patient Name
  - Patient ID
  - Study Date
  - Modality
  - Series Description
  - Number of instances
- **Validation indicators** (warning/error icons if issues detected)

### Test Gallery Features

#### 1. Search and Filter

**Full-text search:**
```
Search: POC001
Result: Shows all series for patient POC001
```

**Wildcard search:**
```
Search: POC*
Result: Shows all series with PatientID starting with POC
```

**Add filters:**
- Click "Add Filter" button
- Select "Modality" → Choose "CT"
- Only CT series displayed

**Official Search Syntax:**
- Use `*` for wildcarding: `LUNG1-*`
- Use `-` for excluding: `-CHEST`
- Full OpenSearch query syntax supported

#### 2. Multi-Select

**Select multiple series:**
- Hold **Ctrl** (Cmd on Mac) and click series
- Or **click and drag** to select multiple

**Available actions after selection:**
- Create new dataset
- Add to existing dataset
- Remove from dataset (if dataset selected)
- Execute workflow

#### 3. Create a Dataset

**Datasets organize series for workflow processing:**

1. **Select series** (e.g., all CT series)
2. **Click "Create Dataset"** button
3. **Enter dataset name:** `poc-ct-dataset`
4. **Click "Save"**

**Result:** Dataset created and selected, gallery filters to show only those series

#### 4. Open Detail View

**View series details and images:**
1. **Double-click a series thumbnail**
2. **Side panel opens** showing:
   - **OHIF Viewer** - Interactive medical image viewer
   - **Metadata Table** - Searchable DICOM tags

**OHIF Viewer controls:**
- Scroll through slices
- Adjust window/level
- Zoom and pan
- Measurements

#### 5. Use Metadata Dashboard

**If configured (check Settings):**
- **Right panel** shows metadata distribution
- **Bar charts** for Modality, Study Date, etc.
- **Click bar** to filter by that value

### Datasets View Checklist

- [ ] Datasets gallery accessible
- [ ] Uploaded series visible with thumbnails
- [ ] Can search and find series by Patient ID
- [ ] Filters work (Modality, Date, etc.)
- [ ] Multi-select works
- [ ] Can create dataset from selected series
- [ ] Detail view opens and shows OHIF viewer
- [ ] Can navigate through DICOM slices
- [ ] Metadata table shows DICOM tags
- [ ] Validation results visible (if any warnings/errors)

---

## Step 5: Verify Data in OHIF Viewer (Alternative Access)

### Access OHIF Viewer

**Open browser:**
```
http://YOUR_ELASTIC_IP/ohif/
```

**You should see:**
- Study list interface
- Uploaded studies listed with:
  - Patient Name
  - Patient ID
  - Study Date
  - Study Description
  - Number of images

### View DICOM Study

1. **Select Study**
   - Click on a study from the list

2. **View Images**
   - Images should load in the viewer
   - Should see:
     - DICOM image display
     - Image metadata panel
     - Window/Level controls
     - Zoom, pan, scroll tools

3. **Test Viewer Features**
   - **Scroll through slices:** Mouse wheel or drag
   - **Adjust window/level:** Right-click and drag
   - **Zoom:** Mouse wheel or pinch gesture
   - **Pan:** Middle-click drag or two-finger drag
   - **Measurements:** Use measurement tools in toolbar

4. **Verify Image Quality**
   - Images render correctly
   - No artifacts or corruption
   - Metadata displays accurately

---

## Step 5: Verify Data in dcm4chee Admin UI

### Access dcm4chee Admin Console

**Open browser:**
```
http://YOUR_ELASTIC_IP/dcm4chee-arc/ui2/
```

**Login:**
- Username: `admin`
- Password: `admin`

### Check Study List

1. **Navigate to Studies**
   - Click "Studies" in the left menu

2. **Search for Studies**
   - Leave filters empty or search by Patient ID
   - Click "Search"

3. **Verify Study Details**
   - Should see uploaded studies with:
     - Patient demographics
     - Study metadata
     - Series count
     - Instance count
     - Storage location

4. **View Series Details**
   - Expand study to see series
   - Expand series to see instances
   - Verify instance count matches uploaded files

---

## Step 6: Verify Metadata in OpenSearch

### Access OpenSearch Dashboards

**Open browser:**
```
http://YOUR_ELASTIC_IP/opensearch-dashboards/
```

**Login:**
- Username: `admin`
- Password: `admin`

### Query DICOM Metadata

1. **Navigate to Discover**
   - Click "Discover" in left menu

2. **Select Index Pattern**
   - Select `dicom-*` or `kaapana-*` index pattern

3. **Search for Studies**
   - In search bar: `PatientID:"POC001"`
   - Or: `StudyInstanceUID:*`
   - Set time range to "Last 7 days"

4. **Verify Indexed Data**
   - Should see DICOM metadata documents
   - Check fields:
     - PatientName
     - PatientID
     - StudyInstanceUID
     - SeriesInstanceUID
     - Modality
     - StudyDate
     - NumberOfStudyRelatedInstances

5. **Create Visualization (Optional)**
   - Create bar chart of studies by modality
   - Create table showing patient list

---

## Step 7: Verify Storage in MinIO

### Access MinIO Console

**Open browser:**
```
http://YOUR_ELASTIC_IP/minio-console/
```

**Login:**
- Username: `minio`
- Password: `minio123`

### Check Object Storage

1. **Navigate to Buckets**
   - Click "Buckets" in left menu

2. **View DICOM Bucket**
   - Should see bucket named `dicom` or `kaapana-dicom`
   - Click on bucket name

3. **Browse DICOM Objects**
   - Should see organized structure:
     - Study UID folders
     - Series UID subfolders
     - DICOM instance files

4. **Verify File Count**
   - File count should match uploaded instances

---

## Testing Checklist

Verify the following:

### Data Ingestion Pipeline
- [ ] DICOM port 11112 accessible
- [ ] CTP (Clinical Trial Processor) service running
- [ ] Service DAGs active in Airflow

### DICOM Upload
- [ ] Successfully uploaded DICOM files via DIMSE (dcmsend)
- [ ] Correctly specified project and dataset names
- [ ] No upload errors in dcmsend output
- [ ] (Optional) Successfully uploaded DICOM files via web UI
- [ ] Upload logs show successful reception

### Automatic Processing
- [ ] Metadata extracted to OpenSearch (meta-index)
- [ ] Thumbnails generated and stored in MinIO
- [ ] Series-project mappings created
- [ ] Validation completed (check for warnings/errors)
- [ ] Processing completed within 3-5 minutes

### Datasets Gallery View (Primary Verification)
- [ ] Series visible in Workflows → Datasets
- [ ] Thumbnails displayed correctly
- [ ] Metadata cards show patient/study/series info
- [ ] Can search by Patient ID
- [ ] Filters work (Modality, Date, etc.)
- [ ] Multi-select functionality works
- [ ] Can create dataset from selected series
- [ ] Detail view opens with OHIF viewer
- [ ] Validation indicators visible (if any issues)

### DICOM Viewing
- [ ] Can view images in Datasets detail view (OHIF)
- [ ] Can view images via Store → OHIF menu
- [ ] Image rendering correct
- [ ] Can navigate through slices
- [ ] Window/level adjustments work
- [ ] Measurement tools functional

### Backend Storage Verification
- [ ] Studies visible in dcm4chee admin UI
- [ ] Series and instance counts correct
- [ ] Metadata indexed in OpenSearch (meta-index)
- [ ] Can query metadata via OpenSearch Dashboards
- [ ] Thumbnails stored in MinIO buckets

### Project Isolation
- [ ] Data visible only in correct project
- [ ] Data also visible in admin project (default)
- [ ] Project switching updates Datasets view correctly

---

## Troubleshooting

### Upload fails via UI
```bash
# Check Kaapana UI logs
kubectl logs -l app=kaapana-ui -n kaapana

# Check ingress logs
kubectl logs -n ingress -l app.kubernetes.io/name=ingress-nginx

# Verify upload service
kubectl get svc -n kaapana | grep upload
```

### dcmsend fails
```bash
# Check dcm4chee DICOM service
kubectl get svc dcm4chee-arc -n kaapana

# Check if port 11112 accessible
# On AWS: check security group inbound rules
# Add rule: TCP 11112 from your IP

# Test from AWS server:
telnet localhost 11112
# Should connect

# Check dcm4chee logs
kubectl logs -l app=dcm4chee -n kaapana | grep -i "dicom\|error"
```

### Studies not appearing in OHIF
```bash
# Check OpenSearch connectivity
kubectl logs -l app=ohif -n kaapana

# Check if metadata indexed
curl -u admin:admin http://localhost:9200/dicom-*/_search?pretty

# Restart OHIF
kubectl rollout restart deployment ohif-viewer -n kaapana
```

### Images not displaying in OHIF
```bash
# Check OHIF viewer logs
kubectl logs -l app=ohif -n kaapana

# Check dcm4chee WADO service
kubectl port-forward svc/dcm4chee-arc 8080:8080 -n kaapana &
curl http://localhost:8080/dcm4chee-arc/aets/DCM4CHEE/wado
kill %1

# Verify study accessible via DICOMweb
# In browser: http://YOUR_IP/dcm4chee-arc/aets/DCM4CHEE/rs/studies
```

### OpenSearch not indexing
```bash
# Check OpenSearch status
kubectl get pods -l app=opensearch -n kaapana

# Check indexing service logs
kubectl logs -l app=kaapana-indexing -n kaapana

# Manually trigger indexing
# (depends on Kaapana architecture - check workflows)
```

---

## Next Steps

✅ **DICOM data successfully uploaded and verified!**

**Next:** [08-workflow-testing.md](08-workflow-testing.md)

You'll test Airflow workflows and AI processing pipelines (nnU-Net segmentation).

---

## Quick Reference

**Upload via dcmsend:**
```bash
kubectl port-forward -n kaapana svc/dcm4chee-arc 11112:11112 &
dcmsend localhost 11112 -aec DCM4CHEE *.dcm
kill %1
```

**Check study count:**
```bash
curl -u admin:admin http://localhost:9200/dicom-*/_count?pretty
```

**Access URLs:**
- OHIF: http://YOUR_IP/ohif/
- dcm4chee: http://YOUR_IP/dcm4chee-arc/ui2/
- OpenSearch: http://YOUR_IP/opensearch-dashboards/
- MinIO: http://YOUR_IP/minio-console/

---

**Document Status:** ✅ Complete  
**Next Document:** 08-workflow-testing.md
