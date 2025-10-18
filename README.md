# Ubuntu Server Setup Automation

Automated setup script for Ubuntu 24.04 LTS servers with simple terminal menu. Quickly provision VPS instances with common development tools and databases.

## Quick Start

### 🚀 Fastest Way (Quick Menu)

```bash
curl -fsSL https://raw.githubusercontent.com/rem0413/ubuntu-server-setup/master/quick-install.sh | bash
```

Shows a simple menu (1-5), just pick a number!

### ⚡ Direct Installation (One Command)

**Node.js Stack:**
```bash
curl -fsSL https://raw.githubusercontent.com/rem0413/ubuntu-server-setup/master/remote-install.sh | sudo bash -s -- --profile nodejs-app
```

**Docker Host:**
```bash
curl -fsSL https://raw.githubusercontent.com/rem0413/ubuntu-server-setup/master/remote-install.sh | sudo bash -s -- --profile docker-host
```

**Full Stack:**
```bash
curl -fsSL https://raw.githubusercontent.com/rem0413/ubuntu-server-setup/master/remote-install.sh | sudo bash -s -- --profile fullstack
```

**Install Everything:**
```bash
curl -fsSL https://raw.githubusercontent.com/rem0413/ubuntu-server-setup/master/remote-install.sh | sudo bash -s -- --all
```

### 🔧 Custom Components

```bash
git clone https://github.com/rem0413/ubuntu-server-setup.git
cd ubuntu-server-setup
sudo ./install.sh
```

See [QUICK_START.md](QUICK_START.md) for detailed guide.

## Features

### Core Features
- **Interactive CLI Dashboard** - User-friendly menu for package selection
- **Predefined Profiles** - Quick setup for common scenarios (nodejs-app, docker-host, fullstack, vpn-server)
- **Dry-Run Mode** - Preview what will be installed without making changes
- **Modular Architecture** - Install only what you need
- **Idempotent Operations** - Safe to re-run without conflicts
- **Comprehensive Logging** - Track all operations in `/var/log/ubuntu-setup.log`
- **Error Handling** - Automatic retries and graceful failure recovery
- **Configuration Backup** - Automatic backup before modifying system files

### Utilities & Management
- **Installation Summary** - Auto-generated summary saved to `/root/ubuntu-setup-summary.txt`
- **Status Check** - Quick health check of all installed components
- **Update Management** - Update system packages and installed components
- **Cleanup Script** - Remove components safely with optional data purge
- **Test Suite** - Shellcheck linting and validation tests

## Supported Components

### Installation Components (12 Total)

| # | Component | Description | Version |
|---|-----------|-------------|---------|
| **1** | **System Tools** | Build essentials, git, curl, wget, vim, htop | Latest |
| **2** | **MongoDB** | NoSQL database server with random password generation | 7.0 LTS |
| **3** | **PostgreSQL** | Relational database server with random password generation | 16.x |
| **4** | **Node.js** | JavaScript runtime | 18.x / 20.x LTS / 21.x |
| **5** | **PM2** | Process manager for Node.js | Latest |
| **6** | **Docker** | Container platform + Docker Compose | Latest |
| **7** | **Nginx Unified** | Web server + Cloudflare Real IP + Advanced Config | Latest |
| **8** | **Security** | UFW firewall + Fail2ban | Latest |
| **9** | **OpenVPN** | VPN server + client management | Latest |
| **10** | **SSH Hardening** | SSH security + user creation | Latest |
| **11** | **Redis** | Cache server (standalone/cluster) + password auth | Latest |
| **12** | **Monitoring** | Prometheus + Grafana + exporters (selectable) | Latest |

### Unified Components Features

