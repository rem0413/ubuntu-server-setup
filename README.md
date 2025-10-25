# Ubuntu Server Setup Automation

Automated setup script for Ubuntu 24.04 LTS servers with simple terminal interface. Quickly provision VPS instances with development tools, databases, and services.

## Quick Start

### 🚀 One-Line Installation

**Install everything:**
```bash
curl -fsSL https://raw.githubusercontent.com/rem0413/ubuntu-server-setup/master/remote-install.sh | sudo bash -s -- --all
```

**Install with profile:**
```bash
# Node.js application stack
curl -fsSL https://raw.githubusercontent.com/rem0413/ubuntu-server-setup/master/remote-install.sh | sudo bash -s -- --profile nodejs-app

# Docker host
curl -fsSL https://raw.githubusercontent.com/rem0413/ubuntu-server-setup/master/remote-install.sh | sudo bash -s -- --profile docker-host

# Full stack development
curl -fsSL https://raw.githubusercontent.com/rem0413/ubuntu-server-setup/master/remote-install.sh | sudo bash -s -- --profile fullstack

# VPN server
curl -fsSL https://raw.githubusercontent.com/rem0413/ubuntu-server-setup/master/remote-install.sh | sudo bash -s -- --profile vpn-server
```

**Custom components:**
```bash
# Install specific components (1=system, 4=nodejs, 7=nginx)
curl -fsSL https://raw.githubusercontent.com/rem0413/ubuntu-server-setup/master/remote-install.sh | sudo bash -s -- --components 1 4 7
```

### ⭐ Global Installation (Recommended)

Install as a system command for repeated use:

```bash
curl -fsSL https://raw.githubusercontent.com/rem0413/ubuntu-server-setup/master/install-global.sh | sudo bash
```

Then use anywhere:
```bash
ubuntu-setup install --all
ubuntu-setup install --profile nodejs-app
ubuntu-setup update
ubuntu-setup help
```

### 📦 Manual Installation

```bash
git clone https://github.com/rem0413/ubuntu-server-setup.git
cd ubuntu-server-setup
sudo ./install.sh
```

## Available Components

| # | Component | Description |
|---|-----------|-------------|
| 1 | System Tools | Build essentials, git, curl, wget, vim, htop |
| 2 | MongoDB | NoSQL database with authentication (v7.0) |
| 3 | PostgreSQL | Relational database with authentication (v16.x) |
| 4 | Node.js | JavaScript runtime (18.x/20.x LTS/21.x) |
| 5 | PM2 | Process manager for Node.js applications |
| 6 | Docker | Container platform + Docker Compose |
| 7 | Nginx | Web server + Cloudflare Real IP support |
| 8 | Security | UFW firewall + Fail2ban |
| 9 | OpenVPN | VPN server with client management |
| 10 | SSH Hardening | SSH security + key-based auth setup |
| 11 | Redis | Cache server (standalone/cluster mode) |
| 12 | Monitoring | Prometheus, Grafana, Node Exporter |

## Installation Profiles

Pre-configured profiles for common use cases:

| Profile | Components Installed |
|---------|---------------------|
| **nodejs-app** | System Tools, Node.js, PM2, Nginx, Security |
| **docker-host** | System Tools, Docker, Nginx, Security |
| **fullstack** | System Tools, MongoDB, PostgreSQL, Node.js, PM2, Redis, Docker, Nginx, Security |
| **vpn-server** | System Tools, OpenVPN, Security |
| **database** | System Tools, MongoDB, PostgreSQL, Redis, Security |

## Features

- ✅ **Simple Terminal UI** - Easy-to-use menu interface
- ✅ **Non-Interactive Mode** - Perfect for automation and CI/CD
- ✅ **Secure by Default** - Random passwords, SSH hardening, firewall
- ✅ **Idempotent** - Safe to re-run without conflicts
- ✅ **Auto-Logging** - All operations logged to `/var/log/ubuntu-setup.log`
- ✅ **Config Backup** - Automatic backup before modifying files
- ✅ **Credential Storage** - Installation summary at `/root/ubuntu-setup-summary.txt`

## Usage Examples

### Interactive Menu

```bash
sudo ./install.sh
```

Shows menu, select components by number:
```
========================================
Ubuntu Server Setup - Select Components
========================================

Core:
  1. System Update & Essential Tools (Recommended)
  2. MongoDB Database
  3. PostgreSQL Database
  ...

Enter numbers separated by spaces (e.g., 1 4 7 8):
> 1 4 7 8
```

### Non-Interactive Mode

```bash
# Install everything
sudo ./install.sh --all

# Install with profile
sudo ./install.sh --profile nodejs-app

# Install specific components
sudo ./install.sh --components 1 2 4 5 7 8

# Dry run (preview only)
sudo ./install.sh --all --dry-run
```

### Global Command

```bash
# After global installation
ubuntu-setup install --all
ubuntu-setup install --profile fullstack
ubuntu-setup install --components 1 4 7
ubuntu-setup update
```

## Security Features

### Automatic Password Generation
All services generate secure random passwords (20-24 characters):
- MongoDB admin user
- PostgreSQL database user
- Redis authentication
- SSH user accounts

**Important:** Passwords are displayed once during installation. Save them immediately!

### SSH Hardening Options
- Disable root login
- Key-based authentication
- Change default SSH port
- User management
- SSH key management

### Firewall Configuration
UFW (Uncomplicated Firewall) automatically configured with:
- SSH access (port 22 or custom)
- HTTP/HTTPS (if Nginx installed)
- OpenVPN (if installed)
- Custom rules support
- **Multi-tier IP access control:**
  - **Trusted IPs**: Full access to all ports (VPN-like access)
  - **Restricted IPs**: Access to specific ports/services only
  - Default deny all incoming with granular IP whitelisting

