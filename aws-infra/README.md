# Kaapana POC AWS Infrastructure

This Terraform configuration creates all the necessary AWS infrastructure for Kaapana POC deployment with support for multi-instance architecture and container registry.

## Architecture Overview

The infrastructure consists of:

- **VPC**: New VPC with public and private subnets across 2 availability zones
- **Networking**: Internet Gateway, NAT Gateway, route tables with cost-optimized single NAT gateway
- **Security**: Security groups with proper port access rules and IAM roles
- **Storage**: Encrypted EBS volumes (configurable root volumes, 500GB default)
- **Compute**: Primary EC2 instance (r5.2xlarge, Ubuntu 24.04 LTS) with optional secondary instance
- **Container Registry**: ECR repository for Docker images with lifecycle policies
- **IP Management**: Elastic IP for static public IP on primary instance
- **Encryption**: KMS key for EBS volume encryption with automatic rotation
- **State Management**: S3 backend with state locking and encryption

## Prerequisites

1. AWS CLI configured with `kaapana` profile
2. SSH key pair at `~/.ssh/kaapana-poc.pub` (or path specified in variables)
3. Terraform >= 1.5.0
4. S3 bucket for Terraform state management (configured in versions.tf)

## Configuration

Key variables that can be customized:

### Core Infrastructure
- `aws_region`: AWS region (default: us-east-1)
- `vpc_cidr`: VPC CIDR block (default: 10.0.0.0/16)
- `availability_zones`: List of availability zones (auto-discovered if empty)

### Compute Configuration
- `instance_type`: Primary EC2 instance type (default: r5.2xlarge)
- `root_volume_size`: Primary instance root volume size in GB (default: 500GB)
- `enable_secondary_instance`: Create secondary EC2 instance (default: true)
- `secondary_root_volume_size`: Secondary instance root volume size (default: 500GB)

### Security and Access
- `allowed_cidr_blocks`: CIDR blocks for Kaapana services access (default: 0.0.0.0/0)
- `ssh_cidr_blocks`: CIDR blocks for SSH access (default: 0.0.0.0/0)
- `enable_ebs_encryption`: Enable EBS volume encryption (default: true)

### SSH Configuration
- `create_key_pair`: Create EC2 key pair from local public key (default: true)
- `public_key_path`: Path to SSH public key (default: ~/.ssh/kaapana-poc.pub)
- `key_name`: Name of the EC2 key pair (default: kaapana-poc-key)

### ECR Configuration
- `allowed_principal_arns`: List of AWS principal ARNs allowed to access ECR repository

## Usage

```bash
# Initialize Terraform
terraform init

# Validate configuration
terraform validate

# Review execution plan
terraform plan

# Deploy infrastructure
terraform apply

# Get outputs
terraform output
```

## Security Groups

The configuration creates a security group with the following inbound rules:

- **SSH (22)**: Access configurable via `ssh_cidr_blocks`
- **HTTP (80)**: Redirect to HTTPS
- **HTTPS (443)**: Web interface access
- **DICOM (11112)**: Medical imaging data transfer
- **Kaapana Services (5000-5020)**: Application services

## Module Structure

```
aws-infra/
├── main.tf                 # Root configuration with local values and module calls
├── variables.tf            # Input variables
├── outputs.tf              # Output values
├── versions.tf             # Provider versions and S3 backend configuration
├── data.tf                 # Data sources (AMI, availability zones, etc.)
├── user_data.sh            # Instance initialization script
└── modules/                # Reusable modules
    ├── vpc/               # VPC and networking using terraform-aws-modules/vpc
    ├── security/          # Security groups, IAM roles, and KMS encryption
    ├── storage/           # EBS volumes (currently commented out in main.tf)
    ├── ec2/               # EC2 instances using terraform-aws-modules/ec2-instance
    ├── ecr/               # ECR repository with lifecycle policies
    └── elastic-ip/        # Elastic IP management
```

## Key Features

### Multi-Instance Support
- Primary instance for Kaapana platform deployment
- Optional secondary instance for build/workload separation
- Independent root volume configuration for each instance

### Container Registry
- ECR repository with automatic image scanning on push
- Lifecycle policies to manage image retention
- Configurable access policies for multiple principals

### Security Features
- KMS key with automatic rotation for EBS encryption
- IAM roles with granular permissions for EC2 instances
- Security groups with port-specific ingress rules
- ECR access policies for secure container operations

### State Management
- S3 backend with encryption and state locking
- Remote state storage for team collaboration
- Version control infrastructure state

## Outputs

After deployment, the following outputs are available:

### Primary Instance
- `instance_id`: Primary EC2 instance identifier
- `instance_public_ip`: Public IP address of primary instance
- `elastic_ip`: Static Elastic IP address (assigned to primary instance)
- `connection_info`: Primary instance connection details (SSH host, user, key, URL)

### Secondary Instance (if enabled)
- `secondary_instance_id`: Secondary EC2 instance identifier
- `secondary_instance_public_ip`: Public IP address of secondary instance
- `secondary_instance_enabled`: Boolean indicating if secondary instance is deployed
- `secondary_connection_info`: Secondary instance connection details

### Network
- `vpc_cidr`: VPC CIDR block

### Example Usage

```bash
# Get all outputs
terraform output

# Get specific output
terraform output elastic_ip

# Connect to primary instance
ssh -i ~/.ssh/kaapana-poc ubuntu@$(terraform output -raw elastic_ip)
```

## Cost Estimate

**Monthly estimated costs (on-demand pricing in us-east-1):**

### Primary Instance (always deployed)
- r5.2xlarge EC2: ~$368/month
- 500GB gp3 root volume: ~$43/month

### Secondary Instance (optional, default disabled)
- r5.4xlarge EC2: ~$736/month
- 500GB gp3 root volume: ~$43/month

### Shared Resources
- VPC, NAT Gateway: ~$32/month
- Elastic IP: Free when attached to running instance
- ECR repository: Minimal storage costs
- KMS key: ~$1/month
- Data transfer: Varies by usage

**Estimated total with secondary instance: ~$1,223/month plus data transfer**
**Estimated total without secondary instance: ~$444/month plus data transfer**

*Note: To disable secondary instance, set `enable_secondary_instance = false` in variables.tf*

## Cleanup

To destroy all created resources:

```bash
terraform destroy
```