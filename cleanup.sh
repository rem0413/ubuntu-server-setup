#!/bin/bash

################################################################################
# Ubuntu Server Setup - Cleanup/Uninstall Script
# Description: Remove installed components and clean up system
# Usage: sudo ./cleanup.sh [--component <name>] [--purge]
################################################################################

set -e

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load libraries
source "$SCRIPT_DIR/lib/colors.sh"
source "$SCRIPT_DIR/lib/utils.sh"
source "$SCRIPT_DIR/lib/ui.sh"

# Parse arguments
COMPONENT=""
PURGE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --component)
            COMPONENT="$2"
            shift 2
            ;;
        --purge)
            PURGE=true
            shift
            ;;
        --help|-h)
            cat << EOF
Cleanup/Uninstall Script

Usage: $0 [OPTIONS]

Options:
    --component <name>    Remove specific component
    --purge               Also remove config files and data
    --help, -h            Show this help message

Available components:
    mongodb         Remove MongoDB
    postgresql      Remove PostgreSQL
    nodejs          Remove Node.js and npm
    pm2             Remove PM2
    docker          Remove Docker and Docker Compose
    nginx           Remove Nginx
    openvpn         Remove OpenVPN
    security        Remove UFW and Fail2ban
    logs            Clean up log files only
    all             Remove everything (dangerous!)

Examples:
    # Remove MongoDB (keep config)
    sudo ./cleanup.sh --component mongodb

    # Remove Docker (including data)
    sudo ./cleanup.sh --component docker --purge

    # Clean logs only
    sudo ./cleanup.sh --component logs

Warning:
    --purge will delete all data and configurations!
    Always backup important data before running with --purge

EOF
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            exit 1
            ;;
        esac
done

# Check root
check_root || exit 1

# Banner
echo -e "${RED}"
cat << "EOF"
╔══════════════════════════════════════════════════════════════╗
║                  CLEANUP / UNINSTALL                         ║
╚══════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

# Warning
if [[ "$PURGE" == true ]]; then
    log_warning "PURGE MODE: All data and configurations will be deleted!"
fi

# Cleanup MongoDB
cleanup_mongodb() {
    log_info "Removing MongoDB..."

    if command -v mongod &>/dev/null; then
        systemctl stop mongod 2>/dev/null || true
        systemctl disable mongod 2>/dev/null || true

        if [[ "$PURGE" == true ]]; then
            apt-get remove --purge mongodb-org* -y >> /var/log/ubuntu-setup.log 2>&1
            rm -rf /var/log/mongodb /var/lib/mongodb
            rm -f /etc/apt/sources.list.d/mongodb*.list
            log_success "MongoDB purged (including data)"
        else
            apt-get remove mongodb-org* -y >> /var/log/ubuntu-setup.log 2>&1
            log_success "MongoDB removed (data preserved in /var/lib/mongodb)"
        fi
    else
        log_warning "MongoDB not installed"
    fi
}

# Cleanup PostgreSQL
cleanup_postgresql() {
    log_info "Removing PostgreSQL..."

    if command -v postgres &>/dev/null; then
        systemctl stop postgresql 2>/dev/null || true
        systemctl disable postgresql 2>/dev/null || true

        if [[ "$PURGE" == true ]]; then
            apt-get remove --purge postgresql* -y >> /var/log/ubuntu-setup.log 2>&1
            rm -rf /var/lib/postgresql /etc/postgresql
            log_success "PostgreSQL purged (including data)"
        else
            apt-get remove postgresql* -y >> /var/log/ubuntu-setup.log 2>&1
            log_success "PostgreSQL removed (data preserved)"
        fi
    else
        log_warning "PostgreSQL not installed"
    fi
}

# Cleanup Node.js
cleanup_nodejs() {
    log_info "Removing Node.js..."

    if command -v node &>/dev/null; then
        # Remove global npm packages
        npm ls -g --depth=0 2>/dev/null | awk '/pm2/ {print $2}' | xargs -r npm uninstall -g

        if [[ "$PURGE" == true ]]; then
            apt-get remove --purge nodejs -y >> /var/log/ubuntu-setup.log 2>&1
            rm -rf ~/.npm ~/.nvm /usr/local/lib/node_modules
            rm -f /etc/apt/sources.list.d/nodesource.list
            log_success "Node.js purged"
        else
            apt-get remove nodejs -y >> /var/log/ubuntu-setup.log 2>&1
            log_success "Node.js removed"
        fi
    else
        log_warning "Node.js not installed"
    fi
}

# Cleanup PM2
cleanup_pm2() {
    log_info "Removing PM2..."

    if command -v pm2 &>/dev/null; then
        pm2 kill >> /var/log/ubuntu-setup.log 2>&1 || true
        npm uninstall -g pm2 >> /var/log/ubuntu-setup.log 2>&1

        if [[ "$PURGE" == true ]]; then
            rm -rf ~/.pm2
            log_success "PM2 purged (including logs)"
        else
            log_success "PM2 removed (logs preserved in ~/.pm2)"
        fi
    else
        log_warning "PM2 not installed"
    fi
}

