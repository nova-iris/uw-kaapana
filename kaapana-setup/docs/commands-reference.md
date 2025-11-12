# Quick Commands Reference

**Fast lookup for common Kaapana POC operations**

---

## SSH & Instance Access

```bash
# SSH to AWS instance
ssh -i kaapana-poc-key.pem ubuntu@YOUR_ELASTIC_IP

# SCP file to instance
scp -i kaapana-poc-key.pem localfile.txt ubuntu@YOUR_ELASTIC_IP:~/

# SCP file from instance
scp -i kaapana-poc-key.pem ubuntu@YOUR_ELASTIC_IP:~/remotefile.txt ./

# Start instance
aws ec2 start-instances --instance-ids i-xxxxxxxxx

# Stop instance
aws ec2 stop-instances --instance-ids i-xxxxxxxxx

# Get instance public IP
aws ec2 describe-instances --instance-ids i-xxxxxxxxx \
  --query 'Reservations[0].Instances[0].PublicIpAddress' \
  --output text
```

---

## MicroK8s Management

```bash
# Check MicroK8s status
microk8s status

# Start MicroK8s
sudo snap start microk8s

# Stop MicroK8s
sudo snap stop microk8s

# Restart MicroK8s
sudo snap restart microk8s

# Enable addons
microk8s enable dns storage ingress registry

# Disable addon
microk8s disable <addon-name>

# Reset MicroK8s (⚠️ destroys all data)
microk8s reset

# View MicroK8s config
microk8s config

# Inspect MicroK8s (diagnostic info)
microk8s inspect
```

---

## Kubernetes (kubectl)

### Cluster Info
```bash
# Get cluster info
kubectl cluster-info

# Get nodes
kubectl get nodes

# Node details
kubectl describe node <node-name>

# Check node resources
kubectl top nodes
```

### Pods
```bash
# List pods in namespace
kubectl get pods -n kaapana

# List all pods in all namespaces
kubectl get pods -A

# Wide output (shows node, IP)
kubectl get pods -n kaapana -o wide

# Watch pods (auto-refresh)
watch -n 5 "kubectl get pods -n kaapana"

# Pod details
kubectl describe pod <pod-name> -n kaapana

# Pod logs
kubectl logs <pod-name> -n kaapana

# Follow logs (tail -f)
kubectl logs <pod-name> -n kaapana -f

# Previous pod logs (after crash)
kubectl logs <pod-name> -n kaapana --previous

# Logs from specific container in pod
kubectl logs <pod-name> -n kaapana -c <container-name>

# Execute command in pod
kubectl exec <pod-name> -n kaapana -- <command>

# Interactive shell in pod
kubectl exec -it <pod-name> -n kaapana -- bash

# Delete pod
kubectl delete pod <pod-name> -n kaapana

# Force delete pod
kubectl delete pod <pod-name> -n kaapana --force --grace-period=0

# Check pod resource usage
kubectl top pods -n kaapana

# Sort pods by memory
kubectl top pods -n kaapana --sort-by=memory

# Sort pods by CPU
kubectl top pods -n kaapana --sort-by=cpu
```

### Deployments
```bash
# List deployments
kubectl get deployments -n kaapana

# Deployment details
kubectl describe deployment <deployment-name> -n kaapana

# Scale deployment
kubectl scale deployment <deployment-name> -n kaapana --replicas=3

# Restart deployment (rolling restart)
kubectl rollout restart deployment <deployment-name> -n kaapana

# Rollout status
kubectl rollout status deployment <deployment-name> -n kaapana

# Rollout history
kubectl rollout history deployment <deployment-name> -n kaapana

# Rollback to previous version
kubectl rollout undo deployment <deployment-name> -n kaapana

# Update image
kubectl set image deployment/<deployment-name> \
  <container-name>=<new-image> -n kaapana
```

### Services
```bash
# List services
kubectl get svc -n kaapana

# Service details
kubectl describe svc <service-name> -n kaapana

# Port forward to service
kubectl port-forward svc/<service-name> <local-port>:<service-port> -n kaapana

# Example: Forward MinIO
kubectl port-forward svc/minio 9000:9000 -n kaapana &
```

### Namespaces
```bash
# List namespaces
kubectl get namespaces

# Create namespace
kubectl create namespace <namespace-name>

# Delete namespace (⚠️ deletes all resources in it)
kubectl delete namespace <namespace-name>

# Set default namespace (for current context)
kubectl config set-context --current --namespace=kaapana
```

