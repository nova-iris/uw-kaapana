# 07 - Data Upload and DICOM Testing

**Phase:** 4 - Test & Verify  
**Duration:** 30-60 minutes  
**Prerequisite:** 06-platform-deployment.md completed

---

## Overview

This guide tests Kaapana's core DICOM functionality:
- Uploading DICOM images via UI and DICOM protocol
- Storing images in dcm4chee PACS
- Viewing images in OHIF viewer
- Verifying metadata in OpenSearch

---

## Prerequisites Check

```bash
# SSH to AWS server
ssh -i kaapana-poc-key.pem ubuntu@$ELASTIC_IP

# Verify all pods running
kubectl get pods -n kaapana | grep -v "1/1.*Running"
# Should return empty (all pods running)

# Verify Kaapana UI accessible
curl -s -o /dev/null -w "%{http_code}" http://localhost/
# Should return: 200 or 302
```

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

## Step 3: Upload DICOM via DICOM Protocol (dcmsend)

### Install DICOM Toolkit

```bash
# On AWS server
sudo apt update
sudo apt install -y dcmtk

# Verify installation
dcmsend --version
storescu --version
```

### Send DICOM Files to dcm4chee

```bash
# Navigate to DICOM samples
cd ~/dicom-samples

# Get dcm4chee DICOM service details
kubectl get svc dcm4chee-arc -n kaapana

# Typically:
# - AE Title: DCM4CHEE
# - Port: 11112

# Send DICOM files
# Replace <pod-ip> with actual dcm4chee service IP
DICOM_SVC_IP=$(kubectl get svc dcm4chee-arc -n kaapana -o jsonpath='{.spec.clusterIP}')
echo "dcm4chee DICOM service: $DICOM_SVC_IP:11112"

# Send files from inside a pod (easier than external access)
kubectl run dcm-sender \
  --image=dcmtk:latest \
  --rm -it \
  --restart=Never \
  --namespace kaapana \
  -- bash

# Inside pod, send DICOM:
# (You'll need to copy files into the pod first - see alternative below)
```

**Alternative: Send from AWS server using port-forward:**

```bash
# Port-forward dcm4chee DICOM port
kubectl port-forward -n kaapana svc/dcm4chee-arc 11112:11112 &

# Send DICOM files
cd ~/dicom-samples/ct-sample  # or your DICOM directory

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

# Stop port-forward
kill %1
```

### Verify DICOM Upload

```bash
# Check dcm4chee logs for received studies
kubectl logs -l app=dcm4chee -n kaapana --tail=50 | grep -i "store"

# Should show log entries like:
# Store Request received: StudyInstanceUID=1.2.3.4...
# Store completed successfully
```

---

## Step 4: Verify Data in OHIF Viewer

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

### DICOM Upload
- [x] Successfully uploaded DICOM files via UI
- [x] Successfully sent DICOM files via dcmsend
- [x] No upload errors in logs

### DICOM Storage
- [x] Studies visible in dcm4chee admin UI
- [x] Series and instance counts correct
- [x] DICOM files stored in MinIO

### DICOM Viewing
- [x] Studies appear in OHIF study list
- [x] Can open and view studies in OHIF
- [x] Image rendering correct
- [x] Can navigate through slices
- [x] Window/level adjustments work
- [x] Measurement tools functional

### Metadata Indexing
- [x] DICOM metadata indexed in OpenSearch
- [x] Can search and filter studies
- [x] All metadata fields populated correctly

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
