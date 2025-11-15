#!/bin/bash

# Filter Valid DICOM Files for dcmsend Upload
# This script identifies DICOM files that dcmsend will accept
#
# Usage:
#   ./filter-samples.sh <source_dir> [output_dir]
#   ./filter-samples.sh pydicom-samples valid-dicom-samples
#   ./filter-samples.sh /d/repos/upwork/kaapana/dicom-samples/pydicom-data-master/data
#
# Examples:
#   ./filter-samples.sh pydicom-samples              # Use default output dir
#   ./filter-samples.sh . filtered                   # Filter current dir into filtered/
#   ./filter-samples.sh /path/to/dicom clean-dcm    # Filter specific path

# Don't exit on first error - we want to see all results
set +e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Parse arguments
if [ $# -lt 1 ]; then
    echo -e "${RED}Error: Missing required argument${NC}"
    echo ""
    echo -e "${CYAN}Usage: $0 <source_dir> [output_dir]${NC}"
    echo ""
    echo -e "${CYAN}Examples:${NC}"
    echo "  $0 pydicom-samples              # Use default output dir: valid-dicom-samples"
    echo "  $0 . filtered                   # Filter current dir into filtered/"
    echo "  $0 /path/to/dicom clean-dcm    # Filter specific path into clean-dcm/"
    echo ""
    exit 1
fi

SOURCE_DIR="$1"
OUTPUT_DIR="${2:-valid-dicom-samples}"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}DICOM File Validation for dcmsend${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Check if source directory exists
if [ ! -d "$SOURCE_DIR" ]; then
    echo -e "${RED}Error: Source directory '$SOURCE_DIR' not found${NC}"
    echo -e "${YELLOW}Please provide a valid source directory as first argument${NC}"
    exit 1
fi

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Check if output directory was created successfully
if [ ! -d "$OUTPUT_DIR" ]; then
    echo -e "${RED}Error: Could not create output directory '$OUTPUT_DIR'${NC}"
    exit 1
fi

# Statistics
total_files=0
valid_files=0
invalid_sop_class=0
invalid_format=0
already_valid=0

echo -e "${BLUE}Scanning DICOM files in: $SOURCE_DIR${NC}"
echo -e "${BLUE}Output directory: $OUTPUT_DIR${NC}"
echo ""

# Count total DCM files first (try find first, then ls as fallback)
total_dcm=$(find "$SOURCE_DIR" -name "*.dcm" -type f 2>/dev/null | wc -l)

# If find returns 0, try ls as fallback
if [ "$total_dcm" -eq 0 ]; then
    total_dcm=$(ls "$SOURCE_DIR"/*.dcm 2>/dev/null | wc -l)
fi

if [ "$total_dcm" -eq 0 ]; then
    echo -e "${RED}Error: No DICOM files (*.dcm) found in $SOURCE_DIR${NC}"
    echo -e "${YELLOW}Please check the source directory path${NC}"
    exit 1
fi

echo -e "${CYAN}Found $total_dcm DICOM files to process${NC}"
echo ""

# Find all .dcm files and validate them (try find first, then ls as fallback)
file_list=$(find "$SOURCE_DIR" -name "*.dcm" -type f 2>/dev/null | sort)

# If find returns nothing, use ls as fallback
if [ -z "$file_list" ]; then
    file_list=$(ls "$SOURCE_DIR"/*.dcm 2>/dev/null | sort)
fi

# Process the files
while IFS= read -r file; do
    ((total_files++))
    filename=$(basename "$file")
    progress="[$total_files/$total_dcm]"
    
    # Check if file already exists in output dir
    if [ -f "$OUTPUT_DIR/$filename" ]; then
        echo -e "${YELLOW}⊘ Exists:${NC} $progress $filename (already in output dir)"
        ((already_valid++))
        continue
    fi
    
    # Use dcmdump to validate the file (suppress error output)
    dcmdump_output=$(dcmdump "$file" 2>&1)
    if ! echo "$dcmdump_output" | grep -q "# Dicom-Data-Set"; then
        echo -e "${RED}✗ Invalid:${NC} $progress $filename (not a valid DICOM file)"
        ((invalid_format++))
        continue
    fi
    
    # Check for unknown transfer syntax in file meta information
    if echo "$dcmdump_output" | head -10 | grep -q "Unknown Transfer Syntax"; then
        echo -e "${YELLOW}⚠ Skipped:${NC} $progress $filename (unknown transfer syntax in file meta)"
        ((invalid_sop_class++))
        continue
    fi
    
    # Extract Transfer Syntax UID first (dcmsend compatibility check)
    # Try to get numeric UID first (format: 1.2.840.10008.x.y.z)
    transfer_syntax=$(dcmdump "$file" 2>/dev/null | grep "TransferSyntaxUID" | head -1 | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)+')
    
    # If not numeric, try keyword format
    if [ -z "$transfer_syntax" ]; then
        transfer_syntax=$(dcmdump "$file" 2>/dev/null | grep "TransferSyntaxUID" | head -1 | grep -oE '=[A-Za-z0-9]+' | sed 's/=//g')
    fi
    
    # List of unsupported transfer syntaxes for dcmsend
    # These are known to cause "Unknown Transfer Syntax" errors
    # Format: both numeric UIDs and keyword names
    unsupported_syntaxes=(
        # Numeric UIDs
        "1.2.840.10008.1.2.2"         # Explicit VR Big Endian (deprecated)
        "1.2.840.10008.1.2.4.90"      # JPEG 2000 Lossless
        "1.2.840.10008.1.2.4.91"      # JPEG 2000 Lossy
        "1.2.840.10008.1.2.4.201"     # High-Throughput JPEG 2000 Lossless
        "1.2.840.10008.1.2.4.202"     # High-Throughput JPEG 2000 Lossless with RPT
        "1.2.840.10008.1.2.4.203"     # High-Throughput JPEG 2000 Lossy
        "1.2.840.10008.1.2.4.204"     # High-Throughput JPEG 2000 Lossy with RPT
        "1.2.840.10008.1.2.5"         # RLE Lossless
        "1.2.840.10008.1.2.8.1"       # Deflate/ZLIB Lossless
        "1.2.840.10008.1.2.4.80"      # JPEG-LS Lossless
        "1.2.840.10008.1.2.4.81"      # JPEG-LS Lossy (Near-Lossless)
        "1.2.840.10008.1.2.4.100"     # MPEG-2
        "1.2.840.10008.1.2.4.101"     # MPEG-2 Main Profile
        "1.2.840.10008.1.2.4.103"     # MPEG-4
        "1.2.840.10008.1.2.4.104"     # MPEG-4 AVC/H.264
        # Keyword names
        "BigEndianExplicit"
        "BigEndian"
        "JPEG2000Lossless"
        "JPEG2000LosslessOnly"
        "JPEG2000Lossy"
        "JPEG2000Part2Lossless"
        "JPEG2000Part2Lossy"
        "HighThroughputJPEG2000Lossless"
        "HighThroughputJPEG2000LosslessRPT"
        "HighThroughputJPEG2000Lossy"
        "HighThroughputJPEG2000LossyRPT"
        "RLELossless"
        "DeflateExplicitVR"
        "JPEGLSLossless"
        "JPEGLSLossy"
        "MPEG2MainProfile"
        "MPEG2HighProfile"
        "MPEG4AVCBaseline"
        "MPEG4AVCMain"
        "MPEG4AVCHighProfile"
    )
    
    # Check if transfer syntax is in unsupported list
    if [ -n "$transfer_syntax" ]; then
        for unsupported in "${unsupported_syntaxes[@]}"; do
            if [ "$transfer_syntax" = "$unsupported" ]; then
                echo -e "${YELLOW}⚠ Skipped:${NC} $progress $filename (unsupported transfer syntax: $transfer_syntax)"
                ((invalid_sop_class++))
                continue 2  # Continue outer loop (while loop)
            fi
        done
    fi
    
    # Extract SOP Class UID (handle both numeric and keyword formats)
    sop_class=$(dcmdump "$file" 2>/dev/null | grep "SOPClassUID" | head -1 | grep -oE '\[.*\]|=[A-Za-z]+' | sed 's/[\[\]=]//g')
    
    # If sop_class is empty or only whitespace, try alternative parsing
    if [ -z "$sop_class" ]; then
        sop_class=$(dcmdump "$file" 2>/dev/null | grep "(0008,0016)" | awk '{print $3}' | sed 's/[\[\]]//g')
    fi
    
    # Check if SOP Class UID is valid (not empty and not a known problematic UID)
    if [ -z "$sop_class" ]; then
        echo -e "${YELLOW}⚠ Skipped:${NC} $progress $filename (missing SOP Class UID)"
        ((invalid_sop_class++))
        continue
    fi
    
    # Exclude known problematic test files
    case "$sop_class" in
        "1.2.840.10008.5.1.4.1.1.104.1" | "1.2.840.10008.5.1.1.1" | "1.2.840.10008.5.1.1.2")
            # These are known problematic test UIDs
            echo -e "${YELLOW}⚠ Skipped:${NC} $progress $filename (problematic SOP Class: $sop_class)"
            ((invalid_sop_class++))
            continue
            ;;
    esac
    
    # File is valid - copy it
    if cp "$file" "$OUTPUT_DIR/" 2>/dev/null; then
        echo -e "${GREEN}✓ Valid:${NC} $progress $filename (SOP: ${sop_class:0:30}...)"
        ((valid_files++))
    else
        echo -e "${RED}✗ Failed:${NC} $progress $filename (could not copy)"
        ((invalid_format++))
    fi
done <<< "$file_list"

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Summary${NC}"
echo -e "${BLUE}========================================${NC}"
echo -e "Total files scanned:        ${CYAN}$total_files${NC}"
echo -e "Valid files copied:         ${GREEN}$valid_files${NC}"
echo -e "Already in output:          ${YELLOW}$already_valid${NC}"
echo -e "Invalid format:             ${RED}$invalid_format${NC}"
echo -e "Invalid/missing SOP Class:  ${YELLOW}$invalid_sop_class${NC}"
echo ""
echo -e "Output directory: ${CYAN}$OUTPUT_DIR/${NC}"
echo -e "Total ready for upload:     ${GREEN}$((valid_files + already_valid))${NC} files"
echo ""

if [ $((valid_files + already_valid)) -gt 0 ]; then
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}Ready for Upload!${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    echo -e "${CYAN}Your files are ready in:${NC} ${GREEN}$OUTPUT_DIR/${NC}"
    echo ""
    echo -e "${CYAN}Upload command:${NC}"
    echo ""
    echo "dcmsend -v kaapana.novairis.site 11112 \\"
    echo "  --aetitle kp-sample \\"
    echo "  --call kp-admin \\"
    echo "  --scan-directories \\"
    echo "  --scan-pattern '*.dcm' \\"
    echo "  --recurse $OUTPUT_DIR/"
    echo ""
else
    echo -e "${RED}========================================${NC}"
    echo -e "${RED}No valid DICOM files found for upload${NC}"
    echo -e "${RED}========================================${NC}"
    echo ""
    echo -e "${YELLOW}Please check:${NC}"
    echo "  1. Source directory path exists: $SOURCE_DIR"
    echo "  2. Directory contains .dcm files"
    echo "  3. DICOM files are not corrupted"
    echo ""
    exit 1
fi
