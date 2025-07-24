#!/bin/bash
# Quick deployment script for PhotoPrism with Pearl NAS
# Run this on London server after cloning the repository

set -euo pipefail

echo "PhotoPrism Quick Deployment for Heritage Orient"
echo "=============================================="
echo ""
echo "This script will:"
echo "1. Setup Pearl NAS mounts (192.168.100.212)"
echo "2. Install and configure PhotoPrism"
echo "3. Setup HTTPS with photos.heritageorient.com"
echo ""
read -p "Continue? [y/N] " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 1
fi

# Check if running as root when needed
if [[ $EUID -eq 0 ]]; then
   echo "Please run this script as a regular user, not root"
   exit 1
fi

# Set Pearl NAS IP
export PEARL_NAS_IP="192.168.100.212"

echo ""
echo "Step 1: Installing prerequisites..."
sudo apt-get update
sudo apt-get install -y podman podman-compose nginx certbot python3-certbot-nginx nfs-common cifs-utils

echo ""
echo "Step 2: Setting up Pearl NAS mounts..."
if [ -f "deployment/scripts/setup-nas-mounts.sh" ]; then
    sudo bash deployment/scripts/setup-nas-mounts.sh
else
    echo "ERROR: setup-nas-mounts.sh not found. Are you in the PhotoPrism directory?"
    exit 1
fi

echo ""
echo "Step 3: Creating deploy user..."
if ! id "deploy" &>/dev/null; then
    sudo useradd -m -s /bin/bash deploy
    sudo usermod -aG sudo deploy
fi

echo ""
echo "Step 4: Setting up directories..."
sudo mkdir -p /var/lib/photoprism/storage
sudo mkdir -p /home/deploy/photoprism-deployment
sudo chown -R deploy:deploy /var/lib/photoprism
sudo chown -R deploy:deploy /home/deploy/photoprism-deployment

echo ""
echo "Step 5: Copying deployment files..."
sudo cp -r deployment/* /home/deploy/photoprism-deployment/
sudo chown -R deploy:deploy /home/deploy/photoprism-deployment/

echo ""
echo "Step 6: Configuring SSL certificate..."
echo "Setting up SSL for photos.heritageorient.com"
sudo certbot certonly --nginx \
    -d photos.heritageorient.com \
    --non-interactive \
    --agree-tos \
    --email admin@heritageorient.com \
    --redirect || echo "SSL setup failed - continuing anyway"

echo ""
echo "Step 7: Configuring Nginx..."
if [ -f "deployment/config/nginx-proxy.conf" ]; then
    sudo cp deployment/config/nginx-proxy.conf /etc/nginx/sites-available/photoprism
    sudo ln -sf /etc/nginx/sites-available/photoprism /etc/nginx/sites-enabled/
    sudo nginx -t && sudo systemctl reload nginx
fi

echo ""
echo "Step 8: Setting up systemd service..."
sudo tee /etc/systemd/system/photoprism.service > /dev/null << 'EOF'
[Unit]
Description=PhotoPrism Podman Container
After=network-online.target mnt-pearl\\x2dnas-orico.mount mnt-pearl\\x2dnas-gdrive.mount
Wants=network-online.target

[Service]
Type=simple
User=deploy
Group=deploy
WorkingDirectory=/home/deploy/photoprism-deployment
ExecStartPre=/usr/bin/podman pod exists photoprism || /usr/bin/podman play kube podman/photoprism-pod.yaml
ExecStart=/usr/bin/podman pod start photoprism
ExecStop=/usr/bin/podman pod stop photoprism
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable photoprism

echo ""
echo "Step 9: Deploying PhotoPrism..."
cd /home/deploy/photoprism-deployment
sudo -u deploy bash scripts/deploy.sh

echo ""
echo "Step 10: Starting PhotoPrism service..."
sudo systemctl start photoprism

echo ""
echo "=================================="
echo "Deployment Complete!"
echo "=================================="
echo ""
echo "PhotoPrism is now running at:"
echo "  https://photos.heritageorient.com"
echo ""
echo "Default credentials:"
echo "  Username: admin"
echo "  Password: (configured securely)"
echo ""
echo "Admin password has been securely configured"
echo ""
echo "Useful commands:"
echo "  sudo systemctl status photoprism    # Check service status"
echo "  sudo journalctl -u photoprism -f    # View logs"
echo "  podman pod ps                       # Check pod status"
echo ""
echo "NAS Mounts:"
df -h | grep pearl-nas || echo "  No NAS mounts found - check setup-nas-mounts.sh"