### ConfigMaps & Secrets
```bash
# List ConfigMaps
kubectl get configmaps -n kaapana

# View ConfigMap
kubectl get configmap <configmap-name> -n kaapana -o yaml

# List Secrets
kubectl get secrets -n kaapana

# View Secret (base64 encoded)
kubectl get secret <secret-name> -n kaapana -o yaml

# Decode Secret value
kubectl get secret <secret-name> -n kaapana \
  -o jsonpath='{.data.<key>}' | base64 -d
```

### Persistent Volumes
```bash
# List PVs
kubectl get pv

# List PVCs
kubectl get pvc -n kaapana

# PVC details
kubectl describe pvc <pvc-name> -n kaapana
```

### Ingress
```bash
# List ingress
kubectl get ingress -n kaapana

# Ingress details
kubectl describe ingress <ingress-name> -n kaapana

# List ingress with address
kubectl get ingress -n kaapana -o wide
```

### Events
```bash
# Get events in namespace
kubectl get events -n kaapana

# Sort events by time
kubectl get events -n kaapana --sort-by='.lastTimestamp'

# Watch events
kubectl get events -n kaapana --watch
```

### Diagnostics
```bash
# Get all resources in namespace
kubectl get all -n kaapana

# Get specific resource types
kubectl get pods,svc,deployments -n kaapana

# Check cluster components
kubectl get componentstatuses

# Get API resources
kubectl api-resources
```

---

## Helm

```bash
# List releases in namespace
helm list -n kaapana

# List all releases in all namespaces
helm list -A

# Get release info
helm status <release-name> -n kaapana

# Get release values
helm get values <release-name> -n kaapana

# Get release manifest
helm get manifest <release-name> -n kaapana

# Install chart
helm install <release-name> <chart-path> -n kaapana

# Upgrade release
helm upgrade <release-name> <chart-path> -n kaapana

# Install or upgrade (idempotent)
helm upgrade --install <release-name> <chart-path> -n kaapana

# Uninstall release
helm uninstall <release-name> -n kaapana

# Rollback to previous version
helm rollback <release-name> -n kaapana

# Rollback to specific revision
helm rollback <release-name> <revision> -n kaapana

# Get release history
helm history <release-name> -n kaapana

# Test release
helm test <release-name> -n kaapana
```

---

## Docker

```bash
# List images
docker images

# List containers
docker ps
docker ps -a  # Include stopped

# Pull image
docker pull <image:tag>

# Build image
docker build -t <name:tag> <directory>

# Run container
docker run -it <image:tag> bash

# Stop container
docker stop <container-id>

# Remove container
docker rm <container-id>

# Remove image
docker rmi <image:tag>

# View logs
docker logs <container-id>

# Follow logs
docker logs -f <container-id>

# Execute in running container
docker exec -it <container-id> bash

# Inspect container
docker inspect <container-id>

# Container stats
docker stats

# System info
docker info

# Disk usage
docker system df

# Clean up
docker system prune -af       # Remove all unused
docker image prune -a          # Remove unused images
docker volume prune -f         # Remove unused volumes
docker container prune -f      # Remove stopped containers

# Save image to tar
docker save <image:tag> -o image.tar

# Load image from tar
docker load -i image.tar

# Tag image
docker tag <source-image:tag> <target-image:tag>

# Push to registry
docker push <image:tag>
```

---

## Kaapana Services

### Airflow

```bash
# Access Airflow UI
http://YOUR_IP/flow/
# Username: kaapana, Password: kaapana

# Airflow CLI commands (in pod)
kubectl exec deployment/airflow-scheduler -n kaapana -- airflow <command>

# List DAGs
kubectl exec deployment/airflow-scheduler -n kaapana -- airflow dags list

# Trigger DAG
kubectl exec deployment/airflow-scheduler -n kaapana -- \
  airflow dags trigger <dag-id>

# Pause DAG
kubectl exec deployment/airflow-scheduler -n kaapana -- \
  airflow dags pause <dag-id>

# Unpause DAG
kubectl exec deployment/airflow-scheduler -n kaapana -- \
  airflow dags unpause <dag-id>

# List DAG runs
kubectl exec deployment/airflow-scheduler -n kaapana -- \
  airflow dags list-runs -d <dag-id>

# Get task logs
kubectl exec deployment/airflow-scheduler -n kaapana -- \
  airflow tasks logs <dag-id> <task-id> <execution-date>
```

### dcm4chee (PACS)

```bash
# Access dcm4chee UI
http://YOUR_IP/dcm4chee-arc/ui2/
# Username: admin, Password: admin

# Port forward DICOM port
kubectl port-forward svc/dcm4chee-arc 11112:11112 -n kaapana &

# Send DICOM files
dcmsend localhost 11112 -aec DCM4CHEE *.dcm

# Query studies (from pod)
kubectl exec deployment/dcm4chee -n kaapana -- \
  dcmqrscp -c DCM4CHEE@localhost:11112 -L PATIENT -k PatientName="*"
```

