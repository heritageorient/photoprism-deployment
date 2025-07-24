# PhotoPrism Deployment Summary

## Quick Start

This deployment configures PhotoPrism on London server to display JPG photos stored on Pearl NAS (192.168.100.212).

### Prerequisites Checklist

- [ ] London server accessible via SSH
- [ ] Pearl NAS (192.168.100.212) with Orico and G Drive shares
- [ ] NFS or SMB configured on Pearl NAS
- [ ] Domain: photos.heritageorient.com pointing to London server
- [ ] GitHub repository: heritageorient/PhotoPrism

### Deployment Steps

#### 1. On Pearl NAS (192.168.100.212)

Configure NFS exports or SMB shares for:
- Orico storage
- G Drive storage

#### 2. On London Server

```bash
# Clone deployment repository
git clone https://github.com/heritageorient/PhotoPrism.git
cd PhotoPrism

# Setup NAS mounts
sudo bash deployment/scripts/setup-nas-mounts.sh

# Run one-time server setup
sudo bash deployment/scripts/setup-london-server.sh

# Deploy PhotoPrism
bash deployment/scripts/deploy.sh
```

#### 3. Configure GitHub Secrets

Add to repository settings:
- `LONDON_SERVER_SSH_KEY`: SSH private key
- `LONDON_SERVER_KNOWN_HOSTS`: SSH fingerprint

### Architecture

```
Pearl NAS (192.168.100.212)          London Server
┌─────────────────────────┐         ┌─────────────────────────┐
│  Orico Storage (JPGs)   │ ──NFS──▶│  PhotoPrism Container   │
│  G Drive Storage (JPGs) │ ──NFS──▶│  - Read-only access     │
└─────────────────────────┘         │  - Indexes JPGs         │
                                    │  - Stores metadata      │
                                    │  - Generates thumbnails │
                                    └─────────────────────────┘
                                              │
                                              ▼
                                    https://photos.heritageorient.com
```

### Key Features

- **No Upload Required**: Photos stay on Pearl NAS
- **Read-Only**: Original files are never modified
- **JPG Only**: Optimized for JPG/JPEG files only
- **Auto-Index**: Daily scan for new photos at 3 AM
- **Secure**: HTTPS via Let's Encrypt, read-only mounts

### File Locations

**On Pearl NAS:**
- `/volume1/orico` (or actual path) - Orico photos
- `/volume1/gdrive` (or actual path) - G Drive photos

**On London Server:**
- `/mnt/pearl-nas/orico` - Mounted Orico share
- `/mnt/pearl-nas/gdrive` - Mounted G Drive share
- `/var/lib/photoprism/storage` - PhotoPrism metadata/cache

**In PhotoPrism:**
- `/photoprism/originals/orico` - Orico photos
- `/photoprism/originals/gdrive` - G Drive photos

### Default Credentials

- URL: https://photos.heritageorient.com
- Username: `admin`
- Password: `changeme123!` (CHANGE IMMEDIATELY)

### Maintenance

**Check Status:**
```bash
podman pod ps
systemctl status photoprism
```

**View Logs:**
```bash
podman logs photoprism
journalctl -u photoprism
```

**Manual Re-index:**
```bash
podman exec photoprism photoprism index --cleanup
```

**Update PhotoPrism:**
1. Update image tag in `deployment/podman/photoprism-pod.yaml`
2. Push to GitHub to trigger deployment

### Troubleshooting

**NAS Mount Issues:**
```bash
# Check mounts
df -h | grep pearl-nas
mount | grep pearl-nas

# Test NFS
showmount -e 192.168.100.212

# Remount
sudo mount -a
```

**PhotoPrism Not Starting:**
```bash
# Check pod logs
podman pod logs photoprism

# Restart pod
podman pod restart photoprism
```

**Photos Not Showing:**
```bash
# Check file access
ls -la /mnt/pearl-nas/orico/*.jpg | head
ls -la /mnt/pearl-nas/gdrive/*.jpg | head

# Force re-index
podman exec photoprism photoprism index --force
```

### Support

- PhotoPrism Docs: https://docs.photoprism.app
- GitHub Issues: https://github.com/heritageorient/PhotoPrism/issues