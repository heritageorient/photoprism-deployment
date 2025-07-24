# PhotoPrism Deployment Setup Guide

## Repository Issue Resolution

The heritageorient/PhotoPrism repository appears to have conflicts with the upstream. Here's how to resolve:

### Option 1: Use Deployment Files Directly

1. Copy the deployment directory to your server
2. Run the deployment scripts manually

### Option 2: Create New Repository

```bash
# Create new repository on GitHub
gh repo create heritageorient/photoprism-deployment --private

# Initialize with deployment files
git init
git add deployment/ .github/
git commit -m "Initial deployment configuration"
git remote add origin git@github.com:heritageorient/photoprism-deployment.git
git push -u origin main
```

## GitHub Secrets Configuration

### 1. Generate SSH Key for Deployment

```bash
# On your local machine
ssh-keygen -t ed25519 -f ~/.ssh/london_deploy -C "deploy@london.heritageorient.com" -N ""

# Display the private key (for GitHub secret)
cat ~/.ssh/london_deploy

# Display the public key (for server)
cat ~/.ssh/london_deploy.pub
```

### 2. Add Public Key to London Server

```bash
# SSH to London server
ssh user@london.heritageorient.com

# Create deploy user if not exists
sudo useradd -m -s /bin/bash deploy
sudo usermod -aG docker deploy

# Add SSH key
sudo su - deploy
mkdir -p ~/.ssh
echo "YOUR_PUBLIC_KEY_HERE" >> ~/.ssh/authorized_keys
chmod 700 ~/.ssh
chmod 600 ~/.ssh/authorized_keys
```

### 3. Get Server SSH Fingerprint

```bash
# From your local machine
ssh-keyscan -H london.heritageorient.com > london_known_hosts.txt
cat london_known_hosts.txt
```

### 4. Add GitHub Secrets

Go to your repository settings → Secrets and variables → Actions

Add these secrets:

1. **LONDON_SERVER_SSH_KEY**
   - Value: Contents of `~/.ssh/london_deploy` (private key)
   
2. **LONDON_SERVER_KNOWN_HOSTS**
   - Value: Contents of `london_known_hosts.txt`

## Server Setup Instructions

### 1. Connect to London Server

```bash
ssh user@london.heritageorient.com
```

### 2. Install Prerequisites

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install Podman
sudo apt install -y podman podman-compose

# Install Nginx
sudo apt install -y nginx certbot python3-certbot-nginx

# Enable user namespaces for rootless Podman
sudo sysctl -w kernel.unprivileged_userns_clone=1
echo "kernel.unprivileged_userns_clone=1" | sudo tee /etc/sysctl.d/userns.conf
```

### 3. Setup Pearl NAS Mounts

```bash
# Configure Pearl NAS details
export PEARL_NAS_IP="192.168.100.212"  # Pearl NAS at pearl.lan

# Run NAS mount setup script
sudo bash deployment/scripts/setup-nas-mounts.sh

# Verify mounts
df -h | grep pearl-nas
```

### 4. Create Required Directories

```bash
# Create PhotoPrism storage directory (photos remain on NAS)
sudo mkdir -p /var/lib/photoprism/storage
sudo chown -R deploy:deploy /var/lib/photoprism

# Create deployment directory
sudo mkdir -p /home/deploy/photoprism-deployment
sudo chown -R deploy:deploy /home/deploy/photoprism-deployment
```

### 5. Configure SSL Certificate

```bash
# Obtain SSL certificate
sudo certbot certonly --nginx \
  -d photos.heritageorient.com \
  --agree-tos \
  --email admin@heritageorient.com
```

### 6. Configure Nginx

```bash
# Copy nginx configuration
sudo cp deployment/config/nginx-proxy.conf /etc/nginx/sites-available/photoprism
sudo ln -sf /etc/nginx/sites-available/photoprism /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

### 7. Setup Systemd Service

Create `/etc/systemd/system/photoprism.service`:

```bash
sudo tee /etc/systemd/system/photoprism.service << 'EOF'
[Unit]
Description=PhotoPrism Container
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=deploy
Group=deploy
WorkingDirectory=/home/deploy/photoprism-deployment
ExecStart=/usr/bin/podman play kube podman/photoprism-pod.yaml
ExecStop=/usr/bin/podman pod stop photoprism
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable photoprism
```

## Manual Deployment Test

```bash
# As deploy user
sudo su - deploy
cd /home/deploy/photoprism-deployment

# Copy deployment files manually
# Then run deployment
bash scripts/deploy.sh
```

## Verification

```bash
# Check pod status
podman pod ps

# Check service
systemctl status photoprism

# Test web access
curl -I http://localhost:2342

# Check logs
podman logs photoprism
```

## Troubleshooting

### Port Already in Use
```bash
sudo lsof -i :2342
# Kill process if needed
```

### Podman Permission Issues
```bash
# Check subuid/subgid
grep deploy /etc/subuid /etc/subgid

# If missing, add:
sudo usermod --add-subuids 100000-165535 deploy
sudo usermod --add-subgids 100000-165535 deploy
```

### Storage Permission Issues
```bash
sudo chown -R deploy:deploy /var/lib/photoprism
chmod -R 755 /var/lib/photoprism
```

## Next Steps

1. Complete server setup following the instructions above
2. Configure GitHub secrets
3. Test manual deployment first
4. Then use GitHub Actions for automated deployment

## Pearl NAS Configuration

### NAS Mount Requirements

- **Pearl NAS IP**: 192.168.100.212 (pearl.lan)
- **Orico Share**: Path to Orico storage on NAS (verify actual path)
- **G Drive Share**: Path to G Drive storage on NAS (verify actual path)
- **Protocol**: NFS (recommended) or SMB/CIFS
- **Access**: Read-only mounts to protect original files

### Pearl NAS Preparation

1. **SSH Access** (optional for management):
   ```bash
   # Add public key to Pearl NAS
   ssh-copy-id -i ~/.ssh/claude_pearl_ed25519.pub claude@192.168.100.212
   ```

2. **NFS Configuration** on Pearl:
   ```bash
   # Add to /etc/exports on Pearl
   /volume1/orico 192.168.100.0/24(ro,sync,no_subtree_check,no_root_squash)
   /volume1/gdrive 192.168.100.0/24(ro,sync,no_subtree_check,no_root_squash)
   ```

3. **Verify Shares** from London server:
   ```bash
   showmount -e 192.168.100.212
   ```

### PhotoPrism NAS Features

- **Read-Only Mode**: PhotoPrism will not modify original JPG files
- **Direct Reference**: Photos remain on Pearl NAS, not copied to London server
- **JPG Only**: Configured to index only JPG/JPEG files
- **Auto-Indexing**: Scheduled daily scan for new photos
- **Mount Points**:
  - Orico: `/mnt/pearl-nas/orico` → `/photoprism/originals/orico`
  - G Drive: `/mnt/pearl-nas/gdrive` → `/photoprism/originals/gdrive`

## Security Notes

- Change default PhotoPrism admin password immediately
- Ensure firewall allows only necessary ports (80, 443, 22)
- NAS mounts are read-only to protect original files
- Regular backups of `/var/lib/photoprism/storage` (metadata only)
- Monitor London server disk space (only stores thumbnails/cache)