# AWS Cost Management and Optimization

**Managing POC Costs and Preparing for Production**

---

## POC Cost Breakdown

### EC2 Instance Costs (On-Demand Pricing, us-east-1)

| Instance Type | vCPU | RAM | Cost/Hour | Cost/Day | Cost/Month (730h) |
|---------------|------|-----|-----------|----------|-------------------|
| **r5.xlarge** | 4 | 32GB | $0.252 | $6.05 | $184 |
| **r5.2xlarge** | 8 | 64GB | $0.504 | $12.10 | $368 |
| **r5.4xlarge** | 16 | 128GB | $1.008 | $24.19 | $736 |

**Recommended for POC:** r5.2xlarge

### Storage Costs (us-east-1)

| Storage Type | Size | Cost/Month |
|-------------|------|------------|
| **gp3 SSD** | 200GB | $16 |
| **gp3 SSD** | 300GB | $24 |
| **gp3 SSD** | 500GB | $40 |

**Recommended for POC:** 200-300GB gp3

### Data Transfer Costs

| Type | Cost |
|------|------|
| **Inbound** | Free |
| **Outbound to Internet** (first 100GB) | Free |
| **Outbound to Internet** (next 10TB) | $0.09/GB |

### Elastic IP Costs

- **Associated with running instance:** Free
- **Not associated (idle):** $0.005/hour (~$3.65/month)

---

## Total POC Cost Estimates

### 2-Week POC (336 hours)

| Component | Cost |
|-----------|------|
| EC2 r5.2xlarge (336h) | $169 |
| EBS 250GB gp3 | $20 |
| Elastic IP | $0 (associated) |
| Data Transfer (est. 50GB) | $0 (within free tier) |
| **TOTAL** | **~$189** |

### 1-Month POC (730 hours)

| Component | Cost |
|-----------|------|
| EC2 r5.2xlarge (730h) | $368 |
| EBS 250GB gp3 | $20 |
| Elastic IP | $0 (associated) |
| Data Transfer (est. 100GB) | $0 (within free tier) |
| **TOTAL** | **~$388** |

---

## Cost Optimization Strategies

### Stop Instance When Not In Use

**Savings:** ~95% of compute costs

```bash
# Stop instance (from AWS CLI)
aws ec2 stop-instances --instance-ids i-xxxxxxxxx

# Start instance
aws ec2 start-instances --instance-ids i-xxxxxxxxx
```

**What's retained:**
- EBS volumes and data
- Elastic IP (if kept associated)
- Instance configuration

**What you're charged for:**
- EBS storage (~$20/month)
- Elastic IP if not associated (~$3.65/month)

**Best for:**
- POC only used during business hours
- Demo environments
- Testing/development

**Example savings:**
- Use 8 hours/day, 5 days/week = ~160 hours/month
- EC2 cost: $0.504 × 160 = $81 (vs. $368 full-time)
- **Monthly savings: $287**

### Use Reserved Instances

**Savings:** Up to 72% off on-demand price

| Commitment | r5.2xlarge Hourly | Monthly (730h) | Savings |
|------------|-------------------|----------------|---------|
| **On-Demand** | $0.504 | $368 | 0% |
| **1-Year, No Upfront** | $0.308 | $225 | 39% |
| **1-Year, All Upfront** | $0.296 | $216 | 41% |
| **3-Year, All Upfront** | $0.194 | $142 | 61% |

**Best for:**
- Production deployment (not POC)
- Predictable 24/7 usage
- Budget certainty

**How to purchase:**
```bash
# AWS CLI
aws ec2 describe-reserved-instances-offerings \
  --instance-type r5.2xlarge \
  --product-description "Linux/UNIX" \
  --query "ReservedInstancesOfferings[0:5].[ReservedInstancesOfferingId,InstanceType,OfferingClass,Duration,FixedPrice]"

# Purchase
aws ec2 purchase-reserved-instances-offering \
  --reserved-instances-offering-id <offering-id> \
  --instance-count 1
```

