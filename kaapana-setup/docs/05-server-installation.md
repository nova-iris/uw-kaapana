# 05 - Server Installation and Kubernetes Setup

**Phase:** 3 - Deploy  
**Duration:** 30-45 minutes  
**Prerequisite:** 03-kaapana-build-process.md OR 04-artifact-transfer.md completed

---

## Overview

This guide installs the Kubernetes infrastructure needed for Kaapana:
- MicroK8s (lightweight Kubernetes)
- Required addons (DNS, storage, ingress, registry)
- System configurations
- Network setup

---

## Prerequisites Check

### Verify System State

```bash
# SSH to AWS server
ssh -i kaapana-poc-key.pem ubuntu@$ELASTIC_IP

# Check Docker images exist
docker images | wc -l
# Should show: 90+ images

# Check deployment files exist
# If built on same machine:
ls -la ~/kaapana-build/kaapana/server-installation/server_installation.sh
# If transferred from build machine:
ls -la ~/kaapana-deploy/server-installation/server_installation.sh

# Check disk space
df -h /
# Should show: 100GB+ free

# Check RAM
free -h
# Should show: 64GB total (r5.2xlarge) or 128GB (r5.4xlarge)
```

---

## Step 1: Locate Server Installation Script

### Determine Installation Path

**If built on same machine:**
```bash
export KAAPANA_DIR=~/kaapana-build/kaapana
```

**If transferred from build machine:**
```bash
export KAAPANA_DIR=~/kaapana-deploy
```

**Verify script exists:**
```bash
ls -la $KAAPANA_DIR/server-installation/server_installation.sh

# Should show executable script
```

---

## Step 2: Review Installation Script

```bash
# View script to understand what it does
less $KAAPANA_DIR/server-installation/server_installation.sh

# Key actions performed by script:
# 1. System updates and prerequisites
# 2. Snap installation (if needed)
# 3. MicroK8s installation
# 4. MicroK8s addons enablement
# 5. Network and firewall configuration
# 6. Storage configuration
# 7. User permissions setup
```

**Press `Q` to exit `less`**

---

## Step 3: Run Server Installation

### Execute Installation Script

**⚠️ Important:** This script requires sudo and takes 20-30 minutes.

```bash
# Navigate to server-installation directory
cd $KAAPANA_DIR/server-installation

# Make script executable (if not already)
chmod +x server_installation.sh

# Run installation (use screen for long-running process)
screen -S kaapana-install

# Inside screen session:
sudo ./server_installation.sh 2>&1 | tee install.log
```

**Detach from screen:** `Ctrl+A` then `D`  
**Reattach:** `screen -r kaapana-install`

### Expected Installation Flow

```
[INFO] Kaapana Server Installation Starting...
[INFO] Checking system requirements...
[INFO] Installing system prerequisites...
[INFO] Installing MicroK8s...
[INFO] Waiting for MicroK8s to be ready...
[INFO] Enabling MicroK8s addons...
  - dns
  - storage
  - ingress
  - registry
[INFO] Configuring network settings...
[INFO] Setting up user permissions...
[INFO] Installation complete!
```

### Monitor Progress

**In another SSH session:**
```bash
# Watch MicroK8s installation
watch -n 5 "snap list | grep microk8s"

# Watch MicroK8s status (after installed)
watch -n 5 "microk8s status"

# Check installation log
tail -f $KAAPANA_DIR/server-installation/install.log
```

---

## Step 4: Verify MicroK8s Installation

### Check MicroK8s Status

```bash
# Check MicroK8s is running
microk8s status --wait-ready

# Expected output:
# microk8s is running
# high-availability: no
# addons:
#   enabled:
#     dns
#     storage
#     ingress
#     registry
#   disabled:
#     ...
```

### Check Kubernetes Components

```bash
# Check nodes
microk8s kubectl get nodes

# Expected output:
# NAME             STATUS   ROLES    AGE   VERSION
# ip-xx-xx-xx-xx   Ready    <none>   5m    v1.28.x

# Check system pods
microk8s kubectl get pods -n kube-system

# Should show running pods:
# - coredns
# - calico-node
# - calico-kube-controllers
```

### Check MicroK8s Addons

```bash
# Verify enabled addons
microk8s status | grep -A 20 "enabled:"

# Should show:
#   dns                  # enabled
#   storage              # enabled
#   ingress              # enabled
#   registry             # enabled
```

---

