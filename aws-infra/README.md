# Kaapana POC AWS Infrastructure

This Terraform configuration creates all the necessary AWS infrastructure for Kaapana POC deployment.

## Architecture Overview

The infrastructure consists of:

- **VPC**: New VPC with public and private subnets
- **Networking**: Internet Gateway, NAT Gateway, route tables
- **Security**: Security groups with proper port access rules
- **Storage**: Encrypted EBS volumes (500GB gp3 data volume)
- **Compute**: EC2 instance (r5.2xlarge, Ubuntu 24.04 LTS)
- **IP Management**: Elastic IP for static public IP
- **Encryption**: KMS key for EBS volume encryption

## Prerequisites

1. AWS CLI configured with `kaapana` profile
2. SSH key pair at `~/.ssh/id_ed25519.pub`
3. Terraform >= 1.5.0

## Configuration

Key variables that can be customized:

- `aws_region`: AWS region (default: us-east-1)
- `instance_type`: EC2 instance type (default: r5.2xlarge)
- `data_volume_size`: EBS data volume size in GB (default: 500GB)
- `vpc_cidr`: VPC CIDR block (default: 10.0.0.0/16)
- `allowed_cidr_blocks`: CIDR blocks for Kaapana services access
- `ssh_cidr_blocks`: CIDR blocks for SSH access

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
├── main.tf                 # Root configuration
├── variables.tf            # Input variables
├── outputs.tf              # Output values
├── versions.tf             # Provider versions
├── user_data.sh            # Instance initialization script
└── modules/                # Reusable modules
    ├── vpc/               # VPC and networking
    ├── security/          # Security groups and IAM
    ├── storage/           # EBS volumes
    ├── ec2/               # EC2 instances
    └── elastic-ip/        # Elastic IP management
```

## Outputs

After deployment, the following outputs are available:

- `vpc_id`: VPC identifier
- `elastic_ip`: Public IP address of the instance
- `ssh_command`: SSH command to connect to the instance
- `connection_info`: Connection details
- `kaapana_security_group_id`: Security group identifier

## Cost Estimate

**Monthly estimated costs (on-demand pricing in us-east-1):**

- r5.2xlarge EC2: ~$368/month
- 500GB gp3 storage: ~$43/month
- Elastic IP: Free when attached to running instance
- Data transfer: Varies by usage

**Total estimated: ~$411/month plus data transfer**

## Cleanup

To destroy all created resources:

```bash
terraform destroy
```

## Notes

- All EBS volumes are encrypted by default
- The instance includes a basic user data script for initial setup
- IAM role is created with CloudWatch Logs permissions for logging
- The configuration follows Terraform best practices with modular design