# 06 - Platform Deployment

**Phase:** 3 - Deploy  
**Duration:** 30-60 minutes  
**Prerequisite:** 05-server-installation.md completed

---

## Overview

This guide deploys the Kaapana platform using Helm charts. The deployment includes:
- dcm4chee (PACS server)
- Airflow (workflow orchestration)
- OpenSearch (metadata indexing)
- MinIO (object storage)
- Keycloak (authentication)
- OHIF viewer (DICOM viewing)
- Kaapana UI (management interface)

---

## Prerequisites Check

```bash
# SSH to AWS server
ssh -i kaapana-poc-key.pem ubuntu@$ELASTIC_IP

# Verify Kubernetes ready
kubectl get nodes
# Should show: Ready

# Verify namespace exists
kubectl get namespace kaapana

# Verify images in MicroK8s
microk8s ctr images list | grep kaapana | wc -l
# Should show: 90+

# Check disk space
df -h /
# Should show: 80GB+ free
```

---

## Step 1: Locate Deployment Scripts

### Determine Kaapana Directory

**If built on same machine:**
```bash
export KAAPANA_DIR=~/kaapana-build/kaapana
```

**If transferred from build machine:**
```bash
export KAAPANA_DIR=~/kaapana-deploy
```

**Verify deployment script exists:**
```bash
ls -la $KAAPANA_DIR/platforms/deploy_platform.sh
ls -la $KAAPANA_DIR/platforms/kaapana-platform-chart/

# Should show deployment script and chart directory
```

---

## Step 2: Configure Deployment

### Navigate to Platforms Directory
```bash
cd $KAAPANA_DIR/platforms
```

### Review Deploy Script
```bash
# View script to understand deployment process
less deploy_platform.sh

# Key actions:
# 1. Loads configuration
# 2. Configures Helm values
# 3. Deploys kaapana-platform chart
# 4. Deploys kaapana-admin chart
# 5. Waits for pods to be ready
```

**Press `Q` to exit**

### Create Deployment Configuration

```bash
# Create minimal deployment config
cat > deploy-config.yaml << 'EOF'
# Kaapana POC Deployment Configuration

# Platform Settings
platform:
  name: "kaapana-poc"
  namespace: "kaapana"
  domain: "kaapana.local"  # Will be accessed via IP

# Container Registry
registry:
  url: "localhost:32000"   # MicroK8s local registry
  pullPolicy: "IfNotPresent"

# Storage
storage:
  storageClass: "microk8s-hostpath"
  pvPath: "/mnt/kaapana-storage/pvs"

# Components
components:
  # PACS Server
  dcm4chee:
    enabled: true
    replicas: 1
    storage: "50Gi"
  
  # Workflow Orchestration
  airflow:
    enabled: true
    replicas: 1
    executorType: "LocalExecutor"
  
  # Metadata Indexing
  opensearch:
    enabled: true
    replicas: 1
    storage: "30Gi"
  
  # Object Storage
  minio:
    enabled: true
    replicas: 1
    storage: "100Gi"
  
  # Authentication
  keycloak:
    enabled: true
    replicas: 1
  
  # DICOM Viewer
  ohif:
    enabled: true
    replicas: 1
  
  # Kaapana UI
  kaapana-ui:
    enabled: true
    replicas: 1

# Resource Limits (POC - minimal)
resources:
  limits:
    memory: "2Gi"
    cpu: "1000m"
  requests:
    memory: "512Mi"
    cpu: "100m"

# Ingress
ingress:
  enabled: true
  className: "nginx"
  tls:
    enabled: false  # No TLS for POC

# Admin User
admin:
  username: "kaapana"
  password: "kaapana"  # Change after deployment
  email: "admin@kaapana.local"
EOF
```

---

## Step 3: Deploy Platform

### Execute Deployment

**⚠️ Important:** Deployment takes 20-40 minutes. Use `screen` to avoid interruption.

```bash
# Start screen session
screen -S kaapana-deploy

# Inside screen session:
cd $KAAPANA_DIR/platforms

# Run deployment
./deploy_platform.sh \
  --config deploy-config.yaml \
  --namespace kaapana \
  --wait 2>&1 | tee deploy.log
```

**Detach from screen:** `Ctrl+A` then `D`  
**Reattach:** `screen -r kaapana-deploy`

### Alternative: Manual Helm Deployment

**If deploy script doesn't work, deploy manually:**

```bash
# Deploy platform chart
helm upgrade --install kaapana-platform \
  ./kaapana-platform-chart \
  --namespace kaapana \
  --create-namespace \
  --set global.registry_url=localhost:32000 \
  --set global.pull_policy=IfNotPresent \
  --set global.domain=kaapana.local \
  --wait \
  --timeout 30m

# Deploy admin chart
helm upgrade --install kaapana-admin \
  ./kaapana-admin-chart \
  --namespace admin \
  --create-namespace \
  --set global.registry_url=localhost:32000 \
  --wait \
  --timeout 10m
```

---

## Step 4: Monitor Deployment

### Watch Pod Status

