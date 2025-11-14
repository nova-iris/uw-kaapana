#!/bin/bash

#############################################
# Kaapana Platform Deployment Wrapper Script
# Based on: 06-platform-deployment.md
# Duration: 30-45 minutes (mostly automated)
#############################################

set -e  # Exit on error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Log functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

echo "=================================================="
echo "   Kaapana Platform Deployment"
echo "   Based on guideline 06-platform-deployment.md"
echo "=================================================="
echo ""

#############################################
# Prerequisites Check
#############################################

log_info "Checking prerequisites..."

# Check if Kubernetes is ready
if ! microk8s kubectl get nodes &> /dev/null; then
    log_error "Kubernetes (MicroK8s) is not ready"
    log_error "Please run server installation first (guideline 05)"
    exit 1
fi

# Get node status
NODE_STATUS=$(microk8s kubectl get nodes --no-headers | awk '{print $2}')
if [ "$NODE_STATUS" != "Ready" ]; then
    log_error "Kubernetes node is not Ready (current status: $NODE_STATUS)"
    log_error "Please wait for node to be ready or troubleshoot MicroK8s"
    exit 1
fi

log_success "Kubernetes cluster is Ready"

# Check disk space
DISK_AVAIL=$(df / --output=avail -BG | tail -1 | tr -d 'G ')
if [ "$DISK_AVAIL" -lt 80 ]; then
    log_warning "Low disk space: ${DISK_AVAIL}GB available"
    log_warning "Recommended: 100GB+ free space for platform deployment"
    read -p "Continue anyway? (y/n) " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 0
    fi
else
    log_success "Disk space: ${DISK_AVAIL}GB available"
fi

# Find Kaapana directory
if [ -d "$HOME/kaapana" ]; then
    KAAPANA_DIR="$HOME/kaapana"
elif [ -d "$HOME/kaapana-deploy" ]; then
    KAAPANA_DIR="$HOME/kaapana-deploy"
else
    log_error "Kaapana directory not found"
    log_error "Expected: $HOME/kaapana or $HOME/kaapana-deploy"
    exit 1
fi

log_success "Found Kaapana directory: $KAAPANA_DIR"

# Check if deploy script exists
DEPLOY_SCRIPT="$KAAPANA_DIR/build/kaapana-admin-chart/deploy_platform.sh"
if [ ! -f "$DEPLOY_SCRIPT" ]; then
    log_error "Deployment script not found: $DEPLOY_SCRIPT"
    log_error "Please ensure the build process completed successfully"
    exit 1
fi

log_success "Deployment script found"

#############################################
# Gather Deployment Configuration
#############################################

log_info "Gathering deployment configuration..."

echo ""
log_info "The deployment script will ask for the following:"
echo "  1. Server domain (FQDN) or IP address"
echo "  2. GPU support (y/n)"
echo "  3. Container registry credentials (if using private registry)"
echo ""

# Get server IP/domain
log_info "Detecting server IP addresses..."
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo "")
PRIVATE_IP=$(hostname -I | awk '{print $1}')

if [ -n "$PUBLIC_IP" ]; then
    log_info "Detected public IP: $PUBLIC_IP"
fi
log_info "Detected private IP: $PRIVATE_IP"

echo ""
read -p "Enter server domain or IP (default: $PUBLIC_IP): " SERVER_DOMAIN
if [ -z "$SERVER_DOMAIN" ]; then
    if [ -n "$PUBLIC_IP" ]; then
        SERVER_DOMAIN="$PUBLIC_IP"
    else
        SERVER_DOMAIN="$PRIVATE_IP"
    fi
fi
log_success "Server domain/IP: $SERVER_DOMAIN"

# GPU support
echo ""
read -p "Enable GPU support? (y/n, default: n): " GPU_SUPPORT
if [[ ! $GPU_SUPPORT =~ ^[Yy]$ ]]; then
    GPU_SUPPORT="n"
    log_info "GPU support: Disabled"
