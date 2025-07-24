#!/bin/bash
# Setup script for London server - run this once to prepare the server

set -euo pipefail

echo "Setting up London server for PhotoPrism deployment..."

# Install required packages
echo "Installing required packages..."
sudo apt-get update
sudo apt-get install -y \
    podman \
    podman-compose \
    nginx \
    certbot \
    python3-certbot-nginx \
    curl \
    jq

# Create deployment user if not exists
if ! id "deploy" &>/dev/null; then
    echo "Creating deployment user..."
    sudo useradd -m -s /bin/bash deploy
    sudo usermod -aG sudo deploy
fi

# Create directories
echo "Creating required directories..."
sudo mkdir -p /var/lib/photoprism/{storage,originals,import}
sudo mkdir -p /home/deploy/photoprism-deployment/{scripts,podman,config}
sudo chown -R deploy:deploy /var/lib/photoprism
sudo chown -R deploy:deploy /home/deploy/photoprism-deployment

# Configure podman for rootless operation
echo "Configuring podman..."
sudo loginctl enable-linger deploy
sudo sysctl -w net.ipv4.ip_unprivileged_port_start=80

# Setup SSL certificate
echo "Setting up SSL certificate..."
sudo certbot certonly --nginx -d photos.heritageorient.com \
    --non-interactive \
    --agree-tos \
    --email admin@heritageorient.com \
    --redirect

# Configure nginx
echo "Configuring nginx..."
sudo cp deployment/config/nginx-proxy.conf /etc/nginx/sites-available/photoprism
sudo ln -sf /etc/nginx/sites-available/photoprism /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx

# Create systemd service for PhotoPrism
echo "Creating systemd service..."
cat << 'EOF' | sudo tee /etc/systemd/system/photoprism.service
[Unit]
Description=PhotoPrism Podman Container
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=deploy
Group=deploy
Environment="PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
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

echo "London server setup completed!"
echo ""
echo "Next steps:"
echo "1. Add SSH key for deployment user: ssh-copy-id deploy@london.heritageorient.com"
echo "2. Configure GitHub secrets:"
echo "   - LONDON_SERVER_SSH_KEY: Private SSH key for deployment"
echo "   - LONDON_SERVER_KNOWN_HOSTS: SSH known_hosts entry"
echo "3. Push code to trigger deployment"