**In another SSH session:**
```bash
# Watch all pods in kaapana namespace
watch -n 5 "kubectl get pods -n kaapana"

# Watch pod events
kubectl get events -n kaapana --watch
```

**Expected progression:**
```
# Initial state (0-2 min):
NAME                                READY   STATUS              RESTARTS   AGE
dcm4chee-xxx                        0/1     ContainerCreating   0          30s
airflow-xxx                         0/1     ContainerCreating   0          30s
opensearch-xxx                      0/1     ContainerCreating   0          30s
...

# Containers starting (2-5 min):
NAME                                READY   STATUS    RESTARTS   AGE
dcm4chee-xxx                        0/1     Running   0          2m
airflow-xxx                         0/1     Running   0          2m
opensearch-xxx                      1/1     Running   0          2m
...

# Fully ready (10-30 min):
NAME                                READY   STATUS    RESTARTS   AGE
dcm4chee-xxx                        1/1     Running   0          15m
airflow-xxx                         1/1     Running   0          15m
opensearch-xxx                      1/1     Running   0          15m
minio-xxx                           1/1     Running   0          15m
keycloak-xxx                        1/1     Running   0          15m
ohif-xxx                            1/1     Running   0          15m
kaapana-ui-xxx                      1/1     Running   0          15m
...
```

### Check Helm Releases

```bash
# List Helm releases
helm list -n kaapana
helm list -n admin

# Expected output:
# NAME              NAMESPACE  REVISION  STATUS    CHART
# kaapana-platform  kaapana    1         deployed  kaapana-platform-0.3.0
# kaapana-admin     admin      1         deployed  kaapana-admin-0.3.0
```

### Check Services

```bash
# List services
kubectl get svc -n kaapana

# Expected services:
# NAME                 TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)
# dcm4chee-arc         ClusterIP   10.152.xxx.xxx  <none>        8080/TCP,11112/TCP
# airflow-web          ClusterIP   10.152.xxx.xxx  <none>        8080/TCP
# opensearch           ClusterIP   10.152.xxx.xxx  <none>        9200/TCP
# minio                ClusterIP   10.152.xxx.xxx  <none>        9000/TCP
# keycloak             ClusterIP   10.152.xxx.xxx  <none>        8080/TCP
# ohif-viewer          ClusterIP   10.152.xxx.xxx  <none>        80/TCP
# kaapana-ui           ClusterIP   10.152.xxx.xxx  <none>        80/TCP
```

### Check Ingress

```bash
# Check ingress resources
kubectl get ingress -n kaapana

# Expected ingress:
# NAME              CLASS   HOSTS           ADDRESS        PORTS   AGE
# kaapana-ingress   nginx   kaapana.local   10.152.xxx.xxx 80      15m
```

---

## Step 5: Verify Deployment

### Check All Pods Running

```bash
# Get all pods in kaapana namespace
kubectl get pods -n kaapana

# Should show all pods with STATUS: Running and READY: 1/1
```

### Run Deployment Verification Script

```bash
cat > ~/verify-deployment.sh << 'EOF'
#!/bin/bash
echo "=== Kaapana Deployment Verification ==="
echo ""

# Helm Releases
echo "Helm Releases:"
helm list -n kaapana
helm list -n admin
echo ""

# Pod Status
echo "Pod Status:"
kubectl get pods -n kaapana
echo ""

# Check all pods ready
NOT_READY=$(kubectl get pods -n kaapana --no-headers | grep -v "1/1.*Running" | wc -l)
if [ "$NOT_READY" -eq 0 ]; then
  echo "✅ All pods are ready and running"
else
  echo "⚠️  $NOT_READY pod(s) not ready"
  kubectl get pods -n kaapana | grep -v "1/1.*Running"
fi
echo ""

# Services
echo "Services:"
kubectl get svc -n kaapana | grep -E "NAME|dcm4chee|airflow|opensearch|minio|keycloak|ohif|kaapana"
echo ""

# Ingress
echo "Ingress:"
kubectl get ingress -n kaapana
echo ""

# Persistent Volumes
echo "Persistent Volumes:"
kubectl get pv | grep kaapana
echo ""

# Resource Usage
echo "Resource Usage:"
kubectl top nodes 2>/dev/null || echo "  (metrics not available - normal for new deployment)"
echo ""

echo "=== Verification Complete ==="
EOF

chmod +x ~/verify-deployment.sh
~/verify-deployment.sh
```

---

## Step 6: Access Kaapana UI

### Get Access Information

```bash
# Get ingress IP
kubectl get ingress -n kaapana -o wide

# Get node IP
kubectl get nodes -o wide

# For MicroK8s, typically access via node IP
KAAPANA_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
echo "Kaapana UI: http://$KAAPANA_IP"
```

### Configure Local Access

**On your local workstation (not AWS server):**

**Option A: Direct IP Access**
```bash
# Simply open browser to AWS Elastic IP
# http://YOUR_ELASTIC_IP/
```

**Option B: Use domain name with hosts file**
```bash
# Edit /etc/hosts (Linux/Mac) or C:\Windows\System32\drivers\etc\hosts (Windows)
sudo nano /etc/hosts

# Add line:
YOUR_ELASTIC_IP    kaapana.local

# Save and test
ping kaapana.local
```