### Use Spot Instances

**Savings:** Up to 90% off on-demand price

**Average r5.2xlarge spot prices (us-east-1):**
- Typical: $0.15-0.25/hour (50-70% savings)
- Low demand: $0.10/hour (80% savings)
- High demand: $0.45/hour (10% savings)

**⚠️ Risk:** Instance can be terminated with 2-minute notice

**Best for:**
- Development/testing
- Non-critical workloads
- Batch processing
- **NOT recommended for production or POC demo**

**How to use:**
```bash
# Launch spot instance (AWS CLI)
aws ec2 request-spot-instances \
  --spot-price "0.25" \
  --instance-count 1 \
  --type "persistent" \
  --launch-specification file://spot-config.json
```

### Rightsize Instance

**Choose appropriate instance type for your workload.**

| Workload Type | Recommended Instance | Monthly Cost |
|---------------|---------------------|--------------|
| **Initial setup/build** | r5.2xlarge (8 vCPU, 64GB) | $368 |
| **Small POC (<50 studies)** | r5.xlarge (4 vCPU, 32GB) | $184 |
| **Medium POC (50-200 studies)** | r5.2xlarge (8 vCPU, 64GB) | $368 |
| **Large POC (200+ studies)** | r5.4xlarge (16 vCPU, 128GB) | $736 |

**Recommendation:**
- **Build phase:** r5.2xlarge (sufficient resources)
- **Demo phase:** Can downsize to r5.xlarge if workload light
- **Production:** r5.4xlarge or cluster of r5.2xlarge

**How to resize:**
```bash
# Stop instance
aws ec2 stop-instances --instance-ids i-xxxxxxxxx

# Wait for stopped state
aws ec2 wait instance-stopped --instance-ids i-xxxxxxxxx

# Change instance type
aws ec2 modify-instance-attribute \
  --instance-id i-xxxxxxxxx \
  --instance-type "{\"Value\": \"r5.xlarge\"}"

# Start instance
aws ec2 start-instances --instance-ids i-xxxxxxxxx
```

### Optimize Storage

**Storage type comparison:**

| Type | IOPS | Throughput | Cost/GB/Month | Best For |
|------|------|------------|---------------|----------|
| **gp3** | 3,000-16,000 | 125-1000 MB/s | $0.08 | Most workloads |
| **gp2** | 100-16,000 | 128-250 MB/s | $0.10 | Legacy |
| **io2** | Up to 64,000 | Up to 1,000 MB/s | $0.125 + IOPS cost | High performance DB |

**Optimization tips:**

1. **Use gp3 instead of gp2:**
   - Same performance at 20% lower cost
   - Migrate existing gp2 → gp3 via console

2. **Right-size volume:**
   ```bash
   # Check actual usage
   df -h /
   
   # If using <60%, consider shrinking (requires backup/restore)
   ```

3. **Delete old snapshots:**
   ```bash
   # List snapshots
   aws ec2 describe-snapshots --owner-ids self
   
   # Delete old snapshot
   aws ec2 delete-snapshot --snapshot-id snap-xxxxxxxxx
   ```

4. **Enable EBS volume cleanup:**
   ```bash
   # Delete unattached volumes
   aws ec2 describe-volumes \
     --filters Name=status,Values=available \
     --query "Volumes[*].VolumeId" \
     --output text | xargs -n 1 aws ec2 delete-volume --volume-id
   ```

### Manage Elastic IP

**Costs:**
- **Associated with running instance:** $0
- **Not associated:** $0.005/hour = $3.65/month

**Optimization:**
```bash
# Release Elastic IP when not needed
aws ec2 release-address --allocation-id eipalloc-xxxxxxxxx

# Reallocate when needed
aws ec2 allocate-address --domain vpc
```

**Alternative:** Use AWS Session Manager instead of SSH
- No Elastic IP needed
- Connect via AWS Console or CLI
- No SSH key management

### Clean Up Unused Resources

