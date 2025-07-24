#!/bin/bash
set -euo pipefail

# Deployment script for PhotoPrism on Podman
# This script handles the deployment process on the target server

DEPLOYMENT_ENV="${DEPLOYMENT_ENV:-production}"
DEPLOYMENT_HOST="${DEPLOYMENT_HOST:-london.heritageorient.com}"
DEPLOYMENT_USER="${DEPLOYMENT_USER:-deploy}"
POD_NAME="photoprism"
NAMESPACE="${NAMESPACE:-default}"

echo "Starting PhotoPrism deployment to ${DEPLOYMENT_HOST}..."
echo "Environment: ${DEPLOYMENT_ENV}"
echo "Timestamp: $(date -u +"%Y-%m-%d %H:%M:%S UTC")"

# Function to check if pod exists
pod_exists() {
    podman pod exists "$POD_NAME" 2>/dev/null
}

# Function to verify deployment
verify_deployment() {
    echo "Verifying deployment..."
    
    # Check if pod is running
    if ! podman pod ps | grep -q "$POD_NAME.*Running"; then
        echo "ERROR: Pod $POD_NAME is not running"
        return 1
    fi
    
    # Check if container is running
    if ! podman ps --filter "pod=$POD_NAME" | grep -q "photoprism"; then
        echo "ERROR: PhotoPrism container is not running"
        return 1
    fi
    
    # Get container ID for logging
    CONTAINER_ID=$(podman ps --filter "pod=$POD_NAME" --format "{{.ID}}" | head -1)
    echo "Container ID: $CONTAINER_ID"
    
    # Check HTTP endpoint
    echo "Waiting for PhotoPrism to be ready..."
    for i in {1..30}; do
        if curl -s -o /dev/null -w "%{http_code}" http://localhost:2342/api/v1/status | grep -q "200"; then
            echo "PhotoPrism is responding on http://localhost:2342"
            return 0
        fi
        echo -n "."
        sleep 2
    done
    
    echo "ERROR: PhotoPrism did not become ready within 60 seconds"
    return 1
}

# Stop and remove existing pod if it exists
if pod_exists; then
    echo "Stopping existing PhotoPrism pod..."
    podman pod stop "$POD_NAME" || true
    podman pod rm "$POD_NAME" || true
fi

# Create directories for persistent storage
echo "Creating storage directories..."
sudo mkdir -p /var/lib/photoprism/storage
sudo chown -R "$USER:$USER" /var/lib/photoprism

# Check NAS mounts
echo "Checking NAS mounts..."
if ! mountpoint -q /mnt/pearl-nas/orico; then
    echo "WARNING: Orico NAS mount not found at /mnt/pearl-nas/orico"
    echo "Run setup-nas-mounts.sh first to configure NAS access"
    exit 1
fi

if ! mountpoint -q /mnt/pearl-nas/gdrive; then
    echo "WARNING: G Drive NAS mount not found at /mnt/pearl-nas/gdrive"
    echo "Run setup-nas-mounts.sh first to configure NAS access"
    exit 1
fi

echo "NAS mounts verified:"
echo "- Orico: $(find /mnt/pearl-nas/orico -name "*.jpg" -o -name "*.JPG" 2>/dev/null | wc -l) JPG files"
echo "- G Drive: $(find /mnt/pearl-nas/gdrive -name "*.jpg" -o -name "*.JPG" 2>/dev/null | wc -l) JPG files"

# Deploy the pod
echo "Creating PhotoPrism pod from YAML..."
podman play kube deployment/podman/photoprism-pod.yaml

# Verify deployment
if verify_deployment; then
    echo "Deployment successful!"
    echo "PhotoPrism is accessible at: http://${DEPLOYMENT_HOST}:2342"
    echo "Default credentials: admin / insecure"
    echo "IMPORTANT: Change the admin password immediately after first login!"
    
    # Log deployment metadata
    echo "Deployment metadata:"
    echo "- Hostname: $(hostname)"
    echo "- Environment: ${DEPLOYMENT_ENV}"
    echo "- User: $(whoami)"
    echo "- Access: localhost:2342 (configure reverse proxy for external access)"
    echo "- Scope: Local container deployment"
    echo "- Mode: Read-only (referencing NAS files)"
    echo "- Photo sources:"
    echo "  - Orico NAS: /photoprism/originals/orico"
    echo "  - G Drive NAS: /photoprism/originals/gdrive"
    
    echo ""
    echo "Starting initial photo indexing..."
    echo "This may take several minutes depending on the number of JPG files..."
    
    # Trigger initial index
    CONTAINER_NAME=$(podman ps --filter "pod=$POD_NAME" --format "{{.Names}}" | grep photoprism | head -1)
    podman exec "$CONTAINER_NAME" photoprism index --cleanup || echo "Initial indexing will run in background"
else
    echo "Deployment verification failed!"
    echo "Checking pod logs..."
    podman pod logs "$POD_NAME" --tail=50
    exit 1
fi