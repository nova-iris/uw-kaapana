# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Kaapana is an open-source medical data analysis platform built for federated learning scenarios with a focus on radiological and radiotherapeutic imaging. This repository contains the infrastructure and setup documentation for deploying Kaapana on AWS as a Proof of Concept (POC).

### Architecture

This repository has three main components:

1. **aws-infra/**: Terraform infrastructure for AWS deployment
2. **kaapana-setup/**: Complete POC setup documentation and guides
3. **public/kaapana/**: The main Kaapana platform source code

The project uses a "build from source" approach since DKFZ registry credentials are not available, requiring local Docker image builds.

## Key Development Commands

### Infrastructure (aws-infra/)

```bash
# Initialize and deploy AWS infrastructure
cd aws-infra
terraform init
terraform plan
terraform apply

# Destroy infrastructure
terraform destroy

# Get outputs
terraform output
```

### Build System

The build system is the core of Kaapana development:

```bash
# Navigate to build scripts
cd public/kaapana/build-scripts

# Create build configuration from template
cp build-config-template.yaml build-config.yaml

# Install build dependencies
pip install -r requirements.txt

# Start build process (takes 1-2 hours, builds 90+ containers)
python3 start_build.py \
  --config build-config.yaml \
  --build-only \
  --parallel 4

# Build and push to ECR
python3 start_build.py \
  --config build-config.yaml \
  --registry-url <account-id>.dkr.ecr.<region>.amazonaws.com \
  --username AWS \
  --password $(aws ecr get-login-password --region <region>)
```

### Platform Deployment

```bash
# Install MicroK8s dependencies
sudo snap install microk8s --classic
microk8s enable dns storage ingress registry

# Deploy platform
cd public/kaapana/platforms
./deploy_platform_template.sh

# Or use Helm directly
helm upgrade --install kaapana-platform ./kaapana-platform-chart -n kaapana
```

### Testing and Verification

```bash
# Check pod status
kubectl get pods -n kaapana

# Check services
kubectl get svc -n kaapana

# Access logs
kubectl logs <pod-name> -n kaapana -f

# Run health check
~/health-check.sh
```

## Build System Architecture

Kaapana uses a sophisticated build system located in `public/kaapana/build-scripts/`:

### Core Components

- **start_build.py**: Main build orchestrator
- **build-config-template.yaml**: Build configuration template
- **build_helper/**: Python modules for build management
  - `build/`: Core build logic and state management
  - `container/`: Docker container building and pushing
  - `helm/`: Helm chart generation and validation
  - `cli/`: Command-line interface and configuration loading

### Build Configuration

Key configuration options in `build-config.yaml`:

- `default_registry`: Container registry URL
- `build_only`: Build without pushing to registry
- `parallel_processes`: Number of parallel build processes (typically 4)
- `platform_filter`: Chart name filter (kaapana-admin-chart)
- `enable_build_kit`: Use Docker BuildKit for faster builds

### Container Categories

The build system creates ~90 Docker containers organized by:

- **base/**: Base Python images (CPU/GPU variants)
- **services/**: Core services (Airflow, OpenSearch, dcm4chee, etc.)
- **applications/**: Web applications (OHIF viewer, admin interfaces)
- **flow/**: Workflow processing containers
- **operators/**: Airflow operators for workflows

## Platform Architecture

### Services Structure

```
public/kaapana/services/
├── base/              # Core backend services (kaapana-backend, workflow-api)
├── applications/      # User-facing apps (OHIF, Collabora, EDK)
├── data-separation/   # Multi-tenant data management
├── flow/              # Workflow processing engines
├── kaapana-admin/     # Administrative interfaces
├── meta/              # Metadata and monitoring
├── store/             # PACS and storage systems
└── utils/             # Utility services
```

### Deployment Structure

```
public/kaapana/platforms/
├── kaapana-platform-chart/    # Main platform Helm chart
├── kaapana-admin-chart/       # Admin interface Helm chart
└── deploy_platform_template.sh # Deployment script
```

## Development Workflow

### For POC Setup (Following Documentation)

1. **Infrastructure Setup**: Use `aws-infra/` Terraform scripts
2. **Build Machine**: Prepare build environment with Docker and dependencies
3. **Build Kaapana**: Run `start_build.py` - takes 1-2 hours
4. **Deploy**: Transfer artifacts and deploy to AWS instance
5. **Test**: Upload DICOM data and test workflows

### For Development/Testing

```bash
# Build specific service
cd public/kaapana/services/<service-name>
docker build -t test-image .

# Test local changes
docker run -it test-image bash

# Push to registry for testing
docker push <registry>/<image>:tag

# Update Helm values
helm upgrade kaapana-platform ./kaapana-platform-chart \
  -n kaapana -f values.yaml
```

## Key Services and Access Points

After deployment, services are accessible via these URLs:

- **Kaapana UI**: http://YOUR_IP/ (kaapana/kaapana)
- **Airflow**: http://YOUR_IP/flow/ (workflow management)
- **OHIF Viewer**: http://YOUR_IP/ohif/ (DICOM viewer)
- **dcm4chee**: http://YOUR_IP/dcm4chee-arc/ui2/ (PACS admin)
- **OpenSearch**: http://YOUR_IP/opensearch-dashboards/ (metadata search)
- **MinIO**: http://YOUR_IP/minio-console/ (object storage)

## Common Development Tasks

### Testing Workflow Changes

```bash
# Modify workflow DAG
cd public/kaapana/data-processing/kaapana-plugin/extension/

# Rebuild specific container
docker build -t local-only/workflow-container .

# Update deployment
kubectl set image deployment/<name> <container>=local-only/workflow-container -n kaapana
```

### Adding New Services

1. Create service directory under `services/`
2. Add Dockerfile and requirements
3. Add to `build-config.yaml` components
4. Create Helm chart values
5. Update platform deployment scripts

### Debugging Build Issues

```bash
# Check build logs
tail -f public/kaapana/build-scripts/build.log

# Build single component for debugging
python3 start_build.py --config build-config.yaml --platform-filter <component>

# Check Docker images
docker images | grep local-only
```

## Important Notes

- **Build Time**: Full build takes 1-2 hours and requires 200GB+ disk space
- **Memory**: Build machine needs 16GB+ RAM for parallel builds
- **Network**: Build requires internet access for base images and dependencies
- **ECR Option**: Images can be pushed to AWS ECR for centralized storage
- **Helm Charts**: Generated automatically during build process

## Documentation References

The `kaapana-setup/docs/` directory contains comprehensive guides:

- **01-aws-infrastructure-setup.md**: AWS infrastructure deployment
- **02-build-machine-preparation.md**: Build environment setup
- **03-kaapana-build-process.md**: Complete build instructions
- **05-server-installation.md**: Kubernetes and MicroK8s setup
- **06-platform-deployment.md**: Platform deployment
- **07-data-upload-testing.md**: DICOM data testing
- **08-workflow-testing.md**: Airflow workflow testing
- **commands-reference.md**: Quick command reference

## Testing and Validation

Always verify deployment using these commands:

```bash
# Check cluster status
microk8s status
kubectl get nodes

# Check all pods
kubectl get pods -A

# Check Kaapana-specific pods
kubectl get pods -n kaapana

# Test service accessibility
curl -I http://localhost/
kubectl get ingress -n kaapana
```

This project represents a complete medical imaging platform deployment with enterprise-grade components including PACS, workflow management, and federated learning capabilities.