```bash
# List all resources in region
aws resourcegroupstaggingapi get-resources \
  --region us-east-1 \
  --query 'ResourceTagMappingList[].ResourceARN'

# Delete unused security groups
aws ec2 describe-security-groups \
  --query "SecurityGroups[?IpPermissions==\`[]\`].GroupId" \
  --output text | xargs -n 1 aws ec2 delete-security-group --group-id

# Detach and delete unused volumes
aws ec2 describe-volumes \
  --filters Name=status,Values=available \
  --query "Volumes[*].VolumeId" \
  --output text | xargs -n 1 aws ec2 delete-volume --volume-id
```

---

## Budgets and Alerts

### Set Up AWS Budget

**Via AWS Console:**
1. Navigate to **AWS Billing → Budgets**
2. Click **Create budget**
3. Select **Cost budget**
4. Set budget amount: $400 (for 1-month POC)
5. Configure alerts:
   - Alert at 50% ($200)
   - Alert at 80% ($320)
   - Alert at 100% ($400)
6. Enter email for notifications
7. Create budget

**Via AWS CLI:**
```bash
cat > budget-config.json << 'EOF'
{
  "BudgetName": "KaapanaPOCBudget",
  "BudgetLimit": {
    "Amount": "400",
    "Unit": "USD"
  },
  "TimeUnit": "MONTHLY",
  "BudgetType": "COST"
}
EOF

aws budgets create-budget \
  --account-id $(aws sts get-caller-identity --query Account --output text) \
  --budget file://budget-config.json \
  --notifications-with-subscribers \
    file://budget-notifications.json
```

### Cost Explorer

**Track costs daily:**
```bash
# Get cost for last 30 days
aws ce get-cost-and-usage \
  --time-period Start=2024-01-01,End=2024-01-31 \
  --granularity DAILY \
  --metrics "UnblendedCost" \
  --group-by Type=DIMENSION,Key=SERVICE
```

**Example output:**
```json
{
  "EC2": "$180.50",
  "EBS": "$20.00",
  "DataTransfer": "$5.20",
  "Total": "$205.70"
}
```

---

## Production Cost Estimates

### Small Deployment (Single Server)

| Component | Specification | Monthly Cost |
|-----------|---------------|--------------|
| EC2 Reserved (1-year) | r5.4xlarge | $435 |
| EBS Storage | 500GB gp3 | $40 |
| Backups | 500GB snapshots | $25 |
| Load Balancer | ALB | $23 |
| Data Transfer | 500GB/month | $40 |
| CloudWatch Logs | 50GB | $25 |
| **TOTAL** | | **~$588/month** |

### Medium Deployment (3-Node Cluster)

| Component | Specification | Monthly Cost |
|-----------|---------------|--------------|
| EC2 Reserved (1-year) | 3× r5.4xlarge | $1,305 |
| EBS Storage | 1.5TB gp3 | $120 |
| Backups | 1TB snapshots | $50 |
| Load Balancer | ALB | $23 |
| Data Transfer | 2TB/month | $170 |
| CloudWatch Logs | 200GB | $100 |
| RDS (PostgreSQL) | db.r5.xlarge | $292 |
| **TOTAL** | | **~$2,060/month** |

### Large Deployment (Multi-AZ, HA)

| Component | Specification | Monthly Cost |
|-----------|---------------|--------------|
| EC2 Reserved (1-year) | 6× r5.4xlarge (Multi-AZ) | $2,610 |
| EBS Storage | 3TB gp3 | $240 |
| Backups | 2TB snapshots | $100 |
| Load Balancer | ALB + NLB | $46 |
| Data Transfer | 5TB/month | $425 |
| CloudWatch Logs | 500GB | $250 |
| RDS Multi-AZ | db.r5.2xlarge | $730 |
| S3 Storage | 10TB | $230 |
| **TOTAL** | | **~$4,631/month** |

---

## Cost Tracking Script

