# PhotoPrism Deployment for Heritage Orient

This repository contains the deployment configuration for PhotoPrism with Pearl NAS integration.

## Quick Start

```bash
# On London server
git clone https://github.com/heritageorient/photoprism-deployment.git
cd photoprism-deployment
bash quick-deploy.sh
```

## Architecture

- **PhotoPrism**: Self-hosted photo management
- **Pearl NAS**: 192.168.100.212 - Photo storage (Orico & G Drive)
- **London Server**: Hosts PhotoPrism container
- **Access**: https://photos.heritageorient.com

## Key Features

- ✅ Read-only access to Pearl NAS photos
- ✅ No file uploads - references photos directly
- ✅ JPG-only indexing
- ✅ Automated daily indexing
- ✅ HTTPS with Let's Encrypt
- ✅ Podman containerization
- ✅ GitHub Actions CI/CD

## Documentation

- [Deployment Summary](DEPLOYMENT_SUMMARY.md) - Quick reference
- [Deployment Setup](DEPLOYMENT_SETUP.md) - Detailed instructions
- [Deployment Checklist](DEPLOYMENT_CHECKLIST.md) - Pre/post deployment verification

## Support

For issues, please create a GitHub issue in this repository.