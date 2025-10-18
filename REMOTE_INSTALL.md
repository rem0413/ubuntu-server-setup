# Remote Installation Guide

Hướng dẫn cài đặt Ubuntu Server Setup trực tiếp từ GitHub mà không cần clone repository.

## Quick Start - One-Line Installation

### Method 1: Using remote-install.sh (Recommended)

```bash
# Interactive installation
curl -fsSL https://raw.githubusercontent.com/USERNAME/ubuntu-server-setup/main/remote-install.sh | sudo bash

# Install all components
curl -fsSL https://raw.githubusercontent.com/USERNAME/ubuntu-server-setup/main/remote-install.sh | sudo bash -s -- --all

# Use specific profile
curl -fsSL https://raw.githubusercontent.com/USERNAME/ubuntu-server-setup/main/remote-install.sh | sudo bash -s -- --profile nodejs-app

# Dry-run mode
curl -fsSL https://raw.githubusercontent.com/USERNAME/ubuntu-server-setup/main/remote-install.sh | sudo bash -s -- --dry-run
```

### Method 2: Direct install.sh (Requires wget/curl for dependencies)

```bash
# Download and run directly
curl -fsSL https://raw.githubusercontent.com/USERNAME/ubuntu-server-setup/main/install.sh | sudo bash
```

⚠️ **Note**: Method 2 requires all dependencies (lib/, modules/) to be available, so Method 1 is recommended.

## Custom Repository/Branch

You can specify custom repository or branch:

```bash
# Custom repository
export REPO_USER="yourusername"
export REPO_NAME="your-fork"
export REPO_BRANCH="development"

curl -fsSL https://raw.githubusercontent.com/${REPO_USER}/${REPO_NAME}/${REPO_BRANCH}/remote-install.sh | sudo bash
```

## Installation Options

All install.sh options work with remote installation:

```bash
# Show help
curl -fsSL https://raw.githubusercontent.com/USERNAME/ubuntu-server-setup/main/remote-install.sh | sudo bash -s -- --help

# Show version
curl -fsSL https://raw.githubusercontent.com/USERNAME/ubuntu-server-setup/main/remote-install.sh | sudo bash -s -- --version

# Install with profile
curl -fsSL https://raw.githubusercontent.com/USERNAME/ubuntu-server-setup/main/remote-install.sh | sudo bash -s -- --profile fullstack

# Dry-run to preview
curl -fsSL https://raw.githubusercontent.com/USERNAME/ubuntu-server-setup/main/remote-install.sh | sudo bash -s -- --dry-run

# Install all components
curl -fsSL https://raw.githubusercontent.com/USERNAME/ubuntu-server-setup/main/remote-install.sh | sudo bash -s -- --all
```

## Available Profiles

```bash
# Node.js application server (Components: 1, 2, 4, 5, 7, 8)
curl -fsSL https://raw.githubusercontent.com/USERNAME/ubuntu-server-setup/main/remote-install.sh | sudo bash -s -- --profile nodejs-app

# Docker container host (Components: 1, 6, 8)
curl -fsSL https://raw.githubusercontent.com/USERNAME/ubuntu-server-setup/main/remote-install.sh | sudo bash -s -- --profile docker-host

# Full stack development (Components: 1, 2, 3, 4, 5, 6, 7, 8)
curl -fsSL https://raw.githubusercontent.com/USERNAME/ubuntu-server-setup/main/remote-install.sh | sudo bash -s -- --profile fullstack

# VPN server (Components: 1, 8, 9, 10)
curl -fsSL https://raw.githubusercontent.com/USERNAME/ubuntu-server-setup/main/remote-install.sh | sudo bash -s -- --profile vpn-server
```

## How It Works

The remote installer:

1. **Downloads** all required files from GitHub:
   - `install.sh` - Main installer
   - `lib/*.sh` - Library files (colors, utils, ui)
   - `modules/*.sh` - All 12 module files
   - `VERSION` - Version information

2. **Creates** temporary directory (`/tmp/ubuntu-server-setup-$$`)

3. **Runs** installation with provided arguments

4. **Cleans up** temporary files after completion

## Security Considerations

### Review Before Running

Always review scripts before piping to bash:

```bash
# Download and review first
curl -fsSL https://raw.githubusercontent.com/USERNAME/ubuntu-server-setup/main/remote-install.sh > remote-install.sh
cat remote-install.sh
# Review the script
sudo bash remote-install.sh
```

### Verify Repository

Make sure you're using the correct repository URL:

```bash
# Check repository exists
curl -I https://raw.githubusercontent.com/USERNAME/ubuntu-server-setup/main/remote-install.sh

# Should return: HTTP/2 200
```

### Use HTTPS

