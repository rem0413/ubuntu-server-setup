#!/bin/bash

################################################################################
# Ubuntu Server Setup - Update Script
# Description: Update all installed components
# Usage: sudo ./update.sh [--component <name>]
################################################################################

set -e

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load libraries
source "$SCRIPT_DIR/lib/colors.sh"
source "$SCRIPT_DIR/lib/utils.sh"

# Parse arguments
COMPONENT=""
while [[ $# -gt 0 ]]; do
    case $1 in
        --component)
            COMPONENT="$2"
            shift 2
            ;;
        --help|-h)
            cat << EOF
Update Script

Usage: $0 [OPTIONS]

Options:
    --component <name>    Update specific component
    --help, -h            Show this help message

Available components:
    system        System packages (apt update && apt upgrade)
    node          Node.js to latest LTS
    docker        Docker to latest stable
    mongodb       MongoDB to latest in current series
    postgresql    PostgreSQL to latest in current series
    all           Update everything (default)

Examples:
    sudo ./update.sh
    sudo ./update.sh --component node
    sudo ./update.sh --component system

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
show_banner() {
    echo -e "${CYAN}"
    cat << "EOF"
╔══════════════════════════════════════════════════════════════╗
║                     SYSTEM UPDATE                            ║
╚══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

show_banner

# Update system packages
update_system() {
    log_info "Updating system packages..."

    apt-get update >> /var/log/ubuntu-setup.log 2>&1
    apt-get upgrade -y >> /var/log/ubuntu-setup.log 2>&1
    apt-get autoremove -y >> /var/log/ubuntu-setup.log 2>&1
    apt-get autoclean >> /var/log/ubuntu-setup.log 2>&1

    log_success "System packages updated"
}

# Update Node.js
update_nodejs() {
    if ! command -v node &>/dev/null; then
        log_warning "Node.js not installed, skipping"
        return 0
    fi

    log_info "Updating Node.js..."
    local current=$(node --version)

    npm install -g npm@latest >> /var/log/ubuntu-setup.log 2>&1

    log_success "Node.js updated (current: $current, npm updated to latest)"
}

# Update Docker
update_docker() {
    if ! command -v docker &>/dev/null; then
        log_warning "Docker not installed, skipping"
        return 0
    fi

    log_info "Updating Docker..."

    apt-get update >> /var/log/ubuntu-setup.log 2>&1
    apt-get install --only-upgrade docker-ce docker-ce-cli containerd.io -y >> /var/log/ubuntu-setup.log 2>&1

    log_success "Docker updated to $(docker --version)"
}

# Update MongoDB
update_mongodb() {
    if ! command -v mongod &>/dev/null; then
        log_warning "MongoDB not installed, skipping"
        return 0
    fi

    log_info "Updating MongoDB..."

    apt-get update >> /var/log/ubuntu-setup.log 2>&1
    apt-get install --only-upgrade mongodb-org -y >> /var/log/ubuntu-setup.log 2>&1

    systemctl restart mongod

    log_success "MongoDB updated"
}

# Update PostgreSQL
update_postgresql() {
    if ! command -v postgres &>/dev/null; then
        log_warning "PostgreSQL not installed, skipping"
        return 0
    fi

    log_info "Updating PostgreSQL..."

    apt-get update >> /var/log/ubuntu-setup.log 2>&1
    apt-get install --only-upgrade postgresql postgresql-contrib -y >> /var/log/ubuntu-setup.log 2>&1

    systemctl restart postgresql

    log_success "PostgreSQL updated"
}

# Update PM2
update_pm2() {
    if ! command -v pm2 &>/dev/null; then
        log_warning "PM2 not installed, skipping"
        return 0
    fi

    log_info "Updating PM2..."

    npm install -g pm2@latest >> /var/log/ubuntu-setup.log 2>&1
    pm2 update >> /var/log/ubuntu-setup.log 2>&1

    log_success "PM2 updated to $(pm2 --version)"
}

# Main update logic
if [[ -z "$COMPONENT" ]] || [[ "$COMPONENT" == "all" ]]; then
    log_info "Updating all components..."
    echo ""

    update_system
    update_nodejs
    update_docker
    update_mongodb
    update_postgresql
    update_pm2

    echo ""
    log_success "All updates completed!"
    echo ""
    log_info "Review changes in: /var/log/ubuntu-setup.log"
    echo ""
else
    case "$COMPONENT" in
        system)
            update_system
            ;;
        node|nodejs)
            update_nodejs
            ;;
        docker)
            update_docker
            ;;
        mongodb|mongo)
            update_mongodb
            ;;
        postgresql|postgres)
            update_postgresql
            ;;
        pm2)
            update_pm2
            ;;
        *)
            log_error "Unknown component: $COMPONENT"
            log_info "Available: system, node, docker, mongodb, postgresql, pm2, all"
            exit 1
            ;;
    esac

    echo ""
    log_success "Update completed!"
fi

# Security updates check
if [[ -f /var/run/reboot-required ]]; then
    echo ""
    log_warning "System reboot required for updates to take effect"
    log_info "Run: sudo reboot"
fi