## Step 5: Configure kubectl Access

### Setup kubectl Alias

```bash
# Create kubectl alias
echo "alias kubectl='microk8s kubectl'" >> ~/.bashrc
source ~/.bashrc

# Test alias
kubectl version --short
kubectl get nodes
```

### Generate kubeconfig (optional)

**For external access from your workstation:**
```bash
# On AWS server: export kubeconfig
microk8s config > ~/kaapana-kubeconfig.yaml

# View config
cat ~/kaapana-kubeconfig.yaml
```

**On your workstation:**
```bash
# Copy kubeconfig from server
scp -i kaapana-poc-key.pem ubuntu@$ELASTIC_IP:~/kaapana-kubeconfig.yaml ~/.kube/kaapana-config

# Use config
export KUBECONFIG=~/.kube/kaapana-config
kubectl get nodes
```

---

## Step 6: Create Kaapana Namespace

```bash
# Create kaapana namespace
kubectl create namespace kaapana

# Verify namespace
kubectl get namespaces

# Should show:
# NAME              STATUS   AGE
# kaapana           Active   5s
# kube-system       Active   10m
# default           Active   10m
```

---

## Step 7: Configure Storage

### Create Persistent Volumes Directory

```bash
# Create storage directory
sudo mkdir -p /mnt/kaapana-storage/pvs
sudo chmod 777 /mnt/kaapana-storage/pvs

# Verify
ls -la /mnt/kaapana-storage/
```

### Configure Default Storage Class

```bash
# Check storage class
kubectl get storageclass

# Should show:
# NAME                          PROVISIONER
# microk8s-hostpath (default)   microk8s.io/hostpath

# Set as default if not already
kubectl patch storageclass microk8s-hostpath \
  -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
```

---

## Step 8: Configure Network Access

### Check Ingress Controller

```bash
# Verify ingress controller running
kubectl get pods -n ingress

# Should show nginx-ingress-microk8s-controller pod running

# Check ingress service
kubectl get svc -n ingress

# Should show LoadBalancer or NodePort service
```

### Configure Firewall (if UFW enabled)

```bash
# Check if UFW active
sudo ufw status

# If active, allow required ports:
sudo ufw allow 80/tcp    # HTTP
sudo ufw allow 443/tcp   # HTTPS
sudo ufw allow 11112/tcp # DICOM
sudo ufw reload

# Verify rules
sudo ufw status numbered
```

### Verify Port Access

```bash
# Check ports listening
sudo netstat -tulpn | grep -E "(:80|:443|:11112)"

# Or using ss:
sudo ss -tulpn | grep -E "(:80|:443|:11112)"
```

---

## Step 9: Load Docker Images to MicroK8s

### Import Images to MicroK8s Registry

**Kaapana uses local Docker images. MicroK8s needs access to them:**

```bash
# Check Docker images
docker images | grep "local-only" | wc -l
# Should show 90+

# Tag images for MicroK8s local registry
for img in $(docker images --format "{{.Repository}}:{{.Tag}}" | grep "local-only"); do
  # Remove local-only prefix and tag for localhost:32000
  new_tag=$(echo $img | sed 's/local-only\//localhost:32000\//')
  docker tag $img $new_tag
  echo "Tagged: $img -> $new_tag"
done

# Push images to MicroK8s registry
for img in $(docker images --format "{{.Repository}}:{{.Tag}}" | grep "localhost:32000"); do
  docker push $img
  echo "Pushed: $img"
done

# This takes 15-20 minutes
```

**Or use the simpler approach (recommended):**
```bash
# Export Docker images and import to MicroK8s
docker save $(docker images --format "{{.Repository}}:{{.Tag}}" | grep "local-only") | \
  microk8s ctr image import -

# Verify images in MicroK8s
microk8s ctr images list | grep kaapana | head -20
```

---

## Step 10: Verification

### Run System Verification