Always use HTTPS (https://raw.githubusercontent.com) to ensure encrypted download.

## Troubleshooting

### Error: Failed to download install.sh

**Cause**: Repository URL or branch name incorrect

**Solution**:
```bash
# Check repository URL
# Replace USERNAME with your GitHub username
# Replace main with your branch name if different
curl -I https://raw.githubusercontent.com/USERNAME/ubuntu-server-setup/main/install.sh
```

### Error: This script must be run as root

**Cause**: Not using sudo

**Solution**:
```bash
# Use sudo
curl -fsSL URL | sudo bash
```

### Error: Module download failed

**Cause**: Missing module file in repository

**Solution**:
```bash
# Verify all modules exist in repository
# Should have 12 modules: core, mongodb, postgresql, nodejs, pm2, docker,
#                        nginx-unified, security, openvpn, ssh-hardening,
#                        redis, monitoring
```

### Connection timeout

**Cause**: Network issues or GitHub API rate limiting

**Solution**:
```bash
# Wait a few minutes and retry
# Or clone repository locally:
git clone https://github.com/USERNAME/ubuntu-server-setup.git
cd ubuntu-server-setup
sudo ./install.sh
```

## Advanced Usage

### Save for Offline Use

Download once, use multiple times:

```bash
# Download remote installer
curl -fsSL https://raw.githubusercontent.com/USERNAME/ubuntu-server-setup/main/remote-install.sh -o remote-install.sh
chmod +x remote-install.sh

# Use later (still downloads from GitHub)
sudo ./remote-install.sh --profile nodejs-app
```

### Custom Install Directory

The installer uses `/tmp/ubuntu-server-setup-$$` by default. To change:

```bash
# Edit INSTALL_DIR in remote-install.sh after downloading
export INSTALL_DIR="/custom/path"
```

### Skip Cleanup

To keep downloaded files for inspection:

```bash
# Comment out cleanup section in remote-install.sh
# Or copy files before cleanup:
cp -r /tmp/ubuntu-server-setup-* ~/saved-install/
```

## Comparison: Remote vs Local Installation

| Feature | Remote Install | Local Install |
|---------|---------------|---------------|
| **Setup Time** | Instant | Requires git clone |
| **Disk Usage** | Temporary (auto-cleanup) | Permanent (~5MB) |
| **Network** | Required each run | Only for initial clone |
| **Customization** | Limited | Full control |
| **Updates** | Always latest | Manual git pull |
| **Offline Use** | No | Yes (after clone) |

## Best Practices

1. **Use specific branch/tag** for production:
   ```bash
   export REPO_BRANCH="v2.0.0"
   curl -fsSL https://raw.githubusercontent.com/USERNAME/ubuntu-server-setup/v2.0.0/remote-install.sh | sudo bash
   ```

2. **Test with dry-run** first:
   ```bash
   curl -fsSL URL | sudo bash -s -- --dry-run
   ```

3. **Save credentials** immediately:
   ```bash
   # After installation
   sudo cat /root/ubuntu-setup-summary.txt > ~/credentials.txt
   chmod 600 ~/credentials.txt
   ```

4. **Check logs** for errors:
   ```bash
   sudo tail -100 /var/log/ubuntu-setup.log
   ```

## Examples

### Fresh Ubuntu VPS Setup

```bash
# Update system first
sudo apt update && sudo apt upgrade -y

# Install full stack
curl -fsSL https://raw.githubusercontent.com/USERNAME/ubuntu-server-setup/main/remote-install.sh | sudo bash -s -- --profile fullstack

# Save credentials
sudo cat /root/ubuntu-setup-summary.txt
```

### Production Web Server

```bash
# Install web server stack
curl -fsSL https://raw.githubusercontent.com/USERNAME/ubuntu-server-setup/main/remote-install.sh | sudo bash -s -- --profile nodejs-app

# Configure Nginx for your domain
# Setup SSL certificates
# Deploy application
```

### VPN Server Setup

```bash
# Install VPN server
curl -fsSL https://raw.githubusercontent.com/USERNAME/ubuntu-server-setup/main/remote-install.sh | sudo bash -s -- --profile vpn-server

# Add VPN clients through menu
sudo ./install.sh
# Select: 9 (OpenVPN) → Add Client
```

## GitHub Repository Setup

To enable remote installation:

1. **Push to GitHub**:
   ```bash
   git add .
   git commit -m "Add remote installation support"
   git push origin main
   ```

2. **Update URLs** in documentation:
   - Replace `USERNAME` with your GitHub username
   - Replace `ubuntu-server-setup` with your repository name
   - Replace `main` with your branch name if different

3. **Test remote installation**:
   ```bash
   curl -fsSL https://raw.githubusercontent.com/YOUR_USERNAME/ubuntu-server-setup/main/remote-install.sh | sudo bash -s -- --dry-run
   ```

## Support

For issues with remote installation:

1. Verify repository URL is correct
2. Check GitHub repository is public
3. Ensure all files are committed and pushed
4. Test with `--dry-run` first
5. Check `/var/log/ubuntu-setup.log` for errors

**Repository**: https://github.com/USERNAME/ubuntu-server-setup
**Issues**: https://github.com/USERNAME/ubuntu-server-setup/issues
