# Troubleshooting Guide

**Quick Reference for Common Kaapana POC Issues**

---

## General Troubleshooting Approach

1. **Identify the problem component** (Kubernetes, Pod, Service, Network, Storage)
2. **Gather logs and status** information
3. **Check resource constraints** (CPU, memory, disk)
4. **Review recent changes** that might have caused the issue
5. **Search error messages** in Kaapana GitHub issues
6. **Apply fix** and verify resolution

---

## Quick Diagnostic Commands

```bash
# Overall cluster health
kubectl get nodes
kubectl get pods -A | grep -v Running
kubectl top nodes

# Kaapana specific
kubectl get pods -n kaapana
kubectl get svc -n kaapana
kubectl get ingress -n kaapana

# Logs for a pod
kubectl logs <pod-name> -n kaapana --tail=100
kubectl logs <pod-name> -n kaapana -f  # Follow logs

# Describe pod for events
kubectl describe pod <pod-name> -n kaapana

# MicroK8s status
microk8s status
microk8s inspect
```

---

## Infrastructure Issues

### EC2 Instance Not Accessible

**Symptoms:**
- Cannot SSH to instance
- Connection timeout

**Diagnosis:**
```bash
# From local machine
ping YOUR_ELASTIC_IP
telnet YOUR_ELASTIC_IP 22

# Check AWS Console:
# - Instance state (should be "running")
# - Security group inbound rules
# - Elastic IP association
```

**Solutions:**

**Security group misconfigured:**
```bash
# AWS CLI to fix security group
aws ec2 authorize-security-group-ingress \
  --group-id sg-xxxxxxxx \
  --protocol tcp \
  --port 22 \
  --cidr YOUR_IP/32
```

**Instance stopped:**
```bash
# Start instance
aws ec2 start-instances --instance-ids i-xxxxxxxx
```

**Wrong SSH key:**
```bash
# Verify key matches instance
ssh -i correct-key.pem ubuntu@$ELASTIC_IP
```

### Out of Disk Space

**Symptoms:**
- Pods failing with "no space left on device"
- Build fails
- Cannot pull images

**Diagnosis:**
```bash
df -h /
du -sh /* | sort -h
docker system df
```

**Solutions:**

**Clean Docker cache:**
```bash
docker system prune -af
docker volume prune -f
```

**Clean old logs:**
```bash
sudo find /var/log -type f -name "*.log" -mtime +7 -delete
sudo journalctl --vacuum-time=7d
```

**Expand EBS volume:**
```bash
# 1. AWS Console → EC2 → Volumes → Modify Volume
# 2. Increase size to 300GB or 500GB
# 3. On server:
sudo growpart /dev/nvme0n1 1
sudo resize2fs /dev/nvme0n1p1
df -h  # Verify
```

**Clean Kubernetes:**
```bash
kubectl delete pods --field-selector status.phase=Failed -A
kubectl delete pods --field-selector status.phase=Succeeded -A
```

### Out of Memory

**Symptoms:**
- Pods OOMKilled
- System slow/unresponsive
- Kernel messages about OOM

**Diagnosis:**
```bash
free -h
kubectl top nodes
kubectl top pods -n kaapana
dmesg | grep -i "out of memory"
```

**Solutions:**

**Identify memory hogs:**
```bash
kubectl top pods -n kaapana --sort-by=memory
```

**Reduce pod resource limits:**
```bash
kubectl patch deployment <deployment-name> -n kaapana \
  -p '{"spec":{"template":{"spec":{"containers":[{"name":"<container-name>","resources":{"limits":{"memory":"2Gi"}}}]}}}}'
```

**Restart high-memory pod:**
```bash
kubectl delete pod <pod-name> -n kaapana
```

**Add swap (temporary):**
```bash
sudo fallocate -l 8G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
```

---

## Kubernetes Issues

### MicroK8s Not Starting

**Symptoms:**
- `microk8s status` shows error
- Pods not deploying

**Diagnosis:**
```bash
microk8s status
microk8s inspect
sudo journalctl -u snap.microk8s.daemon-kubelite -n 100
```

**Solutions:**

**Restart MicroK8s:**
```bash
sudo snap restart microk8s
microk8s status --wait-ready
```

**Full MicroK8s reset:**
```bash
microk8s stop
sudo rm -rf /var/snap/microk8s/current/*
microk8s start
microk8s status --wait-ready

# Re-enable addons
microk8s enable dns storage ingress registry
```