```bash
cat > ~/check-aws-costs.sh << 'EOF'
#!/bin/bash

echo "=== AWS Cost Report ==="
echo ""

# Get account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "Account: $ACCOUNT_ID"
echo ""

# Current month costs
START_DATE=$(date +%Y-%m-01)
END_DATE=$(date +%Y-%m-%d)

echo "Costs from $START_DATE to $END_DATE:"
echo ""

# Get total cost
aws ce get-cost-and-usage \
  --time-period Start=$START_DATE,End=$END_DATE \
  --granularity MONTHLY \
  --metrics "UnblendedCost" \
  --query 'ResultsByTime[0].Total.UnblendedCost.Amount' \
  --output text | xargs printf "Total: $%.2f\n"

echo ""
echo "Cost by Service:"

# Get cost by service
aws ce get-cost-and-usage \
  --time-period Start=$START_DATE,End=$END_DATE \
  --granularity MONTHLY \
  --metrics "UnblendedCost" \
  --group-by Type=DIMENSION,Key=SERVICE \
  --query 'ResultsByTime[0].Groups[*].[Keys[0],Metrics.UnblendedCost.Amount]' \
  --output text | \
  awk '{printf "  %-20s $%.2f\n", $1, $2}' | \
  sort -k2 -rn | head -10

echo ""
EOF

chmod +x ~/check-aws-costs.sh
~/check-aws-costs.sh
```

---

## Cleanup After POC

### Complete Cleanup Checklist

**When POC is no longer needed:**

```bash
# 1. Delete Kaapana deployment
helm uninstall kaapana-platform -n kaapana
helm uninstall kaapana-admin -n admin
kubectl delete namespace kaapana admin

# 2. Stop instance (if keeping for reference)
aws ec2 stop-instances --instance-ids i-xxxxxxxxx

# OR terminate instance (if done completely)
aws ec2 terminate-instances --instance-ids i-xxxxxxxxx

# 3. Delete EBS volumes (after instance terminated)
aws ec2 describe-volumes \
  --filters Name=status,Values=available \
  --query "Volumes[*].VolumeId" \
  --output text | xargs -n 1 aws ec2 delete-volume --volume-id

# 4. Release Elastic IP
aws ec2 release-address --allocation-id eipalloc-xxxxxxxxx

# 5. Delete snapshots
aws ec2 describe-snapshots --owner-ids self \
  --query "Snapshots[*].SnapshotId" \
  --output text | xargs -n 1 aws ec2 delete-snapshot --snapshot-id

# 6. Delete security group
aws ec2 delete-security-group --group-id sg-xxxxxxxxx

# 7. Delete key pair
aws ec2 delete-key-pair --key-name kaapana-poc-key
rm kaapana-poc-key.pem
```

**Estimated savings after cleanup:** $388/month (r5.2xlarge + storage)

---

## Best Practices Summary

1. **Use Tags:** Tag all resources with Project=Kaapana, Environment=POC
2. **Set Budgets:** Create budget alerts at 50%, 80%, 100%
3. **Stop When Idle:** Stop instance outside business hours
4. **Monitor Daily:** Check costs daily via Cost Explorer
5. **Right-size:** Start with appropriate instance type
6. **Clean Regularly:** Delete unused snapshots, volumes
7. **Use gp3:** Convert gp2 volumes to gp3
8. **Plan for Production:** Use Reserved Instances for production

---

## Cost Comparison: Cloud Providers

| Provider | Instance Type | vCPU | RAM | Storage | Monthly Cost |
|----------|--------------|------|-----|---------|--------------|
| **AWS** | r5.2xlarge | 8 | 64GB | 250GB gp3 | $388 |
| **Azure** | E8s_v5 | 8 | 64GB | 250GB Premium SSD | $420 |
| **GCP** | n2-highmem-8 | 8 | 64GB | 250GB SSD | $395 |

**Recommendation:** AWS offers best balance of performance and cost for Kaapana.

---

**Document Status:** ✅ Complete  
**Key Takeaway:** Stop instance when not in use to save 95% on compute costs!