## Service Configuration

### MongoDB
- Version: 7.0 LTS
- Port: 27017 (configurable)
- Authentication: Enabled by default
- Bind: localhost only (secure)
- Connection: `mongodb://admin:PASSWORD@localhost:27017/admin`

### PostgreSQL
- Version: 16.x
- Port: 5432 (default)
- Authentication: Password-based
- Remote access: Optional configuration
- Connection: `postgresql://user:PASSWORD@localhost:5432/dbname`

### Redis
- Mode: Standalone or Cluster (6 nodes)
- Port: 6379 (configurable)
- Authentication: Required
- Persistence: AOF enabled
- Max memory: 256MB with LRU eviction
- Security: Password + localhost binding

### Nginx
- Advanced configurations available:
  - Security headers
  - Rate limiting
  - Gzip compression
  - SSL/TLS optimization
  - Cloudflare Real IP restoration

### OpenVPN
- Port: 1194 (configurable)
- Protocol: UDP/TCP
- DNS: System/Google/Cloudflare
- Client management: Add, list, revoke
- Auto-generated client configs

### Monitoring Stack
- **Prometheus**: Metrics collection (port 9090)
- **Grafana**: Visualization dashboard (port 3000)
- **Node Exporter**: System metrics (port 9100)
- **Standalone**: Exporters work without Prometheus/Grafana

## Troubleshooting

### Check Installation Logs
```bash
sudo tail -f /var/log/ubuntu-setup.log
```

### View Installation Summary
```bash
sudo cat /root/ubuntu-setup-summary.txt
```

### Service Status
```bash
# MongoDB
sudo systemctl status mongod

# PostgreSQL
sudo systemctl status postgresql

# Redis
sudo systemctl status redis-server

# Nginx
sudo systemctl status nginx

# Docker
sudo systemctl status docker
```

### Common Issues

**Problem: Input prompts not visible**
- Solution: Already fixed! All prompts now output to `/dev/tty`

**Problem: MongoDB repository error on Ubuntu 24.04**
- Solution: Automatically uses jammy repository for compatibility

**Problem: Redis won't start**
- Solution: Check logs with `sudo journalctl -u redis-server -n 50`

**Problem: Permission denied**
- Solution: Run with `sudo`

**Problem: Service fails to start**
- Check logs: `sudo journalctl -u <service-name> -n 50`
- Check config: Service-specific config file in `/etc/`

## File Locations

| Type | Location |
|------|----------|
| Installation log | `/var/log/ubuntu-setup.log` |
| Credentials summary | `/root/ubuntu-setup-summary.txt` |
| MongoDB config | `/etc/mongod.conf` |
| PostgreSQL config | `/etc/postgresql/16/main/postgresql.conf` |
| Redis config | `/etc/redis/redis.conf` |
| Nginx config | `/etc/nginx/nginx.conf` |
| SSH config | `/etc/ssh/sshd_config` |
| Docker config | `/etc/docker/daemon.json` |
| OpenVPN config | `/etc/openvpn/server/` |

## Requirements

- **OS**: Ubuntu 24.04 LTS (tested), Ubuntu 22.04 LTS (should work)
- **Privileges**: Root or sudo access required
- **Network**: Internet connection for package downloads
- **Disk**: Minimum 5GB free space
- **RAM**: Minimum 1GB (2GB+ recommended)

## Architecture

```
ubuntu-server-setup/
├── install.sh              # Main installer with menu
├── remote-install.sh       # Remote installation wrapper
├── install-global.sh       # Global installation script
├── lib/
│   ├── colors.sh          # Color definitions
│   ├── common.sh          # Common utilities
│   ├── logger.sh          # Logging functions
│   └── ui.sh              # UI helpers (fixed for pipe input)
└── modules/
    ├── system.sh          # System tools
    ├── mongodb.sh         # MongoDB
    ├── postgresql.sh      # PostgreSQL
    ├── nodejs.sh          # Node.js
    ├── pm2.sh             # PM2
    ├── docker.sh          # Docker
    ├── nginx-unified.sh   # Nginx
    ├── security.sh        # UFW + Fail2ban
    ├── openvpn.sh         # OpenVPN
    ├── ssh-hardening.sh   # SSH security
    ├── redis.sh           # Redis
    └── monitoring.sh      # Prometheus + Grafana
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test on Ubuntu 24.04
5. Submit a pull request

## Testing

```bash
# Run shellcheck validation
./test.sh

# Test on fresh Ubuntu 24.04 VM
curl -fsSL https://raw.githubusercontent.com/rem0413/ubuntu-server-setup/master/remote-install.sh | sudo bash -s -- --dry-run
```

## Changelog

### v1.0.0 (2025-10-18)
- ✅ Fixed input prompt visibility for piped execution
- ✅ Fixed Redis 7.0 configuration (removed deprecated rename-command)
- ✅ Fixed MongoDB Ubuntu 24.04 repository compatibility
- ✅ Fixed Grafana apt-key deprecation warning
- ✅ Added global installation feature
- ✅ Added automatic random password generation
- ✅ Added comprehensive error logging and debugging
- ✅ Improved UI with better input visibility

## License

MIT License - See LICENSE file for details

## Support

- **Issues**: [GitHub Issues](https://github.com/rem0413/ubuntu-server-setup/issues)
- **Repository**: [GitHub](https://github.com/rem0413/ubuntu-server-setup)

## Security Notice

- All passwords are randomly generated (20-24 characters)
- Passwords displayed **once** during installation - save immediately!
- Services bound to localhost by default (secure)
- SSH hardening recommended for production servers
- Review firewall rules before exposing services to internet

---

**Made with ❤️ for Ubuntu server administrators**