**Reinstall MicroK8s:**
```bash
sudo snap remove microk8s --purge
sudo snap install microk8s --classic
sudo usermod -aG microk8s $USER
newgrp microk8s
```

### Pod Stuck in Pending

**Symptoms:**
- Pod shows STATUS: Pending
- Pod never starts

**Diagnosis:**
```bash
kubectl describe pod <pod-name> -n kaapana

# Look for:
# - Insufficient CPU/memory
# - Unschedulable
# - Volume mount issues
```

**Solutions:**

**Insufficient resources:**
```bash
# Check node resources
kubectl top nodes

# Scale down other deployments
kubectl scale deployment <deployment-name> -n kaapana --replicas=0
```

**PVC not bound:**
```bash
kubectl get pvc -n kaapana

# If PVC pending, check storage class
kubectl get storageclass

# Delete and recreate PVC
kubectl delete pvc <pvc-name> -n kaapana
kubectl apply -f <pvc-manifest>
```

### Pod in CrashLoopBackOff

**Symptoms:**
- Pod STATUS: CrashLoopBackOff
- Pod continuously restarting

**Diagnosis:**
```bash
kubectl logs <pod-name> -n kaapana --previous
kubectl describe pod <pod-name> -n kaapana
```

**Solutions:**

**Application error:**
```bash
# Fix depends on error in logs
# Common issues:
# - Missing environment variables
# - Wrong configuration
# - Failed dependency check
```

**Image pull error:**
```bash
# Check image exists
microk8s ctr images list | grep <image-name>

# Re-import images if missing
docker save <image> | microk8s ctr image import -
```

**Liveness probe failing:**
```bash
# Temporarily disable probe
kubectl patch deployment <deployment-name> -n kaapana \
  -p '{"spec":{"template":{"spec":{"containers":[{"name":"<container>","livenessProbe":null}]}}}}'
```

### Ingress Not Working

**Symptoms:**
- Cannot access services via browser
- 404 or 502 errors

**Diagnosis:**
```bash
kubectl get ingress -n kaapana
kubectl describe ingress <ingress-name> -n kaapana
kubectl get svc -n ingress
kubectl logs -n ingress -l app.kubernetes.io/name=ingress-nginx
```

**Solutions:**

**Ingress controller not running:**
```bash
microk8s disable ingress
microk8s enable ingress

# Wait for ingress controller
kubectl wait --for=condition=ready pod \
  -l app.kubernetes.io/name=ingress-nginx \
  -n ingress \
  --timeout=300s
```

**Service not accessible:**
```bash
# Test service directly
kubectl port-forward svc/<service-name> 8080:80 -n kaapana &
curl http://localhost:8080
kill %1
```

**Firewall blocking:**
```bash
# Check if UFW active
sudo ufw status

# Allow ports
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw reload
```

---

## Component-Specific Issues

### dcm4chee Not Starting

**Symptoms:**
- dcm4chee pod not ready
- DICOM upload fails

**Diagnosis:**
```bash
kubectl logs -l app=dcm4chee -n kaapana --tail=100
kubectl describe pod -l app=dcm4chee -n kaapana
```

**Solutions:**

**Database connection issue:**
```bash
# Check postgres pod
kubectl get pods -n kaapana | grep postgres
kubectl logs -l app=postgres -n kaapana

# Restart postgres
kubectl delete pod -l app=postgres -n kaapana
```

**Out of memory:**
```bash
# Increase dcm4chee memory
kubectl patch deployment dcm4chee -n kaapana \
  -p '{"spec":{"template":{"spec":{"containers":[{"name":"dcm4chee","resources":{"limits":{"memory":"4Gi"}}}]}}}}'
```

**Port conflict:**
```bash
# Check if port 11112 in use
sudo netstat -tulpn | grep 11112

# Kill conflicting process if found
sudo kill <pid>
```

### Airflow Not Accessible

**Symptoms:**
- Airflow UI returns 502 or 404
- DAGs not loading

**Diagnosis:**
```bash
kubectl get pods -n kaapana | grep airflow
kubectl logs -l app=airflow-web -n kaapana --tail=50
kubectl logs -l app=airflow-scheduler -n kaapana --tail=50
```

**Solutions:**

**Webserver not ready:**
```bash
# Restart airflow webserver
kubectl delete pod -l app=airflow-web -n kaapana
```

**Scheduler not healthy:**
```bash
# Restart airflow scheduler
kubectl delete pod -l app=airflow-scheduler -n kaapana
```