else
    GPU_SUPPORT="y"
    log_warning "GPU support: Enabled (ensure NVIDIA drivers are installed)"
fi

# Container registry
echo ""
log_info "Container registry configuration:"
log_info "  - For local build: Use MicroK8s registry (leave blank)"
log_info "  - For remote registry: Provide registry URL and credentials"
echo ""
read -p "Use remote container registry? (y/n, default: n): " USE_REMOTE_REGISTRY

#############################################
# Create Deployment Configuration File
#############################################

log_info "Creating deployment configuration..."

mkdir -p ~/kaapana-deployment

cat > ~/kaapana-deployment/deployment-config.txt <<EOF
# Kaapana Platform Deployment Configuration
# Generated: $(date)

SERVER_DOMAIN=$SERVER_DOMAIN
GPU_SUPPORT=$GPU_SUPPORT
USE_REMOTE_REGISTRY=$USE_REMOTE_REGISTRY
EOF

log_success "Configuration saved to: ~/kaapana-deployment/deployment-config.txt"

#############################################
# Run Deployment
#############################################

log_info "Preparing to deploy Kaapana platform..."
log_warning "This will deploy all Kaapana services to Kubernetes"
log_warning "Deployment will take approximately 30-45 minutes"
log_warning "Pod initialization may take 10-30 minutes after deployment"

echo ""
read -p "Continue with platform deployment? (y/n) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    log_info "Deployment cancelled"
    exit 0
fi

# Navigate to deployment directory
cd "$KAAPANA_DIR/build/kaapana-admin-chart"

# Make script executable
chmod +x deploy_platform.sh

# Create log directory
mkdir -p ~/kaapana-logs

log_info "Starting platform deployment..."
log_info "Deployment log will be saved to: ~/kaapana-logs/platform-deployment.log"

echo ""
log_info "Running deployment script..."
log_warning "The script will prompt for configuration inputs"
echo ""

# Run deployment script and log output
./deploy_platform.sh 2>&1 | tee ~/kaapana-logs/platform-deployment.log

DEPLOY_EXIT_CODE=${PIPESTATUS[0]}

if [ $DEPLOY_EXIT_CODE -ne 0 ]; then
    log_error "Platform deployment failed with exit code: $DEPLOY_EXIT_CODE"
    log_error "Check the log file: ~/kaapana-logs/platform-deployment.log"
    exit 1
fi

log_success "Deployment script completed successfully!"

#############################################
# Wait for Pods to be Ready
#############################################

log_info "Waiting for pods to be ready..."
log_info "This may take 10-30 minutes depending on image pull speed"

echo ""
log_info "You can monitor pod status with:"
echo "  watch microk8s kubectl get pods -A"
echo ""

# Create monitoring script
cat > ~/kaapana-deployment/monitor-pods.sh <<'EOF'
#!/bin/bash
while true; do
    clear
    echo "=== Kaapana Pod Status ==="
    echo "Press Ctrl+C to exit"
    echo ""
    
    microk8s kubectl get pods -A | grep -E "NAME|kaapana|services|admin"
    
    echo ""
    TOTAL=$(microk8s kubectl get pods -A --no-headers | wc -l)
    RUNNING=$(microk8s kubectl get pods -A --no-headers | grep "Running" | wc -l)
    echo "Progress: $RUNNING/$TOTAL pods running"
    
    sleep 5
done
EOF

chmod +x ~/kaapana-deployment/monitor-pods.sh

log_info "Created pod monitoring script: ~/kaapana-deployment/monitor-pods.sh"

# Wait for critical pods
log_info "Waiting for critical pods to start (timeout: 10 minutes)..."

TIMEOUT=600
ELAPSED=0
INTERVAL=10