# Cleanup Docker
cleanup_docker() {
    log_info "Removing Docker..."

    if command -v docker &>/dev/null; then
        # Stop all containers
        docker stop $(docker ps -aq) 2>/dev/null || true

        systemctl stop docker 2>/dev/null || true
        systemctl disable docker 2>/dev/null || true

        if [[ "$PURGE" == true ]]; then
            apt-get remove --purge docker-ce docker-ce-cli containerd.io docker-compose-plugin -y >> /var/log/ubuntu-setup.log 2>&1
            rm -rf /var/lib/docker /var/lib/containerd
            rm -f /etc/apt/sources.list.d/docker.list
            log_success "Docker purged (including images and volumes)"
        else
            apt-get remove docker-ce docker-ce-cli containerd.io docker-compose-plugin -y >> /var/log/ubuntu-setup.log 2>&1
            log_success "Docker removed (data preserved in /var/lib/docker)"
        fi
    else
        log_warning "Docker not installed"
    fi
}

# Cleanup Nginx
cleanup_nginx() {
    log_info "Removing Nginx..."

    if command -v nginx &>/dev/null; then
        systemctl stop nginx 2>/dev/null || true
        systemctl disable nginx 2>/dev/null || true

        if [[ "$PURGE" == true ]]; then
            apt-get remove --purge nginx* -y >> /var/log/ubuntu-setup.log 2>&1
            rm -rf /etc/nginx /var/log/nginx
            log_success "Nginx purged (including config)"
        else
            apt-get remove nginx* -y >> /var/log/ubuntu-setup.log 2>&1
            log_success "Nginx removed (config preserved)"
        fi
    else
        log_warning "Nginx not installed"
    fi
}

# Cleanup OpenVPN
cleanup_openvpn() {
    log_info "Removing OpenVPN..."

    if command -v openvpn &>/dev/null; then
        systemctl stop openvpn-server@server 2>/dev/null || true
        systemctl disable openvpn-server@server 2>/dev/null || true

        if [[ "$PURGE" == true ]]; then
            apt-get remove --purge openvpn easy-rsa -y >> /var/log/ubuntu-setup.log 2>&1
            rm -rf /etc/openvpn /var/log/openvpn
            log_success "OpenVPN purged (including certificates)"
        else
            apt-get remove openvpn easy-rsa -y >> /var/log/ubuntu-setup.log 2>&1
            log_success "OpenVPN removed (config preserved)"
        fi
    else
        log_warning "OpenVPN not installed"
    fi
}

# Cleanup Security
cleanup_security() {
    log_info "Removing Security tools..."

    if command -v ufw &>/dev/null; then
        ufw disable 2>/dev/null || true
        apt-get remove --purge ufw -y >> /var/log/ubuntu-setup.log 2>&1 || true
    fi

    if command -v fail2ban-client &>/dev/null; then
        systemctl stop fail2ban 2>/dev/null || true
        apt-get remove --purge fail2ban -y >> /var/log/ubuntu-setup.log 2>&1 || true
    fi

    log_success "Security tools removed"
}

# Cleanup logs only
cleanup_logs() {
    log_info "Cleaning up log files..."

    # Truncate setup log
    if [[ -f /var/log/ubuntu-setup.log ]]; then
        truncate -s 0 /var/log/ubuntu-setup.log
    fi

    # Clean old logs
    find /var/log -name "*.log.*" -mtime +7 -delete 2>/dev/null || true
    find /var/log -name "*.gz" -mtime +7 -delete 2>/dev/null || true

    # Journal cleanup
    journalctl --vacuum-time=7d &>/dev/null

    log_success "Log files cleaned"
}

# Main cleanup
if [[ -z "$COMPONENT" ]]; then
    log_error "No component specified"
    log_info "Run with --help to see available components"
    exit 1
fi

# Confirm
if [[ "$COMPONENT" == "all" ]]; then
    echo ""
    log_warning "This will remove ALL installed components!"
    if [[ "$PURGE" == true ]]; then
        log_warning "PURGE mode will delete all data permanently!"
    fi
    echo ""

    if ! ask_yes_no "Are you absolutely sure?" "n"; then
        log_info "Cleanup cancelled"
        exit 0
    fi
fi

# Execute cleanup
case "$COMPONENT" in
    mongodb)
        cleanup_mongodb
        ;;
    postgresql)
        cleanup_postgresql
        ;;
    nodejs|node)
        cleanup_nodejs
        ;;
    pm2)
        cleanup_pm2
        ;;
    docker)
        cleanup_docker
        ;;
    nginx)
        cleanup_nginx
        ;;
    openvpn)
        cleanup_openvpn
        ;;
    security)
        cleanup_security
        ;;
    logs)
        cleanup_logs
        ;;
    all)
        cleanup_mongodb
        cleanup_postgresql
        cleanup_nodejs
        cleanup_pm2
        cleanup_docker
        cleanup_nginx
        cleanup_openvpn
        cleanup_security
        cleanup_logs
        ;;
    *)
        log_error "Unknown component: $COMPONENT"
        exit 1
        ;;
esac

# Final cleanup
apt-get autoremove -y >> /var/log/ubuntu-setup.log 2>&1
apt-get autoclean >> /var/log/ubuntu-setup.log 2>&1

echo ""
log_success "Cleanup completed!"
log_info "System packages cleaned up"
echo ""
