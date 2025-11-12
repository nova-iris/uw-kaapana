# Kaapana POC Setup Documentation

**Project:** Kaapana Proof of Concept Deployment  
**Cloud Provider:** AWS (Amazon Web Services)  
**Deployment Method:** Build from Source  
**Last Updated:** November 12, 2025

---

## Documentation Structure

This documentation is organized into focused, step-by-step guides:

### 📋 Planning Documents
- **[milestones.md](milestones.md)** - Project milestones and deliverables
- **[clarification-questions.md](clarification-questions.md)** - Requirements and answers

### 🚀 Setup Guides (Follow in Order)

#### Phase 1: Preparation
1. **[01-aws-infrastructure-setup.md](01-aws-infrastructure-setup.md)**
   - AWS account setup
   - EC2 instance provisioning
   - Security group configuration
   - Storage setup

2. **[02-build-machine-preparation.md](02-build-machine-preparation.md)**
   - Build machine requirements
   - Dependencies installation
   - Docker and Helm setup

#### Phase 2: Build Process
3. **[03-kaapana-build-process.md](03-kaapana-build-process.md)**
   - Clone repository
   - Configure build settings
   - Execute build
   - Verify artifacts

4. **[04-artifact-transfer.md](04-artifact-transfer.md)**
   - Transfer containers to AWS
   - Prepare deployment artifacts

#### Phase 3: Deployment
5. **[05-server-installation.md](05-server-installation.md)**
   - Install MicroK8s
   - Configure Kubernetes
   - Verify environment

6. **[06-platform-deployment.md](06-platform-deployment.md)**
   - Deploy Kaapana platform
   - Configure services
   - Verify pods

#### Phase 4: Testing & Validation
7. **[07-data-upload-testing.md](07-data-upload-testing.md)**
   - Obtain DICOM samples
   - Upload test data
   - Verify storage

8. **[08-workflow-testing.md](08-workflow-testing.md)**
   - Test Airflow workflows
   - Run nnU-Net segmentation
   - Validate results

9. **[09-verification-checklist.md](09-verification-checklist.md)**
   - Complete verification steps
   - Performance validation
   - System persistence testing

### 🔧 Reference Documents
- **[troubleshooting.md](troubleshooting.md)** - Common issues and solutions
- **[aws-cost-management.md](aws-cost-management.md)** - Cost optimization tips
- **[commands-reference.md](commands-reference.md)** - Quick command reference

### ⚠️ Alternative Approaches (Not Used)
- **[CONTAINER_ACCESS_OPTIONS.md](CONTAINER_ACCESS_OPTIONS.md)** - Registry alternatives (reference only)
- **[kaapana-build-from-source.md](kaapana-build-from-source.md)** - Original consolidated guide

---

## Quick Start

**Total Time Estimate:** 8-12 days for complete POC

### Prerequisites Checklist
- [ ] AWS account with billing enabled
- [ ] Basic Linux/Ubuntu experience
- [ ] Understanding of Docker and Kubernetes concepts
- [ ] SSH key for AWS access
- [ ] 200GB+ disk space for build

### Fast Track (Experienced Users)
```bash
# 1. Setup AWS (1 hour)
# Follow: 01-aws-infrastructure-setup.md

# 2. Prepare build machine (30 min)
# Follow: 02-build-machine-preparation.md

# 3. Build Kaapana (1-2 hours)
# Follow: 03-kaapana-build-process.md

# 4. Deploy to AWS (30 min)
# Follow: 05-server-installation.md
# Follow: 06-platform-deployment.md

# 5. Test and verify (1-2 hours)
# Follow: 07-data-upload-testing.md
# Follow: 08-workflow-testing.md
```

---

## Timeline Overview

| Phase | Duration | Documents |
|-------|----------|-----------|
| **Phase 1: Infrastructure Setup** | 2-3 days | 01, 02 |
| **Phase 2: Build Kaapana** | 1-2 days | 03, 04 |
| **Phase 3: Deployment** | 1-2 days | 05, 06 |
| **Phase 4: Testing** | 2-3 days | 07, 08, 09 |
| **Total** | **8-12 days** | **POC Complete** |

---

## Why Build from Source?

Since we don't have access to DKFZ container registry credentials, we're building Kaapana from source. This is:

✅ **Fully supported** by the Kaapana team  
✅ **Official approach** documented in Kaapana docs  
✅ **Complete control** over the build process  
✅ **No external dependencies** on registry access  
✅ **Can be customized** if needed

---

## Support and Resources

**Kaapana Official:**
- Documentation: https://kaapana.readthedocs.io/en/latest/
- GitHub: https://github.com/kaapana/kaapana
- Email: kaapana@dkfz-heidelberg.de

**This Project:**
- All documentation in this folder
- Follow documents in numbered order
- Check troubleshooting.md for issues

---

## Document Status

| Document | Status | Last Updated |
|----------|--------|--------------|
| 01-aws-infrastructure-setup.md | ✅ Ready | Nov 12, 2025 |
| 02-build-machine-preparation.md | ✅ Ready | Nov 12, 2025 |
| 03-kaapana-build-process.md | ✅ Ready | Nov 12, 2025 |
| 04-artifact-transfer.md | ✅ Ready | Nov 12, 2025 |
| 05-server-installation.md | ✅ Ready | Nov 12, 2025 |
| 06-platform-deployment.md | ✅ Ready | Nov 12, 2025 |
| 07-data-upload-testing.md | ✅ Ready | Nov 12, 2025 |
| 08-workflow-testing.md | ✅ Ready | Nov 12, 2025 |
| 09-verification-checklist.md | ✅ Ready | Nov 12, 2025 |
| troubleshooting.md | ✅ Ready | Nov 12, 2025 |
| aws-cost-management.md | ✅ Ready | Nov 12, 2025 |
| commands-reference.md | ✅ Ready | Nov 12, 2025 |

---

## Getting Started

**Start here:** [01-aws-infrastructure-setup.md](01-aws-infrastructure-setup.md)

Follow the numbered documents in sequence for a complete POC setup.
