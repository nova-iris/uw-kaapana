# 05 - Server Installation and Kubernetes Setup

**Phase:** 3 - Deploy  
**Duration:** 20-30 minutes (mostly automated)  

---

## Overview

This guide installs MicroK8s (lightweight Kubernetes) and prepares the server infrastructure for Kaapana platform deployment:
- System prerequisites installation
- MicroK8s Kubernetes cluster setup
- Network and firewall configuration
- Docker images import for MicroK8s

---

## Prerequisites Check

### Verify System Requirements

```bash
# SSH to AWS server
ssh -i kaapana-poc-key.pem ubuntu@$ELASTIC_IP

# Verify Kaapana files exist
ls -la ~/kaapana/server-installation/server_installation.sh
# OR if transferred: ls -la ~/kaapana-deploy/server-installation/server_installation.sh
```

---

## Step 1: Configure Optional Settings (Optional)

### Setup Proxy (If Required)

```bash
# Edit environment file if your network requires proxy
sudo nano /etc/environment

# Add proxy variables:
# http_proxy="your.proxy.url:port"
# https_proxy="your.proxy.url:port"
# HTTP_PROXY="your.proxy.url:port"
# HTTPS_PROXY="your.proxy.url:port"

# Logout and login for changes to take effect
logout
# Then ssh back in
```

### Configure Custom DNS (If Required)

```bash
# Edit server_installation.sh to use custom DNS
sed -i 's/DNS=""/DNS="my.custom.dns"/' ~/kaapana-build/kaapana/server-installation/server_installation.sh
```

---

## Step 2: Run Server Installation Script

### Execute Installation

```bash
# Navigate to installation directory
cd ~/kaapana/server-installation

# Make script executable
chmod +x server_installation.sh

# Run installation (requires sudo, takes 20-30 minutes)
# IMPORTANT: The script will ask "Is this correct and you don't need a proxy?" - answer 'y'
# Note: On AlmaLinux, use: sudo -E ./server_installation.sh
echo 'y' | sudo ./server_installation.sh

# Reboot after completion
sudo reboot
```

---

## Step 5: Configure Network Access

### Verify Open Ports

```bash
# Default Kaapana ports:
# - Port 80: HTTP (redirects to HTTPS)
# - Port 443: HTTPS (Web interface)
# - Port 11112: DIMSE (DICOM transmission)

# Check listening ports
sudo ss -tulpn | grep -E "(:80|:443|:11112)"
```

### Configure Firewall (If UFW Enabled)

```bash
# Check firewall status
sudo ufw status

# If active, allow required ports:
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 11112/tcp
sudo ufw reload
```

---

## Reference Documentation

Official Kaapana Server Installation:
- https://kaapana.readthedocs.io/en/latest/installation_guide/server_installation.html

---