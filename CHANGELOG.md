# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.0.0] - 2025-01-18

### Major Refactoring

**Module Consolidation:**
- Reduced components from 15 to 12 by merging related functionality
- Created `nginx-unified.sh` combining nginx.sh, nginx-advanced.sh, and cloudflare.sh
- Merged OpenVPN server and client management into single unified interface
- Removed standalone components: Cloudflare Real IP (10), Advanced Nginx (11), Add OpenVPN Client (13)

### Added

**modules/monitoring.sh:**
- Interactive exporter selection menu
- Support for node_exporter, mysqld_exporter, postgres_exporter, redis_exporter, mongodb_exporter
- Auto-configuration of Prometheus scrape configs based on selections
- Dashboard recommendations for each exporter type

**modules/redis.sh:**
- Port selection (1024-65535, default 6379)
- Redis Cluster mode support (6 nodes: 3 masters + 3 replicas)
- Standalone and cluster configuration options
- Systemd service management for each cluster node

**modules/openvpn.sh:**
- Unified menu with adaptive interface based on installation state
- Integrated server setup and client management
- List clients and revoke client certificates
- Server reinstallation option

**modules/nginx-unified.sh:**
- Combined installation and configuration in single module
- 6 configuration modes: Basic, Performance, Reverse Proxy, Static Server, Security, All
- Cloudflare Real IP integration with automatic IP range fetching
- Template creation for reverse proxy and static servers

**modules/ssh-hardening.sh:**
- User creation workflow with password setup
- SSH key configuration during user creation
- Sudo group management
- Optional password authentication disable after key setup
- AllowUsers configuration with created user

### Changed

- Updated component numbering throughout install.sh
- Modified all profiles to use new component numbers
- Updated help text to reflect 12 components
- Consolidated menu displays and case statements
- Enhanced user summaries with unified component descriptions

### Removed

- `modules/nginx.sh` (merged into nginx-unified.sh)
- `modules/nginx-advanced.sh` (merged into nginx-unified.sh)
- `modules/cloudflare.sh` (merged into nginx-unified.sh)

### Technical Improvements

- Modular architecture with better separation of concerns
- Reduced code duplication across nginx modules
- Improved menu navigation with state-aware interfaces
- Enhanced configuration flexibility with interactive prompts

---

## [1.1.0] - 2025-01-XX

### Added

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

---

## [1.0.0] - 2025-01-XX

### Initial Release

**Core Features:**
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
- Advanced Nginx configuration (6 modes)
- SSH security hardening (4 options)
- OpenVPN client certificate generation

**Management Utilities:**
- Installation summary auto-generation
- Status check script (`status.sh`)
- Update script (`update.sh`)
- Cleanup script (`cleanup.sh`)
- Test suite (`test.sh`)

**Security Enhancements:**
- Random password generation (20 chars: uppercase, lowercase, numbers)
- SSH hardening with key-based authentication
- OpenVPN with AES-256-GCM encryption
- Nginx security headers and SSL/TLS hardening
- Fail2ban protection against brute-force attacks
- UFW firewall with intelligent rule configuration