### OpenSearch

```bash
# Access OpenSearch Dashboards
http://YOUR_IP/opensearch-dashboards/
# Username: admin, Password: admin

# Query index
curl -u admin:admin http://localhost:9200/dicom-*/_search?pretty

# Count documents
curl -u admin:admin http://localhost:9200/dicom-*/_count?pretty

# List indices
curl -u admin:admin http://localhost:9200/_cat/indices?v

# Cluster health
curl -u admin:admin http://localhost:9200/_cluster/health?pretty

# Cluster stats
curl -u admin:admin http://localhost:9200/_cluster/stats?pretty

# Delete index (⚠️ dangerous)
curl -X DELETE -u admin:admin http://localhost:9200/<index-name>
```

### MinIO

```bash
# Access MinIO Console
http://YOUR_IP/minio-console/
# Username: minio, Password: minio123

# MinIO Client (mc) commands

# Configure alias
mc alias set kaapana-minio http://localhost:9000 <accesskey> <secretkey>

# List buckets
mc ls kaapana-minio/

# List bucket contents
mc ls kaapana-minio/<bucket-name>/

# Copy file to MinIO
mc cp localfile.txt kaapana-minio/<bucket-name>/

# Copy from MinIO
mc cp kaapana-minio/<bucket-name>/file.txt ./

# Mirror (sync) directories
mc mirror kaapana-minio/<bucket-name>/ ~/local-dir/

# Remove file
mc rm kaapana-minio/<bucket-name>/file.txt

# Get bucket info
mc du kaapana-minio/<bucket-name>/
```

### OHIF Viewer

```bash
# Access OHIF
http://YOUR_IP/ohif/

# Check OHIF config
kubectl get configmap ohif-config -n kaapana -o yaml
```

---

## DICOM Tools

```bash
# Install DCMTK
sudo apt install -y dcmtk

# Send DICOM files (dcmsend)
dcmsend <host> <port> -aec <AE-title> <file.dcm>

# Example:
dcmsend localhost 11112 -aec DCM4CHEE *.dcm

# Query PACS (findscu)
findscu -S -k PatientName="*" -k StudyDate="20240101-" \
  <host> <port> -aec <AE-title>

# Retrieve from PACS (movescu)
movescu -S -k PatientName="<name>" <host> <port> -aec <AE-title>

# Dump DICOM file info
dcmdump <file.dcm>

# Convert DICOM to image
dcmj2pnm <file.dcm> output.png

# Anonymize DICOM
dcmodify -i "PatientName=ANON" <file.dcm>

# Validate DICOM
dciodvfy <file.dcm>
```

---

## System Monitoring

```bash
# System resources
htop              # Interactive process viewer
top               # Process viewer
free -h           # Memory usage
df -h             # Disk usage
du -sh /*         # Directory sizes
iostat            # I/O stats
vmstat            # Virtual memory stats

# Network
ifconfig          # Network interfaces
ip a              # IP addresses
netstat -tulpn    # Listening ports
ss -tulpn         # Socket stats
ping <host>       # Test connectivity
traceroute <host> # Trace route
curl <url>        # HTTP request
wget <url>        # Download file

# Logs
journalctl -xe    # System logs
tail -f /var/log/syslog  # Follow syslog
dmesg             # Kernel messages

# Process management
ps aux            # All processes
kill <pid>        # Kill process
killall <name>    # Kill by name
pkill <pattern>   # Kill by pattern
```

---

## Backup & Restore

### Backup Kaapana Data

```bash
# Backup MinIO data
mc mirror kaapana-minio/kaapana-data ~/backup/minio-data/

# Backup dcm4chee database
kubectl exec deployment/postgres -n kaapana -- \
  pg_dump -U pacsdb pacsdb > ~/backup/dcm4chee-$(date +%Y%m%d).sql

# Backup Helm releases
helm get values kaapana-platform -n kaapana > ~/backup/kaapana-platform-values.yaml
helm get values kaapana-admin -n admin > ~/backup/kaapana-admin-values.yaml

# Backup Kubernetes resources
kubectl get all -n kaapana -o yaml > ~/backup/kaapana-resources.yaml

# Backup persistent volumes
kubectl get pv,pvc -A -o yaml > ~/backup/persistent-volumes.yaml
```

### Restore Kaapana Data