**Database migration needed:**
```bash
kubectl exec deployment/airflow-scheduler -n kaapana -- \
  airflow db upgrade
```

**DAGs not syncing:**
```bash
# Check DAG directory
kubectl exec deployment/airflow-scheduler -n kaapana -- \
  ls -la /opt/airflow/dags/

# Restart scheduler to reload DAGs
kubectl delete pod -l app=airflow-scheduler -n kaapana
```

### OpenSearch Not Starting

**Symptoms:**
- OpenSearch pod not ready
- "max virtual memory areas vm.max_map_count too low"

**Diagnosis:**
```bash
kubectl logs -l app=opensearch -n kaapana --tail=50
```

**Solutions:**

**vm.max_map_count too low:**
```bash
# Set on host
sudo sysctl -w vm.max_map_count=262144
echo "vm.max_map_count=262144" | sudo tee -a /etc/sysctl.conf

# Restart OpenSearch pod
kubectl delete pod -l app=opensearch -n kaapana
```

**Out of memory:**
```bash
# Check OpenSearch memory settings
kubectl get deployment opensearch -n kaapana -o yaml | grep -A 5 resources

# Reduce heap size if needed
kubectl set env deployment/opensearch -n kaapana \
  OPENSEARCH_JAVA_OPTS="-Xms1g -Xmx1g"
```

### OHIF Viewer Not Loading Images

**Symptoms:**
- Study list loads but images don't display
- Blank viewer or loading spinner

**Diagnosis:**
```bash
kubectl logs -l app=ohif -n kaapana
# Browser console (F12) → Network tab
```

**Solutions:**

**DICOMweb endpoint misconfigured:**
```bash
# Check OHIF config
kubectl get configmap ohif-config -n kaapana -o yaml

# Verify dcm4chee DICOMweb accessible
curl http://localhost:8080/dcm4chee-arc/aets/DCM4CHEE/rs/studies
```

**CORS issue:**
```bash
# Check dcm4chee CORS config
kubectl exec -it deployment/dcm4chee -n kaapana -- cat /opt/wildfly/standalone/configuration/standalone.xml | grep -i cors
```

**Studies not indexed:**
```bash
# Check OpenSearch for study metadata
curl -u admin:admin http://localhost:9200/dicom-*/_search?pretty
```

### MinIO Not Accessible

**Symptoms:**
- MinIO console returns error
- Upload to MinIO fails

**Diagnosis:**
```bash
kubectl logs -l app=minio -n kaapana --tail=50
kubectl get svc minio -n kaapana
```

**Solutions:**

**Credentials wrong:**
```bash
# Get MinIO credentials
kubectl get secret minio-secret -n kaapana \
  -o jsonpath='{.data.accesskey}' | base64 -d
echo ""
kubectl get secret minio-secret -n kaapana \
  -o jsonpath='{.data.secretkey}' | base64 -d
echo ""
```

**Storage issue:**
```bash
# Check PVC bound
kubectl get pvc -n kaapana | grep minio

# Check disk space on volume
kubectl exec deployment/minio -n kaapana -- df -h
```

---

## Build Issues

### Build Fails: Docker Permission Denied

**Symptoms:**
- Build script fails with "permission denied"
- Cannot connect to Docker daemon

**Solutions:**
```bash
sudo usermod -aG docker $USER
newgrp docker
docker run --rm hello-world
```

### Build Fails: Image Build Error

**Symptoms:**
- Specific image fails to build
- Syntax error or missing dependency

**Solutions:**
```bash
# Build single image manually for debugging
cd ~/kaapana-build/kaapana/services/<service-name>
docker build -t test-image:latest .

# Check error and fix Dockerfile if needed
```

### Build Hangs

**Symptoms:**
- Build process stops responding
- No progress for 15+ minutes

**Solutions:**
```bash
# Check system resources
htop
df -h

# Reduce parallel builds
python3 start_build.py --config build-config.yaml --build-only --parallel 2
```

---

## Network Issues

### Cannot Access Services from Browser

**Symptoms:**
- Connection timeout
- No route to host

**Diagnosis:**
```bash
# From AWS server
curl -I http://localhost/

# From local machine
curl -I http://YOUR_ELASTIC_IP/

# Check AWS security group inbound rules
```

**Solutions:**

**Security group:**
```bash
# Add rules for ports 80, 443
# AWS Console → EC2 → Security Groups → Edit inbound rules
# Add: HTTP (80) from 0.0.0.0/0
# Add: HTTPS (443) from 0.0.0.0/0
```

