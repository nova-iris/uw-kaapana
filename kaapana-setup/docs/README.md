# Kaapana POC Setup Documentation

**Project:** Kaapana Proof of Concept Deployment  
**Cloud Provider:** AWS (Amazon Web Services)  
**Deployment Method:** Build from Source or Pre-built Images  
**Last Updated:** November 26, 2025

## Documentation Structure

This documentation provides step-by-step guides for deploying Kaapana on AWS:

### Planning Documents
- **[milestones.md](milestones.md)** - Project milestones and deliverables

### Setup Guides (Follow in Order)

#### Phase 1: Infrastructure & Preparation
1. **[01-aws-infrastructure-setup.md](01-aws-infrastructure-setup.md)**
   - AWS account configuration
   - Terraform infrastructure deployment
   - EC2 instance provisioning with security groups
   - S3 backend setup for state management

2. **[02-build-machine-preparation.md](02-build-machine-preparation.md)**
   - System requirements verification
   - Docker and Helm installation
   - AWS CLI configuration
   - Python environment setup
   - Automated or manual installation options

#### Phase 2: Build Kaapana (Optional)
3. **[03-kaapana-build-process.md](03-kaapana-build-process.md)**
   - Build configuration for GitLab registry
   - Docker image compilation (~90 containers)
   - Registry authentication and push
   - Build verification and troubleshooting

#### Phase 3: Server Setup & Deployment
4. **[04-server-installation.md](04-server-installation.md)**
   - MicroK8s installation
   - Kubernetes cluster configuration
   - Network and firewall setup

5. **[05-platform-deployment.md](05-platform-deployment.md)**
   - Two deployment options:
     - Build from source (local images)
     - Pre-built images (GitLab registry)
   - Core services deployment (dcm4chee, Airflow, OpenSearch, MinIO, Keycloak, OHIF)
   - Platform access and verification

#### Phase 4: Testing & Validation
6. **[06-data-upload-testing.md](06-data-upload-testing.md)**
   - DICOM data ingestion via DIMSE protocol
   - Sample data upload and verification
   - Datasets Gallery View exploration
   - OHIF viewer testing


## Deployment Options

### Option 1: Build from Source
- Full control over build configuration
- Requires ~90GB disk space and 1-2 hours build time
- Images pushed to GitLab registry during build
- Best for: Customization needs, learning the platform

### Option 2: Pre-built Images
- Faster deployment using existing images
- Requires GitLab registry credentials
- No local build required
- Best for: Quick POC setup, standard configurations

## Support Resources

**Kaapana Official:**
- Documentation: https://kaapana.readthedocs.io/en/latest/
- GitHub: https://github.com/kaapana/kaapana
- Email: kaapana@dkfz-heidelberg.de

**This Project:**
- Follow numbered documents sequentially
- Each guide includes troubleshooting sections
- Sample DICOM data provided in `dicom-samples/` directory

## Getting Started

**Start here:** [01-aws-infrastructure-setup.md](01-aws-infrastructure-setup.md)

Follow the numbered documents in sequence for a complete POC setup.