```bash
# Restore MinIO data
mc mirror ~/backup/minio-data/ kaapana-minio/kaapana-data/

# Restore dcm4chee database
kubectl exec -i deployment/postgres -n kaapana -- \
  psql -U pacsdb pacsdb < ~/backup/dcm4chee-20240101.sql

# Restore from Helm backup
helm upgrade kaapana-platform ./kaapana-platform-chart \
  -n kaapana \
  -f ~/backup/kaapana-platform-values.yaml
```

---

## AWS CLI

```bash
# Configure AWS CLI
aws configure

# Get account info
aws sts get-caller-identity

# List instances
aws ec2 describe-instances --query 'Reservations[*].Instances[*].[InstanceId,State.Name,PublicIpAddress]' --output table

# Instance details
aws ec2 describe-instances --instance-ids i-xxxxxxxxx

# Start instance
aws ec2 start-instances --instance-ids i-xxxxxxxxx

# Stop instance
aws ec2 stop-instances --instance-ids i-xxxxxxxxx

# Reboot instance
aws ec2 reboot-instances --instance-ids i-xxxxxxxxx

# Terminate instance
aws ec2 terminate-instances --instance-ids i-xxxxxxxxx

# List volumes
aws ec2 describe-volumes

# List snapshots
aws ec2 describe-snapshots --owner-ids self

# List security groups
aws ec2 describe-security-groups

# Get current costs
aws ce get-cost-and-usage \
  --time-period Start=2024-01-01,End=2024-01-31 \
  --granularity MONTHLY \
  --metrics "UnblendedCost"
```

---

## Verification Scripts

### Quick Health Check

```bash
# Save as ~/health-check.sh
cat > ~/health-check.sh << 'EOF'
#!/bin/bash
echo "=== Kaapana Health Check ==="
microk8s status | head -5
kubectl get nodes
kubectl get pods -n kaapana | grep -v "1/1.*Running" || echo "All pods running"
curl -s -o /dev/null -w "Kaapana UI: %{http_code}\n" http://localhost/
curl -s -o /dev/null -w "Airflow: %{http_code}\n" http://localhost/flow/
df -h / | tail -1
echo "=== Health Check Complete ==="
EOF

chmod +x ~/health-check.sh
~/health-check.sh
```

---

## Useful Aliases

```bash
# Add to ~/.bashrc
cat >> ~/.bashrc << 'EOF'
# Kaapana aliases
alias k='kubectl'
alias kgp='kubectl get pods -n kaapana'
alias kgs='kubectl get svc -n kaapana'
alias kgi='kubectl get ingress -n kaapana'
alias kl='kubectl logs -n kaapana'
alias kd='kubectl describe -n kaapana'
alias ke='kubectl exec -it -n kaapana'
alias mkstatus='microk8s status'
alias mkstop='sudo snap stop microk8s'
alias mkstart='sudo snap start microk8s'
alias mkrestart='sudo snap restart microk8s'
alias kaapana='cd ~/kaapana-build/kaapana'
alias activate='source ~/kaapana-build/kaapana-venv/bin/activate'
EOF

source ~/.bashrc
```

---

## Emergency Commands

### Complete System Reset

**⚠️ WARNING: Destroys all data**

```bash
# 1. Delete Kaapana
helm uninstall kaapana-platform -n kaapana
helm uninstall kaapana-admin -n admin
kubectl delete namespace kaapana admin --force --grace-period=0

# 2. Reset MicroK8s
microk8s reset

# 3. Clean Docker
docker system prune -af --volumes

# 4. Reboot server
sudo reboot
```

### Force Delete Stuck Resources

```bash
# Force delete namespace
kubectl delete namespace <namespace> --force --grace-period=0

# Remove finalizers from stuck resource
kubectl patch <resource-type> <resource-name> -n <namespace> \
  -p '{"metadata":{"finalizers":[]}}' --type=merge

# Example: Force delete stuck pod
kubectl delete pod <pod-name> -n kaapana --force --grace-period=0
```

---

## Access URLs Summary

| Service | URL | Credentials |
|---------|-----|-------------|
| **Kaapana UI** | http://YOUR_IP/ | kaapana / kaapana |
| **Airflow** | http://YOUR_IP/flow/ | kaapana / kaapana |
| **OHIF Viewer** | http://YOUR_IP/ohif/ | (SSO via Keycloak) |
| **dcm4chee** | http://YOUR_IP/dcm4chee-arc/ui2/ | admin / admin |
| **OpenSearch** | http://YOUR_IP/opensearch-dashboards/ | admin / admin |
| **MinIO** | http://YOUR_IP/minio-console/ | minio / minio123 |
| **Keycloak** | http://YOUR_IP/auth/admin/ | admin / (in secret) |

---

**Document Status:** ✅ Complete  
**Tip:** Bookmark this page for quick command lookup!
