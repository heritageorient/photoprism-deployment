# PhotoPrism Deployment Checklist

## Pre-Deployment Checklist

### Pearl NAS (192.168.100.212)
- [ ] NFS or SMB shares configured
- [ ] Orico share path verified
- [ ] G Drive share path verified
- [ ] Read permissions set for London server
- [ ] Firewall allows NFS/SMB from London server

### London Server
- [ ] SSH access available
- [ ] Domain photos.heritageorient.com points to server
- [ ] Ports 80 and 443 open in firewall
- [ ] Sufficient disk space for thumbnails/cache (10-20GB recommended)

### GitHub Repository
- [ ] Repository accessible: heritageorient/PhotoPrism
- [ ] Deployment files committed
- [ ] GitHub Actions enabled

## Deployment Files Created

### Configuration Files
- ✅ `.github/workflows/deploy.yml` - CI/CD pipeline
- ✅ `deployment/podman/photoprism-pod.yaml` - Container configuration
- ✅ `deployment/config/nginx-proxy.conf` - Reverse proxy
- ✅ `deployment/config/london.env` - Environment variables
- ✅ `deployment/config/photoprism-nas.yml` - PhotoPrism settings

### Scripts
- ✅ `deployment/scripts/deploy.sh` - Main deployment script
- ✅ `deployment/scripts/setup-london-server.sh` - Server setup
- ✅ `deployment/scripts/setup-nas-mounts.sh` - NAS mount configuration
- ✅ `deployment/scripts/setup-pearl-access.sh` - Pearl access guide
- ✅ `quick-deploy.sh` - One-command deployment

### Documentation
- ✅ `README.md` - Project overview
- ✅ `DEPLOYMENT_SETUP.md` - Detailed setup guide
- ✅ `DEPLOYMENT_SUMMARY.md` - Quick reference
- ✅ `DEPLOYMENT_CHECKLIST.md` - This checklist

## Deployment Steps

### Option 1: Quick Deploy (Recommended)
```bash
# On London server
git clone https://github.com/heritageorient/PhotoPrism.git
cd PhotoPrism
bash quick-deploy.sh
```

### Option 2: Manual Deploy
1. Setup NAS mounts
2. Install prerequisites
3. Configure nginx
4. Deploy PhotoPrism
5. Setup systemd service

## Post-Deployment Checklist

### Immediate Actions
- [ ] Change admin password (default: changeme123!)
- [ ] Verify NAS mounts are working
- [ ] Check PhotoPrism is indexing photos
- [ ] Test HTTPS access

### Verification Commands
```bash
# Check service
systemctl status photoprism

# Check mounts
df -h | grep pearl-nas

# Check container
podman pod ps

# Check logs
podman logs photoprism

# Check photo count
podman exec photoprism photoprism show stats
```

### GitHub Secrets (for CI/CD)
- [ ] Add `LONDON_SERVER_SSH_KEY`
- [ ] Add `LONDON_SERVER_KNOWN_HOSTS`

## Troubleshooting Quick Reference

| Issue | Solution |
|-------|----------|
| NAS mount failed | Check Pearl NAS exports, verify IP connectivity |
| PhotoPrism won't start | Check logs: `podman pod logs photoprism` |
| Photos not showing | Verify mount paths, run manual index |
| SSL certificate failed | Run certbot manually, check domain DNS |
| Permission denied | Check deploy user permissions, NAS access rights |

## Success Criteria

- [ ] PhotoPrism accessible at https://photos.heritageorient.com
- [ ] Can browse Orico photos
- [ ] Can browse G Drive photos
- [ ] Search functionality working
- [ ] Thumbnails generating properly
- [ ] No errors in logs