| Component | Includes | Features |
|-----------|----------|----------|
| **Nginx Unified (#7)** | Installation + Cloudflare + Advanced Config | 6 config modes, Real IP, reverse proxy, static server, security headers |
| **OpenVPN (#9)** | Server Setup + Client Management | Server install, add clients, list clients, revoke certificates |
| **SSH Hardening (#10)** | Security + User Management | Quick hardening, user creation, key management, port change |
| **Redis (#11)** | Standalone + Cluster | Port selection, 6-node cluster (3 masters + 3 replicas) |
| **Monitoring (#12)** | Prometheus + Grafana + Exporters | Selectable exporters: node, mysql, postgres, redis, mongodb |

## Quick Start

### Interactive Installation

```bash
# Clone repository
git clone https://github.com/yourusername/ubuntu-server-setup.git
cd ubuntu-server-setup

# Run installer
sudo ./install.sh
```

### Using Profiles (Recommended)

```bash
# Node.js application server
sudo ./install.sh --profile nodejs-app

# Docker container host
sudo ./install.sh --profile docker-host

# Full stack development
sudo ./install.sh --profile fullstack

# VPN server
sudo ./install.sh --profile vpn-server
```

### Dry-Run Mode

```bash
# Preview what will be installed
sudo ./install.sh --dry-run

# Preview with profile
sudo ./install.sh --profile nodejs-app --dry-run
```

### One-Line Remote Installation

```bash
curl -fsSL https://raw.githubusercontent.com/yourusername/ubuntu-server-setup/main/install.sh | sudo bash
```

### Install All Components

```bash
sudo ./install.sh --all
```

## Installation Modes

### 1. Interactive Mode (Default)

Run the installer and select components from the menu:

```bash
sudo ./install.sh
```

The interactive menu allows you to:
- Select specific components with checkboxes
- Configure each service during installation
- Review selections before proceeding

### 2. Automated Mode

Install all components without prompts:

```bash
sudo ./install.sh --all
```

## Usage Examples

### Example 1: Web Development Server

Install Node.js, PM2, MongoDB, and Nginx:

```bash
sudo ./install.sh
# Select: 1, 2, 4, 5, 7
```

### Example 2: Full Stack Development with Security

Install all development tools and security hardening:

```bash
sudo ./install.sh --all
```

### Example 3: VPN Server Setup

Install OpenVPN server with client management and SSH security:

```bash
sudo ./install.sh
# Select: 1, 8, 9, 10
# OpenVPN menu includes server setup and client management
```

### Example 4: Production Web Server

Install Nginx with Cloudflare and advanced configuration:

```bash
sudo ./install.sh
# Select: 1, 7, 8, 10
# Nginx menu includes Cloudflare Real IP and advanced configs
```

## Component Details

### System Update & Essential Tools

Installs core utilities required for development:
- `build-essential` - Compilation tools (gcc, make)
- `git` - Version control
- `curl`, `wget` - Download utilities
- `vim`, `nano` - Text editors
- `htop` - System monitoring
- `net-tools` - Network utilities

### MongoDB

- Installs MongoDB 7.0 LTS from official repository
- **Generates 20-character random password** (uppercase, lowercase, numbers)
- Displays credentials on screen only (not saved to file)
- Creates admin user with authentication
- Supports custom port configuration
- Configures systemd service for auto-start

**Post-Installation:**
```bash
# Check status
sudo systemctl status mongod

# Connect with displayed credentials
mongosh -u admin -p 'YOUR_RANDOM_PASSWORD'
mongosh --port YOUR_CUSTOM_PORT -u admin -p
```

### PostgreSQL

- Installs PostgreSQL 16.x from official repository
- **Generates 20-character random password** (uppercase, lowercase, numbers)
- Displays credentials with connection string (not saved to file)
- Creates database user and database
- Supports custom port configuration
- Configures pg_hba.conf for authentication

**Post-Installation:**
```bash
# Check status
sudo systemctl status postgresql

# Connect with displayed credentials
PGPASSWORD='YOUR_RANDOM_PASSWORD' psql -h localhost -p PORT -U dbuser -d dbname

# Connection string format provided during installation
```

### Node.js

- Installs Node.js LTS (20.x recommended)
- Configures npm for global package installation
- Optional: Install Yarn and pnpm
- Sets up proper permissions for non-root users

**Post-Installation:**
```bash
# Check versions
node --version
npm --version

# Update PATH
source ~/.bashrc

# Install packages globally
npm install -g <package>
```

### PM2

- Installs PM2 globally via npm
- Configures startup script for auto-restart
- Sets up log rotation (10MB max, 7 days retention)
- Saves process list automatically

**Post-Installation:**
```bash
# Start application
pm2 start app.js

# List processes
pm2 list

# Monitor
pm2 monit

# Save process list
pm2 save
```

### Docker

- Installs Docker CE from official repository
- Includes Docker Compose V2 plugin
- Adds user to docker group (non-root access)
- Configures logging and storage driver
- Enables systemd service

**Post-Installation:**
```bash
# Check version
docker --version
docker compose version

# Test installation
docker run hello-world

# Log out and back in for group changes
```

### Nginx

- Installs Nginx from Ubuntu repository
- Enables and starts systemd service
- Configures firewall rules if UFW active
- Ready to serve on port 80/443

**Post-Installation:**
```bash
# Check status
sudo systemctl status nginx

# Test configuration
sudo nginx -t

# Reload configuration
sudo systemctl reload nginx
```

### Security Tools

**UFW Firewall:**
- Default deny incoming, allow outgoing
- Configures SSH access (custom port supported)
- Optional HTTP/HTTPS rules
- Optional database port rules

**Fail2ban:**
- Protects against brute-force attacks
- Monitors SSH login attempts
- Bans IPs after 3 failed attempts
- 2-hour ban duration for SSH

**Post-Installation:**
```bash
# Check firewall status
sudo ufw status verbose

# Check Fail2ban jails
sudo fail2ban-client status

# Check SSH jail
sudo fail2ban-client status sshd
```

### OpenVPN Server

- Installs OpenVPN and Easy-RSA for PKI
- Creates Certificate Authority (CA)
- Generates server certificates and DH parameters
- Creates TLS authentication key
- Configures networking with IP forwarding and NAT
- Supports custom port and protocol (UDP/TCP)
- Choice of DNS servers (system, Google, Cloudflare)
- Configures firewall rules automatically

**Post-Installation:**
```bash
# Check VPN status
sudo systemctl status openvpn-server@server

# View connected clients
sudo cat /var/log/openvpn/status.log

# Add new clients using menu option 13
```

### Nginx Unified (#7)

**Unified module combining installation, Cloudflare Real IP, and advanced configuration**

**Installation:**
- Installs Nginx from Ubuntu repository
- Enables and starts systemd service
- Configures firewall rules if UFW active

**Cloudflare Real IP:**
- Fetches latest Cloudflare IP ranges (IPv4 & IPv6)
- Configures Nginx to trust Cloudflare proxies
- Sets `real_ip_header CF-Connecting-IP`
- Enables proper visitor IP logging behind Cloudflare

**Advanced Configuration - Six Modes:**
1. **Basic** - Essential settings, gzip compression
2. **Performance** - Worker connections 4096, optimized buffers
3. **Reverse Proxy** - Upstream config, WebSocket support, templates
4. **Static Server** - Cache headers, asset optimization templates
5. **Security** - Security headers (X-Frame-Options, CSP, etc.)
6. **All** - Combines performance + security + templates

**Post-Installation:**
```bash
# Check status
sudo systemctl status nginx

# Test configuration
sudo nginx -t

# Reload configuration
sudo systemctl reload nginx

# View templates
ls /etc/nginx/sites-available/
```

### OpenVPN (#9)

**Unified server setup and client management interface**

**Server Setup:**
- Installs OpenVPN and Easy-RSA for PKI
- Creates Certificate Authority (CA)
- Generates server certificates and DH parameters
- Configures networking with IP forwarding and NAT
- Supports custom port and protocol (UDP/TCP)
- Choice of DNS servers (system, Google, Cloudflare)

**Client Management:**
- Add new clients with certificate generation
- List all connected/configured clients
- Revoke client certificates
- Creates standalone .ovpn configuration files
- Server reinstallation option

**Post-Installation:**
```bash
# Check VPN status
sudo systemctl status openvpn-server@server

# View connected clients
sudo cat /var/log/openvpn/status.log

# Client configs location
ls /etc/openvpn/client-configs/files/
```

### SSH Hardening (#10)

**SSH security enhancement with user management**

**Five Hardening Options:**
1. **Quick hardening** - Recommended security settings
2. **Create SSH user** - Alternative to root login with password/key setup
3. **Manage SSH keys** - Add, view, remove, or generate keys
4. **Change SSH port** - Custom port (1024-65535)
5. **Show configuration** - Display current settings

**User Creation Features:**
- Creates user with home directory
- Password setup with strength requirements
- Optional sudo group membership
- SSH directory setup with proper permissions
- Optional SSH key configuration
- Automatic root login disable
- AllowUsers configuration

**Security Measures Applied:**
- Disable root login
- Disable password authentication (with key verification)
- Disable empty passwords
- Disable X11 forwarding
- Max authentication tries: 3
- Login grace time: 30 seconds
- Enforce SSH Protocol 2
- Configure allowed users
- Client alive intervals

**Post-Installation:**
```bash
# Verify SSH configuration
sudo sshd -t

# Check current settings
sudo grep -E "^(Port|PermitRootLogin|PasswordAuthentication)" /etc/ssh/sshd_config

# Test connection in new terminal before closing current session
```

### Redis (#11)

**Standalone or cluster cache server with security**

**Two Deployment Modes:**

1. **Standalone Mode:**
   - Single Redis instance
   - Custom port selection (1024-65535)
   - Password authentication
   - AOF persistence enabled
   - Max memory: 256MB with LRU eviction

2. **Cluster Mode:**
   - 6 nodes (3 masters + 3 replicas)
   - Automatic cluster creation
   - Individual systemd services per node
   - High availability configuration
   - Same security features as standalone

**Security Features:**
- Random 20-character password
- Dangerous commands disabled (FLUSHDB, FLUSHALL, KEYS, CONFIG)
- Localhost binding only
- Password authentication required

**Post-Installation:**
```bash
# Check status (standalone)
sudo systemctl status redis-server

# Check cluster nodes
sudo systemctl status redis-cluster-*

# Connect to Redis
redis-cli -p PORT -a 'PASSWORD'

# Monitor Redis
redis-cli -p PORT -a 'PASSWORD' monitor
```

### Monitoring (#12)

**Prometheus + Grafana + Selectable Exporters**

**Core Components (Required):**
- Prometheus (metrics collection)
- Grafana (visualization dashboards)

**Selectable Exporters:**
- **node_exporter** - System metrics (CPU, memory, disk, network)
- **mysqld_exporter** - MySQL/MariaDB metrics
- **postgres_exporter** - PostgreSQL metrics
- **redis_exporter** - Redis metrics
- **mongodb_exporter** - MongoDB metrics

**Features:**
- Auto-configuration of Prometheus scrape configs
- Grafana runs on port 3000
- Prometheus runs on port 9090
- Dashboard recommendations for each exporter
- Systemd service management

**Post-Installation:**
```bash
# Access Grafana
http://your-server:3000
# Default credentials: admin / admin

# Access Prometheus
http://your-server:9090

# Check exporter status
sudo systemctl status node_exporter
sudo systemctl status mysqld_exporter

# View metrics
curl http://localhost:9100/metrics  # node_exporter
```

## Configuration

### Log Files

All operations are logged to:
```
/var/log/ubuntu-setup.log
```

View logs:
```bash
sudo tail -f /var/log/ubuntu-setup.log
```

### Backup Files

Configuration backups are stored in:
```
/var/backups/ubuntu-setup/
```

### Environment Variables

The script respects these environment variables:
- `SUDO_USER` - Actual user when running with sudo
- `DEBIAN_FRONTEND` - Set to `noninteractive` for automated installs

## Requirements

- Ubuntu 20.04+ (optimized for Ubuntu 24.04 LTS)
- Root or sudo access
- Internet connection
- Minimum 1GB RAM (2GB+ recommended)
- 10GB free disk space

## Troubleshooting

### Installation Failed

1. Check log file for errors:
```bash
sudo tail -100 /var/log/ubuntu-setup.log
```

2. Verify internet connection:
```bash
ping -c 3 8.8.8.8
```

3. Update package lists manually:
```bash
sudo apt-get update
```

### Permission Issues

If you encounter permission errors:

```bash
# For Docker
sudo usermod -aG docker $USER
newgrp docker

# For npm global packages
source ~/.bashrc
```

### Service Not Starting

Check service status:
```bash
sudo systemctl status <service-name>
sudo journalctl -xe
```

Restart service:
```bash
sudo systemctl restart <service-name>
```

### Firewall Blocking Connections

Check UFW rules:
```bash
sudo ufw status numbered
```

Allow specific port:
```bash
sudo ufw allow <port>/tcp
```

## Management Scripts

### Status Check

```bash
# Check status of all components
sudo ./status.sh
```

Displays:
- Server information
- Service status (MongoDB, PostgreSQL, Nginx, Docker, etc.)
- Installed software versions
- System resources (CPU, memory, disk)
- Firewall rules
- Docker containers
- PM2 processes

### Update Components

```bash
# Update all components
sudo ./update.sh

# Update specific component
sudo ./update.sh --component system
sudo ./update.sh --component node
sudo ./update.sh --component docker
sudo ./update.sh --component mongodb
sudo ./update.sh --component postgresql
```

### System Diagnostics

```bash
# Run full diagnostic
sudo ./doctor.sh

# Check specific service
sudo ./doctor.sh --service nginx

# Auto-fix detected issues
sudo ./doctor.sh --fix
```

Features:
- System resources check (disk, memory)
- Service health monitoring
- Database connectivity tests
- SSL certificate expiry check
- Nginx config validation
- PM2 process status
- Auto-fix capability

### Backup & Restore

```bash
# Backup everything
sudo ./backup.sh

# Backup specific component
sudo ./backup.sh --component mongodb
sudo ./backup.sh --component postgresql

# Setup automated daily backups (3 AM)
sudo ./backup.sh --setup-cron

# List all backups
sudo ./backup.sh --list

# Upload to S3
sudo ./backup.sh --upload s3://my-backups
```

Components backed up:
- MongoDB databases
- PostgreSQL databases
- System configurations
- Applications in /var/www
- SSL certificates
- PM2 processes

### Quick Deployment

```bash
# Deploy Node.js app
sudo ./deploy.sh --repo https://github.com/user/app.git \
                 --name myapp \
                 --port 3000 \
                 --domain myapp.com

# Deploy with MongoDB
sudo ./deploy.sh --repo URL --db mongodb

# Deploy static site
sudo ./deploy.sh --repo URL --static --domain site.com
```

Features:
- Git clone to /var/www
- Automated npm install
- .env file setup with DB integration
- PM2 process management
- Nginx configuration (reverse proxy or static)
- Firewall configuration

### SSL Certificate Management

```bash
# Request SSL certificate
sudo ./ssl.sh --domain example.com --email admin@example.com

# Multi-domain certificate
sudo ./ssl.sh --domain "example.com www.example.com"

# Force renewal
sudo ./ssl.sh --domain example.com --force

# Check certificate status
sudo ./ssl.sh --status example.com

# List all certificates
sudo ./ssl.sh --list

# Renew all expiring certificates
sudo ./ssl.sh --renew-all
```

Features:
- Let's Encrypt integration
- Auto-renewal setup (systemd timer or cron)
- Nginx auto-configuration
- Certificate status checking
- Multi-domain support

### Cleanup/Uninstall

```bash
# Remove component (keep data)
sudo ./cleanup.sh --component mongodb

# Remove component with data
sudo ./cleanup.sh --component docker --purge

# Clean logs only
sudo ./cleanup.sh --component logs

# Available components:
# mongodb, postgresql, nodejs, pm2, docker, nginx, openvpn, security, redis, monitoring, logs, all
```

### Testing

```bash
# Run all tests
sudo ./test.sh

# Lint only
sudo ./test.sh --lint-only
```

Tests include:
- Shellcheck linting
- Syntax validation
- File structure checks
- Function existence
- Permission checks
- Security checks

## Security Considerations

1. **Save Random Passwords**: Database passwords are randomly generated and displayed once - save them immediately
2. **Firewall Configuration**: Only open necessary ports (use UFW)
3. **SSH Security**: Use SSH hardening module to disable root login and enforce key-based authentication
4. **Regular Updates**: Keep system and packages updated
5. **Database Access**: Restrict remote database access when possible
6. **VPN Security**: OpenVPN uses strong encryption (AES-256-GCM) and certificate-based authentication
7. **Nginx Security**: Use Advanced Nginx Configuration for security headers and SSL/TLS hardening
8. **Monitor Logs**: Regularly check `/var/log/ubuntu-setup.log` and service logs
9. **Fail2ban**: Monitors and bans IPs with failed login attempts
10. **Cloudflare**: Use Cloudflare Real IP to maintain accurate IP logging and rate limiting

## Project Structure

```
ubuntu-server-setup/
├── install.sh                    # Main installation script (v2.0.0)
├── VERSION                       # Version file
├── CHANGELOG.md                  # Version history and changes
├── README.md                     # Main documentation
├── status.sh                     # Status check utility
├── update.sh                     # Update management utility
├── cleanup.sh                    # Cleanup/uninstall utility
├── test.sh                       # Test suite
├── doctor.sh                     # System diagnostics & auto-fix
├── backup.sh                     # Backup automation tool
├── deploy.sh                     # Quick deployment helper
├── ssl.sh                        # SSL certificate manager
├── lib/
│   ├── colors.sh                # Terminal color definitions
│   ├── utils.sh                 # Utility functions (includes generate_password)
│   └── ui.sh                    # User interface functions (12-component menu)
├── modules/
│   ├── core.sh                  # System updates & essential tools
│   ├── mongodb.sh               # MongoDB installation (with random passwords)
│   ├── postgresql.sh            # PostgreSQL installation (with random passwords)
│   ├── nodejs.sh                # Node.js installation
│   ├── pm2.sh                   # PM2 process manager
│   ├── docker.sh                # Docker & Docker Compose
│   ├── nginx-unified.sh         # Nginx + Cloudflare + Advanced Config (unified)
│   ├── security.sh              # UFW firewall & Fail2ban
│   ├── openvpn.sh               # OpenVPN server + client management (unified)
│   ├── ssh-hardening.sh         # SSH security + user creation
│   ├── redis.sh                 # Redis standalone/cluster + password auth
│   └── monitoring.sh            # Prometheus + Grafana + selectable exporters
└── docs/
    ├── TROUBLESHOOTING.md       # Common issues and solutions
    ├── USE_CASES.md             # Practical examples and use cases
    ├── MAINTENANCE.md           # Maintenance and backup guide
    └── nginx-monitoring-proxy.conf.example  # Nginx config for Grafana
```

## Development

### Adding New Modules

1. Create module file in `modules/`:
```bash
modules/myservice.sh
```

2. Implement installation or configuration function:
```bash
# For installations
install_myservice() {
    log_info "Installing MyService..."
    # Installation logic here
    log_success "MyService installed successfully"
    return 0
}

# For configurations
configure_myservice() {
    log_info "Configuring MyService..."
    # Configuration logic here
    log_success "MyService configured successfully"
    return 0
}
```

3. Use shared utility functions from `lib/utils.sh`:
```bash
# Logging
log_info "Information message"
log_success "Success message"
log_warning "Warning message"
log_error "Error message"

# User input
local value=$(get_input "Prompt text" "default_value")
local password=$(get_input "Password" "" "true")  # Secret input

# Yes/No questions
if ask_yes_no "Continue?" "y"; then
    # User answered yes
fi

# Configuration backup
backup_config "/etc/myservice/config.conf"

# Check if command exists
if command_exists mycommand; then
    # Command is available
fi

# Password generation
local password=$(generate_password 20)
```

4. Source module in `install.sh`:
```bash
source "$SCRIPT_DIR/modules/myservice.sh"
```

5. Add to component selection in `install.sh`:
```bash
# In get_user_selections() or install_components()
14)
    show_step $current $total "MyService"
    install_myservice || log_error "MyService installation failed"
    ;;
```

6. Update menu in `lib/ui.sh`:
```bash
# In show_whiptail_menu() and show_simple_menu()
"14" "MyService Description" OFF
```

### Testing

Test on fresh Ubuntu VM:
```bash
# Install VirtualBox/VMware
# Create Ubuntu 24.04 VM
# Clone repository
# Run installer

sudo ./install.sh
```

## Contributing

Contributions welcome! Please:

1. Fork the repository
2. Create feature branch: `git checkout -b feature/new-module`
3. Commit changes: `git commit -am 'Add new module'`
4. Push to branch: `git push origin feature/new-module`
5. Submit pull request

## License

MIT License - see LICENSE file for details

## Documentation

- **README.md** - Main documentation (this file)
- **TROUBLESHOOTING.md** - Common issues and solutions
- **USE_CASES.md** - Practical examples for different scenarios
- **MAINTENANCE.md** - Maintenance tasks and backup strategies

## Quick Commands Reference

```bash
# Installation
sudo ./install.sh                              # Interactive installation
sudo ./install.sh --profile nodejs-app         # Use predefined profile
sudo ./install.sh --dry-run                    # Preview without installing
sudo ./install.sh --all                        # Install everything

# Management
sudo ./status.sh                               # Check system status
sudo ./update.sh                               # Update all components
sudo ./update.sh --component docker            # Update specific component
sudo ./cleanup.sh --component mongodb          # Remove component
sudo ./test.sh                                 # Run tests

# Diagnostics & Maintenance
sudo ./doctor.sh                               # Run full system diagnostic
sudo ./doctor.sh --fix                         # Auto-fix detected issues
sudo ./backup.sh                               # Backup everything
sudo ./backup.sh --setup-cron                  # Setup automated backups

# Deployment
sudo ./deploy.sh --repo URL --name app --port 3000 --domain app.com
sudo ./ssl.sh --domain example.com --email admin@example.com

# Help
./install.sh --help                            # Show installation help
./update.sh --help                             # Show update help
./cleanup.sh --help                            # Show cleanup help
./doctor.sh --help                             # Show doctor help
./backup.sh --help                             # Show backup help
./deploy.sh --help                             # Show deploy help
./ssl.sh --help                                # Show SSL help
```

## Support

- **Issues**: https://github.com/yourusername/ubuntu-server-setup/issues
- **Documentation**: See documentation files above
- **Installation Summary**: `cat /root/ubuntu-setup-summary.txt`

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for complete version history.

### Version 2.0.0 (2025-01-18)

**Major Refactoring:**
- **Module Consolidation**: Reduced from 15 to 12 components
- **nginx-unified.sh**: Combined nginx.sh + nginx-advanced.sh + cloudflare.sh
- **OpenVPN**: Merged server setup and client management into unified interface
- **Component Renumbering**: Updated all references throughout codebase

**Enhanced Modules:**
- **Monitoring**: Selectable exporters (node, mysql, postgres, redis, mongodb)
- **Redis**: Port selection + cluster mode (6 nodes: 3 masters + 3 replicas)
- **SSH Hardening**: Added user creation workflow with password/key setup
- **Nginx**: 6 configuration modes + Cloudflare Real IP in single module

**Removed Files:**
- modules/nginx.sh, modules/nginx-advanced.sh, modules/cloudflare.sh (merged)

---

### Version 1.1.0 (2025-01-XX)

**New Components:**
- Redis cache server with password authentication
- Monitoring stack (Prometheus + Grafana + node_exporter)

**New Utility Scripts:**
- `doctor.sh` - System diagnostics with auto-fix capability
- `backup.sh` - Automated backup system with cron support
- `deploy.sh` - Quick deployment helper for Node.js/static apps
- `ssl.sh` - Let's Encrypt SSL certificate manager

**Enhancements:**
- Interactive CLI dashboard now supports 15 components (was 13)
- Automated backup with 30-day retention policy
- One-command deployment workflow
- SSL auto-renewal with systemd timer
- Monitoring dashboards with Prometheus & Grafana
- Redis caching layer for applications

**Management Features:**
- System health diagnostics with automatic issue detection
- Backup automation with S3 upload support
- SSL certificate status monitoring and renewal
- Git-based deployment with PM2 integration
- Nginx reverse proxy auto-configuration for deployments

### Version 1.0.0 (2025-01-XX)

**Core Features:**
- Initial release
- Support for Ubuntu 24.04 LTS
- Interactive CLI dashboard with 13 components
- Modular installation system with lib/ and modules/ architecture
- Predefined profiles (nodejs-app, docker-host, fullstack, vpn-server)
- Dry-run mode for preview before installation
- Comprehensive logging and error handling

**Installation Components:**
- System Update & Essential Tools
- MongoDB 7.0 LTS with 20-character random password generation
- PostgreSQL 16.x with 20-character random password generation
- Node.js LTS (18.x/20.x/21.x)
- PM2 process manager
- Docker & Docker Compose
- Nginx web server
- Security tools (UFW firewall, Fail2ban)
- OpenVPN server with PKI and Easy-RSA

**Configuration & Hardening Components:**
- Cloudflare Real IP integration for Nginx
- Advanced Nginx configuration (6 modes: basic, performance, reverse proxy, static, security, all)
- SSH security hardening (4 options: quick hardening, key management, port change, config display)
- OpenVPN client certificate generation and .ovpn file creation

**Management Utilities:**
- Installation summary auto-generation (`/root/ubuntu-setup-summary.txt`)
- Status check script (`status.sh`) - Check all services and resources
- Update script (`update.sh`) - Update system and components
- Cleanup script (`cleanup.sh`) - Remove components with optional data purge
- Test suite (`test.sh`) - Shellcheck linting and validation

**Documentation:**
- Comprehensive README with quick start and examples
- TROUBLESHOOTING.md with common issues and solutions
- USE_CASES.md with 7 practical scenarios
- MAINTENANCE.md with backup strategies and maintenance schedules

**Security Enhancements:**
- Random password generation (20 chars: uppercase, lowercase, numbers)
- Passwords displayed on screen only (not saved to file)
- SSH hardening with key-based authentication support
- OpenVPN with AES-256-GCM encryption
- Nginx security headers and SSL/TLS hardening
- Fail2ban protection against brute-force attacks
- UFW firewall with intelligent rule configuration

## Acknowledgments

- NodeSource for Node.js repositories
- Docker Inc. for Docker installation scripts
- MongoDB, PostgreSQL teams for official repositories
- Ubuntu community for testing and feedback