**Ingress not configured:**
```bash
kubectl get ingress -n kaapana
microk8s enable ingress
```

### DICOM Send Fails (Port 11112)

**Symptoms:**
- dcmsend cannot connect
- Connection refused on port 11112

**Diagnosis:**
```bash
sudo netstat -tulpn | grep 11112
kubectl get svc dcm4chee-arc -n kaapana
```

**Solutions:**

**Port forward for testing:**
```bash
kubectl port-forward svc/dcm4chee-arc 11112:11112 -n kaapana &
dcmsend localhost 11112 -aec DCM4CHEE *.dcm
kill %1
```

**Expose externally (POC only):**
```bash
# Add security group rule
# AWS Console → Security Groups → Add rule
# TCP 11112 from YOUR_IP/32
```

---

## Data Issues

### DICOM Upload Succeeds But Studies Don't Appear

**Symptoms:**
- Upload returns success
- Studies not in OHIF or dcm4chee UI

**Diagnosis:**
```bash
# Check dcm4chee logs
kubectl logs -l app=dcm4chee -n kaapana | grep -i "store\|error"

# Check database
kubectl exec deployment/postgres -n kaapana -- \
  psql -U pacsdb -c "SELECT COUNT(*) FROM study;"
```

**Solutions:**

**Indexing issue:**
```bash
# Trigger manual reindex
# (Depends on Kaapana version - check Airflow DAGs)
```

**OpenSearch not receiving updates:**
```bash
# Check indexing service
kubectl logs -l app=kaapana-indexing -n kaapana

# Restart indexing service
kubectl delete pod -l app=kaapana-indexing -n kaapana
```

### Workflow Fails

**Symptoms:**
- Airflow DAG run fails
- Tasks show red in graph

**Diagnosis:**
```bash
# Get DAG run logs
kubectl exec deployment/airflow-scheduler -n kaapana -- \
  airflow tasks logs <dag-id> <task-id> <execution-date>

# Or view in Airflow UI: Graph view → Click task → View Log
```

**Solutions:**

**Operator image missing:**
```bash
# Check images
microk8s ctr images list | grep operator

# Re-import if missing
```

**Resource constraint:**
```bash
# Check worker pod resources
kubectl top pods -n kaapana | grep airflow-worker

# Scale down workers or increase resources
```

---

## Recovery Procedures

### Complete System Reset

**⚠️ Warning: Destroys all data**

```bash
# 1. Delete Kaapana
helm uninstall kaapana-platform -n kaapana
helm uninstall kaapana-admin -n admin
kubectl delete namespace kaapana admin

# 2. Reset MicroK8s
microk8s reset

# 3. Clean Docker
docker system prune -af --volumes

# 4. Redeploy from Step 5 in setup guide
```

### Restart All Kaapana Pods

```bash
# Restart all deployments
kubectl rollout restart deployment -n kaapana

# Wait for all pods ready
kubectl wait --for=condition=ready pod --all -n kaapana --timeout=600s
```

### Backup Critical Data

```bash
# Backup MinIO data
mc mirror kaapana-minio/kaapana-data ~/backup/minio-data/

# Backup dcm4chee database
kubectl exec deployment/postgres -n kaapana -- \
  pg_dump -U pacsdb pacsdb > ~/backup/dcm4chee-db.sql

# Backup OpenSearch indices
curl -X POST "localhost:9200/_snapshot/backup/snapshot_1?wait_for_completion=true"
```

---

## Getting Help

### Before Asking for Help

**Gather this information:**

1. **Environment details:**
   ```bash
   kubectl version --short
   microk8s version
   lsb_release -a
   ```

2. **Pod status:**
   ```bash
   kubectl get pods -n kaapana
   ```

3. **Relevant logs:**
   ```bash
   kubectl logs <failing-pod> -n kaapana --tail=100
   ```

4. **Recent changes:**
   - What were you doing when the issue occurred?
   - Any recent configuration changes?

### Where to Get Help

- **Kaapana GitHub Issues:** https://github.com/kaapana/kaapana/issues
- **Kaapana Discussions:** https://github.com/kaapana/kaapana/discussions
- **Email:** kaapana@dkfz-heidelberg.de
- **Documentation:** https://kaapana.readthedocs.io/

---

**Document Status:** ✅ Complete  
**Quick Tip:** Always check logs first - they usually reveal the issue!
