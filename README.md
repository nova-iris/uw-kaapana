# Kaapana Medical Imaging Platform

A comprehensive medical data analysis platform built for federated learning scenarios with a focus on radiological and radiotherapeutic imaging.

## Quick Start

Choose your starting point based on what you want to do:

### **Deploy Kaapana on AWS**
`aws-infra/` → Terraform infrastructure for AWS deployment
`kaapana-setup/` → Complete setup documentation and guides

### **Build from Source**
`kaapana-setup/docs/` → Step-by-step build and deployment guides
`public/kaapana/` → Complete Kaapana platform source code

### **Test with Sample Data**
`dicom-samples/` → DICOM file examples for testing

---

## Directory Structure

```
├── aws-infra/          # Terraform AWS infrastructure
├── kaapana-setup/      # Setup guides and pre-built artifacts
│   ├── docs/          # Complete documentation (start here)
│   └── build/         # Pre-built Helm charts and artifacts
├── dicom-samples/     # Sample DICOM files for testing
├── public/kaapana/    # Full Kaapana source code
└── CLAUDE.md          # Development guide for Claude Code
```

## Setup Path

**For complete POC deployment:** Start with `kaapana-setup/docs/README.md`

**For infrastructure only:** Use `aws-infra/README.md`

---
