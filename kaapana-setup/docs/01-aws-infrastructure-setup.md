# 01 - AWS Infrastructure Setup

**Phase:** 1 - Preparation  
**Duration:** 30-60 minutes  

---

## Overview

This guide covers setting up your AWS infrastructure for Kaapana deployment. You'll create an EC2 instance with proper security groups and storage configuration.

---

## What You'll Create

- 1x EC2 instance (r5.2xlarge or r5.4xlarge)
- Security group with required ports
- 500GB gp3 SSD storage
- Elastic IP (optional but recommended)
- SSH key pair for access

**Prerequisite:** 
- AWS account with billing enabled
- Terraform >= 1.5.0 installed
- AWS CLI installed
- An SSH key pair. If you don't have one, generate it:
  ```bash
  ssh-keygen -t ed25519 -f ~/.ssh/kaapana-poc -C "your_email@example.com"
  # Follow the prompts. This will create kaapana-poc (private) and kaapana-poc.pub (public) in ~/.ssh/
  ```
---

## Step 1: AWS Account Setup

### Verify AWS Access

```bash
# Install AWS CLI (if not installed)
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Configure AWS CLI
aws configure --profile kaapana
# Enter:
# - AWS Access Key ID
# - AWS Secret Access Key
# - Default region (e.g., us-east-1)
# - Default output format: json

# Verify access
aws sts get-caller-identity --profile kaapana
```

**Expected Output:**
```json
{
    "UserId": "AIDAXXXXXXXXXX",
    "Account": "123456789012",
    "Arn": "arn:aws:iam::123456789012:user/your-username"
}
```

---

## Step 2: Choose AWS Region

**Recommended Regions:**
- `us-east-1` (N. Virginia) - Lowest cost, most services
- `us-west-2` (Oregon) - Good for West Coast
- `eu-central-1` (Frankfurt) - Good for Europe
- `ap-southeast-1` (Singapore) - Good for Asia

---

## Step 3: Terraform S3 Backend Setup

This project uses a remote S3 backend to store the Terraform state. This is a best practice for teams, as it ensures that everyone is working with the same state and prevents conflicts.

The configuration is defined in `aws-infra/versions.tf`:

```terraform
terraform {
  backend "s3" {
    bucket       = "223271671018-kaapana-ec2-tfstate"
    key          = "poc/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
    profile      = "kaapana"
  }
}
```

You need to ensure that the S3 bucket `223271671018-kaapana-ec2-tfstate` exists in the `us-east-1` region and that you have the necessary permissions to read and write to it using the `kaapana` AWS profile.

If the bucket does not exist, you can create it with the following command:

```bash
aws s3api create-bucket --bucket 223271671018-kaapana-ec2-tfstate --region us-east-1 --profile kaapana
```

---

## Step 4: Deploy Infrastructure with Terraform

This project uses Terraform to provision the entire AWS infrastructure, including the VPC, security groups, EC2 instance, and Elastic IP.

### 1. Navigate to the Terraform Directory

```bash
cd aws-infra
```

### 2. Initialize Terraform

This command initializes the Terraform working directory, downloading the necessary providers and setting up the S3 backend.

```bash
terraform init
```

### 3. Review the Terraform Plan

This command creates an execution plan, which lets you preview the changes that Terraform plans to make to your infrastructure.

```bash
terraform plan
```

You will see a summary of the resources that will be created, such as the VPC, subnets, security groups, EC2 instance, and Elastic IP.

### 4. Apply the Terraform Configuration

This command applies the changes required to reach the desired state of the configuration.

```bash
terraform apply
```

Terraform will ask for confirmation before proceeding. Type `yes` to create the resources.

This process will take a few minutes. Once completed, Terraform will output the public IP of the EC2 instance.

---

## Step 5: Connect to the Instance

After the `terraform apply` command completes, you can get the public IP from the Terraform outputs.

```bash
terraform output ec2_public_ip
```

Now, you can connect to the instance using SSH:

```bash
ssh -i ~/.ssh/kaapana-poc ubuntu@$(terraform output -raw ec2_public_ip)
```

**Note:** The `user_data.sh` script will be executed on the first boot of the instance. It will update the system and install some basic utilities. You can check the log at `/var/log/user-data.log` on the instance.

---

## Step 6: Verify the Setup

You can verify the created resources in the AWS console or by using the AWS CLI.

---

## Step 7: Destroying the Infrastructure

When you are finished with the Kaapana POC, you can destroy all the resources created by Terraform to avoid incurring further costs.

```bash
terraform destroy
```

Terraform will ask for confirmation. Type `yes` to proceed.