```bash
cat > ~/verify-k8s-setup.sh << 'EOF'
#!/bin/bash
echo "=== Kaapana Kubernetes Setup Verification ==="
echo ""

# MicroK8s Status
echo "MicroK8s Status:"
microk8s status --wait-ready | head -10
echo ""

# Kubernetes Nodes
echo "Kubernetes Nodes:"
kubectl get nodes
echo ""

# Addons
echo "Enabled Addons:"
microk8s status | grep -A 10 "enabled:"
echo ""

# System Pods
echo "System Pods:"
kubectl get pods -n kube-system
echo ""

# Storage Class
echo "Storage Classes:"
kubectl get storageclass
echo ""

# Kaapana Namespace
if kubectl get namespace kaapana &>/dev/null; then
  echo "✅ Kaapana namespace exists"
else
  echo "❌ Kaapana namespace missing"
fi
echo ""

# Images in MicroK8s
IMAGE_COUNT=$(microk8s ctr images list | wc -l)
echo "MicroK8s Images: $IMAGE_COUNT"
if [ "$IMAGE_COUNT" -ge 90 ]; then
  echo "  ✅ Images imported"
else
  echo "  ⚠️  Only $IMAGE_COUNT images (expected 90+)"
fi
echo ""

# Ingress Controller
echo "Ingress Controller:"
kubectl get pods -n ingress
echo ""

echo "=== Verification Complete ==="
EOF

chmod +x ~/verify-k8s-setup.sh
~/verify-k8s-setup.sh
```

**Expected output:**
```
=== Kaapana Kubernetes Setup Verification ===

MicroK8s Status:
microk8s is running

Kubernetes Nodes:
NAME             STATUS   ROLES    AGE   VERSION
ip-xx-xx-xx-xx   Ready    <none>   30m   v1.28.x

Enabled Addons:
  enabled:
    dns
    storage
    ingress
    registry

System Pods:
NAME                                      READY   STATUS    RESTARTS   AGE
coredns-xxx                               1/1     Running   0          30m
calico-node-xxx                           1/1     Running   0          30m
calico-kube-controllers-xxx               1/1     Running   0          30m

Storage Classes:
NAME                          PROVISIONER
microk8s-hostpath (default)   microk8s.io/hostpath

✅ Kaapana namespace exists

MicroK8s Images: 95
  ✅ Images imported

Ingress Controller:
NAME                                      READY   STATUS    RESTARTS   AGE
nginx-ingress-microk8s-controller-xxx     1/1     Running   0          28m

=== Verification Complete ===
```

---

## Troubleshooting

### MicroK8s not starting
```bash
# Check MicroK8s status
microk8s status

# Check logs
microk8s inspect

# Restart MicroK8s
sudo snap restart microk8s

# Wait for ready
microk8s status --wait-ready
```

### Addon not enabling
```bash
# Disable and re-enable addon
microk8s disable dns
microk8s enable dns

# Check addon status
microk8s status | grep dns
```

### Images not importing
```bash
# Check Docker images exist
docker images | grep "local-only"

# Try alternative import method:
# 1. Save to tar
docker save -o /tmp/kaapana-images.tar $(docker images --format "{{.Repository}}:{{.Tag}}" | grep "local-only")

# 2. Import to MicroK8s
microk8s ctr image import /tmp/kaapana-images.tar

# 3. Verify
microk8s ctr images list | grep kaapana

# 4. Cleanup
rm /tmp/kaapana-images.tar
```

### kubectl not working
```bash
# Check alias
alias kubectl

# If not set:
echo "alias kubectl='microk8s kubectl'" >> ~/.bashrc
source ~/.bashrc

# Test
kubectl version
```

### Permission denied errors
```bash
# Add user to microk8s group
sudo usermod -aG microk8s $USER

# Apply changes (logout/login or use newgrp)
newgrp microk8s

# Test
microk8s status
```

---

## Installation Complete Checklist

Before proceeding to platform deployment, verify:

- [x] MicroK8s installed and running
- [x] MicroK8s addons enabled (dns, storage, ingress, registry)
- [x] Kubernetes cluster healthy (node ready)
- [x] System pods running (coredns, calico, ingress)
- [x] `kubectl` command working
- [x] Kaapana namespace created
- [x] Storage class configured
- [x] Docker images imported to MicroK8s (90+)
- [x] Ports accessible (80, 443, 11112)

---

## Next Steps

✅ **Kubernetes environment ready!**

**Next:** [06-platform-deployment.md](06-platform-deployment.md)

You'll deploy the Kaapana platform using Helm charts.

---

## Quick Reference

**Check MicroK8s status:**
```bash
microk8s status
```

**Check cluster:**
```bash
kubectl get nodes
kubectl get pods -A
```

**Restart MicroK8s:**
```bash
sudo snap restart microk8s
```

**View logs:**
```bash
microk8s inspect
```

---

**Document Status:** ✅ Complete  
**Next Document:** 06-platform-deployment.md
