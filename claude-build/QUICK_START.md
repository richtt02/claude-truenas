# Quick Start: Deploy Claude Code Docker Container to TrueNAS Scale

This guide walks you through deploying the Claude Code Docker container on TrueNAS Scale. The containerized Claude Code environment includes secure egress firewall, Docker Compose orchestration, and TrueNAS-specific volume mapping.

**Target Platform:** TrueNAS Scale with Docker support
**Container Base:** Debian Bookworm Slim with Node.js 25

## Prerequisites
✅ Docker installed on TrueNAS
✅ SSH access to TrueNAS
✅ TrueNAS user/group configured (see [TrueNAS Setup Guide](TRUENAS_SETUP.md))
✅ Files transferred to TrueNAS

## 4-Step Claude Code Deployment on TrueNAS

### Step 1: Transfer Files
```powershell
# From Windows PowerShell
scp -r C:\Users\Richard\Desktop\docker\* root@<truenas-ip>:/mnt/tank1/configs/claude/docker/
```

### Step 2: SSH to TrueNAS
```bash
ssh root@<truenas-ip>
cd /mnt/tank1/configs/claude/docker/
```

### Step 3: Configure Environment (REQUIRED)
```bash
chmod +x *.sh

# Copy and configure environment file (REQUIRED - no defaults)
cp .env.example .env
nano .env  # Replace ALL <"..."> placeholders with your values

# Build and start
docker compose build
docker compose up -d
```

> **Note:** The base image `richtt02/claude-base:latest` is automatically pulled from Docker Hub.
> To build it locally instead (for auditing or customization), run:
> `docker build -f Dockerfile.base -t richtt02/claude-base:latest .`

### Step 4: Verify
```bash
# Check logs
docker compose logs -f

# Test firewall (should FAIL)
docker exec claude-code curl -sf --connect-timeout 3 https://example.com

# Test firewall (should SUCCEED)
docker exec claude-code curl -sf --connect-timeout 3 https://api.github.com

# Access container
docker exec -it claude-code bash
```

## All-in-One Command

```bash
cd /mnt/tank1/configs/claude/docker/ && \
chmod +x *.sh && \
docker compose build && \
docker compose up -d && \
echo "✅ Deployment complete! Access via: docker exec -it claude-code bash"
```

## Common Docker Commands for Claude Code Container

### Container Management
```bash
docker compose up -d          # Start container
docker compose down           # Stop container
docker compose restart        # Restart container
docker compose logs -f        # View logs
docker compose build          # Rebuild derived image
```

### Base Image Management
```bash
# Pull latest from Docker Hub (default)
docker pull richtt02/claude-base:latest

# Or build locally (for auditing or customization)
docker build -f Dockerfile.base -t richtt02/claude-base:latest .
```

### Testing
```bash
# Firewall tests
docker exec claude-code curl -sf --connect-timeout 3 https://example.com      # BLOCKED
docker exec claude-code curl -sf --connect-timeout 3 https://api.github.com   # ALLOWED

# View firewall rules
docker exec claude-code iptables -L -v -n
docker exec claude-code ipset list allowed-domains

# Check user mapping
docker exec claude-code id
docker exec claude-code ls -la /workspace

# Interactive shell
docker exec -it claude-code bash
```

### Claude Code Setup
```bash
# Interactive shell
docker exec -it claude-code bash

# Inside container
claude auth login    # Login to Claude
claude               # Start Claude Code
```

## Troubleshooting Claude Code on TrueNAS Scale

### Container won't start
```bash
docker compose logs -f           # Check error logs
docker compose down              # Stop container
docker compose build --no-cache  # Rebuild
docker compose up -d             # Start again
```

### Firewall not working
```bash
# Verify capabilities in compose.yaml
grep -A 3 "cap_add" compose.yaml
# Should show: NET_ADMIN and NET_RAW

# Check firewall rules
docker exec claude-code iptables -L -v -n
```

### Permission issues
```bash
# Check container UID/GID
docker exec claude-code id

# Fix host permissions (use USER_UID/USER_GID from your .env)
chown -R 4000:4000 /mnt/tank1/configs/claude/claude-code/workspace
chown -R 4000:4000 /mnt/tank1/configs/claude/claude-code/config

# Verify .env file has correct values:
# USER_UID=4000
# USER_GID=4000
```

### Web terminal not accessible
```bash
# Check container is running
docker ps | grep claude-code

# Check container is accessible
docker exec -it claude-code bash
```

## File Structure
```
/mnt/tank1/configs/claude/docker/
├── Dockerfile.base              ← Base image definition
├── Dockerfile                   ← Derived image (scripts only)
├── entrypoint.sh                ← Container initialization
├── init-firewall.sh             ← Firewall setup
├── compose.yaml                 ← Docker Compose config
├── .env.example                 ← Environment template (copy to .env)
├── build-base.sh                ← Base image build helper
├── CLAUDE.md                    ← Full documentation
├── IMPLEMENTATION_SUMMARY.md    ← Deployment guide
├── TRANSFER_GUIDE.md            ← Transfer instructions
├── CHANGELOG.md                 ← Version history
└── QUICK_START.md               ← This file

/mnt/tank1/configs/claude/claude-code/
├── workspace/                   ← Your projects (mounted to /workspace)
└── config/                      ← Claude config (mounted to /claude)
```

## Success Indicators

✅ Container running: `docker ps | grep claude-code`
✅ Shell access: `docker exec -it claude-code bash` works
✅ Firewall blocking: `curl https://example.com` fails
✅ Firewall allowing: `curl https://api.github.com` succeeds
✅ Claude CLI: `claude --version` shows version

## What's Different from Alpine Version?

| Aspect | Old (Alpine) | New (Debian Slim) |
|--------|-------------|-------------------|
| Base Image | nezhar/claude-container | richtt02/claude-base |
| OS | Alpine Linux | Debian 12 Bookworm Slim |
| Size | ~90MB | ~930MB |
| Build Steps | 1 (compose build) | 1 (compose build, base auto-pulled) |
| Compatibility | Limited | Full Node.js compatibility |

## Need More Help?

📖 **Full Documentation:** See `CLAUDE.md`
🚀 **Deployment Guide:** See `IMPLEMENTATION_SUMMARY.md`
📦 **Transfer Guide:** See `TRANSFER_GUIDE.md`
📝 **Version History:** See `CHANGELOG.md`

## Building Base Image Locally (Optional)

The base image is automatically pulled from Docker Hub. Build locally only if you want to:
- Audit the image contents
- Customize the base image
- Contribute changes

```bash
# Build base image locally
docker build -f Dockerfile.base -t richtt02/claude-base:latest .

# Then rebuild derived image
docker compose build --no-cache
docker compose up -d
```

## Maintenance

### Update Base Image
```bash
# Edit Dockerfile.base as needed
docker build -f Dockerfile.base -t richtt02/claude-base:latest .
docker push richtt02/claude-base:latest  # If using Docker Hub
docker compose build --no-cache
docker compose restart
```

### Update Scripts Only
```bash
# Edit entrypoint.sh or init-firewall.sh
docker compose build
docker compose restart
```

### Update Whitelisted Domains
```bash
# Edit init-firewall.sh (lines 107-114)
# Add domains to ALLOWED_DOMAINS list
docker compose build
docker compose restart
```

---

**Ready to deploy!** Follow Step 1-4 above to get started.
