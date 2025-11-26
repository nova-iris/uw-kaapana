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

You have two options for obtaining DICOM data for testing:

### Option 1: Use Repository Sample Data (Recommended for Testing)

The Kaapana repository includes a comprehensive set of sample DICOM files that are perfect for testing the upload pipeline:

```bash
# DICOM samples are already available in the repository
cd ~/uw-kaapana/dicom-samples

# Explore the available samples
ls -la
# Output includes:
# - dicom-samples/s3/: AWS S3 dataset with diverse modalities
# - dicom-samples/sample-1/: Basic DICOM samples (CT, MR, JPEG, etc.)
# - dicom-samples/sample-2/: Advanced DICOM samples with various formats

# Count available files
find . -name "*.dcm" | wc -l
# Should show 40+ DICOM files across different modalities
```

**Available Sample Categories:**
- **CT and MR images**: Standard medical imaging modalities
- **Compression formats**: JPEG, JPEG2000, lossless/lossy variants
- **Color images**: RGB and YBR color space images
- **Special formats**: RT structures, dose plans, overlays, waveforms
- **Validation cases**: Both standard and edge-case DICOM files

### Option 2: Prepare Your Own DICOM Dataset

If you have access to medical DICOM data, you can use your own dataset:

**Requirements:**
- Files must have `.dcm` extension
- Valid DICOM format (can be verified with `dciodvfy` or `pydicom-validator`)
- Any medical imaging modality (CT, MR, XA, US, etc.)
- Complete DICOM headers with PatientID, StudyInstanceUID, SeriesInstanceUID

**Preparing Your Dataset:**
```bash
# Create organized directory structure
mkdir -p ~/my-dicom-data

# Copy your DICOM files
cp /path/to/your/dicom/files/*.dcm ~/my-dicom-data/

# Verify DICOM files are valid
dciodvfy ~/my-dicom-data/*.dcm

# Count files
ls ~/my-dicom-data/*.dcm | wc -l
```

**Important Security Note:**
- Ensure your DICOM data contains **de-identified** patient information
- Remove or replace real Patient Names, IDs, and birth dates
- Use test identifiers like `POC001`, `TEST_PATIENT`, etc.
- Follow HIPAA de-identification standards if using real medical data

**Recommendation:** For initial testing, use the repository samples (Option 1) as they're known to work well with Kaapana's ingestion pipeline.

## Step 2: Upload DICOM via DICOM Protocol (dcmsend) - Recommended

### Install DICOM Toolkit (if not installed)

```bash
# On AWS server or local machine
sudo apt update
sudo apt install -y dcmtk

# Verify installation
dcmsend --version
```

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



## Step 3: View Data in Datasets Gallery (Primary Method)

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

## Step 4: Verify Data in OHIF Viewer (Alternative Access)

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