### Login to Kaapana

**Open browser:**
```
http://YOUR_ELASTIC_IP/
# or
http://kaapana.local/
```

**Default credentials:**
- Username: `kaapana`
- Password: `kaapana`

**You should see:**
- Kaapana landing page
- Navigation to OHIF viewer, Airflow, dcm4chee admin
- Links to documentation

---

## Step 7: Access Component UIs

### Kaapana Services Access

| Service | URL | Default Credentials |
|---------|-----|---------------------|
| **Kaapana UI** | http://YOUR_IP/ | kaapana / kaapana |
| **Airflow** | http://YOUR_IP/flow/ | kaapana / kaapana |
| **OHIF Viewer** | http://YOUR_IP/ohif/ | (SSO via Keycloak) |
| **OpenSearch** | http://YOUR_IP/opensearch-dashboards/ | admin / admin |
| **MinIO Console** | http://YOUR_IP/minio-console/ | minio / minio123 |
| **dcm4chee Admin** | http://YOUR_IP/dcm4chee-arc/ui2/ | admin / admin |

### Test Component Access

```bash
# From AWS server, test internal access
curl -I http://localhost/
curl -I http://localhost/flow/
curl -I http://localhost/ohif/

# Should return HTTP 200 or 302 (redirect)
```

---

## Step 8: Configure Keycloak (Authentication)

### Access Keycloak Admin Console

```bash
# Get Keycloak admin password
kubectl get secret keycloak-secret -n kaapana \
  -o jsonpath='{.data.admin-password}' | base64 -d
echo ""

# Access Keycloak admin console
# URL: http://YOUR_IP/auth/admin/
# Username: admin
# Password: (from above command)
```

### Create Kaapana Users

**In Keycloak UI:**
1. Navigate to "Users" → "Add user"
2. Fill in user details:
   - Username: `testuser`
   - Email: `testuser@kaapana.local`
   - First Name: `Test`
   - Last Name: `User`
3. Click "Save"
4. Go to "Credentials" tab
5. Set password: `test123`
6. Disable "Temporary" toggle
7. Click "Set Password"

---

## Troubleshooting

### Pods not starting
```bash
# Check pod details
kubectl describe pod <pod-name> -n kaapana

# Check pod logs
kubectl logs <pod-name> -n kaapana

# Common issues:
# - Image pull errors: Check images in MicroK8s (microk8s ctr images list)
# - Storage errors: Check PV/PVC status (kubectl get pv,pvc -n kaapana)
# - Resource limits: Check node resources (kubectl top nodes)
```

### Ingress not accessible
```bash
# Check ingress controller
kubectl get pods -n ingress

# Restart ingress if needed
kubectl rollout restart deployment nginx-ingress-microk8s-controller -n ingress

# Check AWS security group allows port 80
# AWS Console → EC2 → Security Groups → Inbound Rules
```

### dcm4chee not starting
```bash
# dcm4chee requires more memory
# Check pod events
kubectl describe pod -l app=dcm4chee -n kaapana

# If OOMKilled, increase resources:
kubectl patch deployment dcm4chee -n kaapana \
  -p '{"spec":{"template":{"spec":{"containers":[{"name":"dcm4chee","resources":{"limits":{"memory":"4Gi"}}}]}}}}'
```

### Airflow not accessible
```bash
# Check Airflow webserver pod
kubectl get pods -l app=airflow-web -n kaapana
kubectl logs -l app=airflow-web -n kaapana

# Restart if needed
kubectl rollout restart deployment airflow-web -n kaapana
```

### OpenSearch fails to start
```bash
# OpenSearch requires vm.max_map_count adjustment
# On AWS server:
sudo sysctl -w vm.max_map_count=262144
echo "vm.max_map_count=262144" | sudo tee -a /etc/sysctl.conf

# Restart OpenSearch pod
kubectl delete pod -l app=opensearch -n kaapana
```

---

## Deployment Complete Checklist

Before proceeding to testing, verify:

- [x] All pods in `kaapana` namespace are Running (1/1)
- [x] Helm releases deployed successfully
- [x] Services created and have ClusterIP
- [x] Ingress configured and accessible
- [x] Kaapana UI accessible via browser
- [x] Can login with default credentials
- [x] Airflow UI accessible
- [x] OHIF viewer accessible
- [x] dcm4chee admin UI accessible
- [x] No pod restart loops or errors

---

## Next Steps

✅ **Platform deployed and accessible!**

**Next:** [07-data-upload-testing.md](07-data-upload-testing.md)

You'll upload DICOM data and verify the platform can store and display medical images.

---

## Quick Reference

**Check pods:**
```bash
kubectl get pods -n kaapana
```

**Check logs:**
```bash
kubectl logs <pod-name> -n kaapana -f
```

**Restart deployment:**
```bash
kubectl rollout restart deployment <deployment-name> -n kaapana
```

**Access UI:**
```
http://YOUR_ELASTIC_IP/
Username: kaapana
Password: kaapana
```

---

**Document Status:** ✅ Complete  
**Next Document:** 07-data-upload-testing.md
