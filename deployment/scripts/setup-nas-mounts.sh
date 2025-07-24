#!/bin/bash
# Setup NAS mounts for PhotoPrism to reference JPG files from Pearl NAS
# This script configures NFS/SMB mounts for Orico and G Drive storage

set -euo pipefail

echo "Setting up NAS mounts for PhotoPrism..."
echo "This will mount Pearl NAS directories for read-only access"

# NAS Configuration
PEARL_NAS_IP="${PEARL_NAS_IP:-192.168.100.212}"  # Pearl NAS at pearl.lan
ORICO_SHARE="${ORICO_SHARE:-/volume1/orico}"   # Update with actual Orico share path
GDRIVE_SHARE="${GDRIVE_SHARE:-/volume1/gdrive}" # Update with actual G Drive share path

# Mount points on London server
MOUNT_BASE="/mnt/pearl-nas"
ORICO_MOUNT="$MOUNT_BASE/orico"
GDRIVE_MOUNT="$MOUNT_BASE/gdrive"

# Install required packages
echo "Installing NFS/SMB utilities..."
sudo apt-get update
sudo apt-get install -y nfs-common cifs-utils

# Create mount directories
echo "Creating mount directories..."
sudo mkdir -p "$ORICO_MOUNT"
sudo mkdir -p "$GDRIVE_MOUNT"

# Function to setup NFS mounts
setup_nfs_mounts() {
    echo "Setting up NFS mounts..."
    
    # Add to /etc/fstab for persistent mounts
    echo "Adding NFS mounts to /etc/fstab..."
    
    # Check if entries already exist
    if ! grep -q "$ORICO_MOUNT" /etc/fstab; then
        echo "$PEARL_NAS_IP:$ORICO_SHARE $ORICO_MOUNT nfs defaults,ro,noatime,nolock,nfsvers=4 0 0" | sudo tee -a /etc/fstab
    fi
    
    if ! grep -q "$GDRIVE_MOUNT" /etc/fstab; then
        echo "$PEARL_NAS_IP:$GDRIVE_SHARE $GDRIVE_MOUNT nfs defaults,ro,noatime,nolock,nfsvers=4 0 0" | sudo tee -a /etc/fstab
    fi
    
    # Mount the shares
    echo "Mounting NFS shares..."
    sudo mount "$ORICO_MOUNT" || echo "Failed to mount Orico share"
    sudo mount "$GDRIVE_MOUNT" || echo "Failed to mount G Drive share"
}

# Function to setup SMB/CIFS mounts (alternative to NFS)
setup_smb_mounts() {
    echo "Setting up SMB/CIFS mounts..."
    
    # Create credentials file
    CREDS_FILE="/etc/samba/pearl-nas.creds"
    sudo mkdir -p /etc/samba
    
    echo "Please enter Pearl NAS credentials:"
    read -p "Username: " SMB_USER
    read -s -p "Password: " SMB_PASS
    echo
    
    # Create secure credentials file
    sudo bash -c "cat > $CREDS_FILE" << EOF
username=$SMB_USER
password=$SMB_PASS
domain=WORKGROUP
EOF
    
    sudo chmod 600 "$CREDS_FILE"
    
    # Add to /etc/fstab
    if ! grep -q "$ORICO_MOUNT" /etc/fstab; then
        echo "//$PEARL_NAS_IP/orico $ORICO_MOUNT cifs credentials=$CREDS_FILE,ro,uid=deploy,gid=deploy,iocharset=utf8,file_mode=0444,dir_mode=0555 0 0" | sudo tee -a /etc/fstab
    fi
    
    if ! grep -q "$GDRIVE_MOUNT" /etc/fstab; then
        echo "//$PEARL_NAS_IP/gdrive $GDRIVE_MOUNT cifs credentials=$CREDS_FILE,ro,uid=deploy,gid=deploy,iocharset=utf8,file_mode=0444,dir_mode=0555 0 0" | sudo tee -a /etc/fstab
    fi
    
    # Mount the shares
    echo "Mounting SMB shares..."
    sudo mount "$ORICO_MOUNT" || echo "Failed to mount Orico share"
    sudo mount "$GDRIVE_MOUNT" || echo "Failed to mount G Drive share"
}

# Main setup
echo "Select mount type:"
echo "1) NFS (recommended for Linux NAS)"
echo "2) SMB/CIFS (for Windows shares or if NFS unavailable)"
read -p "Enter choice [1-2]: " MOUNT_TYPE

case $MOUNT_TYPE in
    1)
        setup_nfs_mounts
        ;;
    2)
        setup_smb_mounts
        ;;
    *)
        echo "Invalid choice. Exiting."
        exit 1
        ;;
esac

# Test mounts
echo "Testing mounts..."
if mountpoint -q "$ORICO_MOUNT"; then
    echo "✓ Orico mount successful"
    echo "  Files found: $(find "$ORICO_MOUNT" -name "*.jpg" -o -name "*.JPG" 2>/dev/null | head -5 | wc -l) JPGs"
else
    echo "✗ Orico mount failed"
fi

if mountpoint -q "$GDRIVE_MOUNT"; then
    echo "✓ G Drive mount successful"
    echo "  Files found: $(find "$GDRIVE_MOUNT" -name "*.jpg" -o -name "*.JPG" 2>/dev/null | head -5 | wc -l) JPGs"
else
    echo "✗ G Drive mount failed"
fi

# Set permissions for deploy user
echo "Setting permissions..."
sudo chown -R deploy:deploy "$MOUNT_BASE" 2>/dev/null || true

# Create systemd mount units for automatic mounting
echo "Creating systemd mount units..."

# Orico mount unit
sudo tee /etc/systemd/system/mnt-pearl\\x2dnas-orico.mount > /dev/null << EOF
[Unit]
Description=Pearl NAS Orico Mount
After=network-online.target
Wants=network-online.target

[Mount]
What=$PEARL_NAS_IP:$ORICO_SHARE
Where=$ORICO_MOUNT
Type=nfs
Options=defaults,ro,noatime,nolock,nfsvers=4

[Install]
WantedBy=multi-user.target
EOF

# G Drive mount unit
sudo tee /etc/systemd/system/mnt-pearl\\x2dnas-gdrive.mount > /dev/null << EOF
[Unit]
Description=Pearl NAS G Drive Mount
After=network-online.target
Wants=network-online.target

[Mount]
What=$PEARL_NAS_IP:$GDRIVE_SHARE
Where=$GDRIVE_MOUNT
Type=nfs
Options=defaults,ro,noatime,nolock,nfsvers=4

[Install]
WantedBy=multi-user.target
EOF

# Enable and start mount units
sudo systemctl daemon-reload
sudo systemctl enable mnt-pearl\\x2dnas-orico.mount
sudo systemctl enable mnt-pearl\\x2dnas-gdrive.mount

echo ""
echo "NAS mount setup complete!"
echo ""
echo "Mount points:"
echo "  Orico: $ORICO_MOUNT"
echo "  G Drive: $GDRIVE_MOUNT"
echo ""
echo "PhotoPrism will access these as:"
echo "  /photoprism/originals/orico"
echo "  /photoprism/originals/gdrive"
echo ""
echo "Note: PhotoPrism is configured in read-only mode."
echo "It will index and display JPGs without modifying the original files."