while [ $ELAPSED -lt $TIMEOUT ]; do
    # Check if at least some pods are running
    RUNNING_PODS=$(microk8s kubectl get pods -A --no-headers 2>/dev/null | grep "Running" | wc -l)
    
    if [ $RUNNING_PODS -gt 5 ]; then
        log_success "Platform is starting up ($RUNNING_PODS pods running)"
        break
    fi
    
    echo -n "."
    sleep $INTERVAL
    ELAPSED=$((ELAPSED + INTERVAL))
done

echo ""

if [ $ELAPSED -ge $TIMEOUT ]; then
    log_warning "Timeout waiting for pods to start"
    log_info "Pods may still be starting. Check status with: microk8s kubectl get pods -A"
else
    log_success "Platform deployment initiated successfully"
fi

#############################################
# Deployment Summary
#############################################

echo ""
echo "=================================================="
echo "   Platform Deployment Complete!"
echo "=================================================="
echo ""

log_success "Kaapana platform deployed to Kubernetes"
echo ""
echo "Deployment Details:"
echo "  • Server domain/IP: $SERVER_DOMAIN"
echo "  • GPU support: $GPU_SUPPORT"
echo "  • Deployment log: ~/kaapana-logs/platform-deployment.log"
echo "  • Configuration: ~/kaapana-deployment/deployment-config.txt"
echo ""
echo "Access URLs (after pods are ready):"
echo "  • Main UI: https://$SERVER_DOMAIN/"
echo "  • Airflow: https://$SERVER_DOMAIN/flow/"
echo "  • OpenSearch: https://$SERVER_DOMAIN/opensearch-dashboards/"
echo "  • MinIO: https://$SERVER_DOMAIN/minio-console/"
echo ""
echo "Default Credentials:"
echo "  • Kaapana UI: kaapana / kaapana"
echo "  • Airflow: kaapana / kaapana"
echo "  • OpenSearch: admin / admin"
echo "  • MinIO: minio / minio123"
echo ""
echo "Monitor Deployment:"
echo "  • Check all pods: microk8s kubectl get pods -A"
echo "  • Monitor pods: ~/kaapana-deployment/monitor-pods.sh"
echo "  • Check specific namespace: microk8s kubectl get pods -n services"
echo "  • Watch pods: watch microk8s kubectl get pods -A"
echo ""
echo "Wait Time:"
echo "  • Pods may take 10-30 minutes to fully initialize"
echo "  • Images need to be pulled from registry"
echo "  • Services will start sequentially"
echo ""
echo "Next Steps:"
echo "  1. Wait for all pods to show Running status"
echo "  2. Access the UI at https://$SERVER_DOMAIN/"
echo "  3. Login with: kaapana / kaapana"
echo "  4. Follow guideline: 10-core-modules-configuration.md"
echo ""

# Create helper script for checking deployment status
cat > ~/kaapana-deployment/check-deployment.sh <<'EOF'
#!/bin/bash

echo "=== Kaapana Deployment Status ==="
echo ""

echo "Pods by namespace:"
microk8s kubectl get pods -A --no-headers | awk '{print $1}' | sort | uniq -c

echo ""
echo "Pods not in Running state:"
microk8s kubectl get pods -A --no-headers | grep -v "Running"

echo ""
echo "Helm releases:"
microk8s helm list -A

echo ""
echo "Services:"
microk8s kubectl get svc -A | grep -E "NAME|kaapana|services"

echo ""
TOTAL=$(microk8s kubectl get pods -A --no-headers | wc -l)
RUNNING=$(microk8s kubectl get pods -A --no-headers | grep "Running" | wc -l)
echo "Overall Status: $RUNNING/$TOTAL pods running"

if [ $RUNNING -eq $TOTAL ]; then
    echo "✓ All pods are running!"
else
    echo "⚠ Waiting for pods to be ready..."
fi
EOF

chmod +x ~/kaapana-deployment/check-deployment.sh

log_info "Helper script created: ~/kaapana-deployment/check-deployment.sh"
log_info "Run to check deployment status: ~/kaapana-deployment/check-deployment.sh"

echo ""
