#!/bin/bash

################################################################################
# Ubuntu Server Setup - Backup Script
# Description: Automated backup for databases, configs, and applications
# Usage: sudo ./backup.sh [OPTIONS]
################################################################################

set -e

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load libraries
source "$SCRIPT_DIR/lib/colors.sh"
source "$SCRIPT_DIR/lib/utils.sh"
source "$SCRIPT_DIR/lib/ui.sh"

# Configuration
BACKUP_ROOT="/backup"
RETENTION_DAYS=30
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
DATE_ONLY=$(date +%Y%m%d)

# Parse arguments
COMPONENT=""
SETUP_CRON=false
UPLOAD_REMOTE=""
LIST_BACKUPS=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --component)
            COMPONENT="$2"
            shift 2
            ;;
        --setup-cron)
            SETUP_CRON=true
            shift
            ;;
        --upload)
            UPLOAD_REMOTE="$2"
            shift 2
            ;;
        --list)
            LIST_BACKUPS=true
            shift
            ;;
        --help|-h)
            cat << EOF
Backup Script

Usage: $0 [OPTIONS]

Options:
    --component <name>    Backup specific component only
    --setup-cron          Setup automated daily backups
    --upload <target>     Upload to remote (s3://bucket or path)
    --list                List all available backups
    --help, -h            Show this help message

Components:
    mongodb              Backup MongoDB databases
    postgresql           Backup PostgreSQL databases
    configs              Backup system configurations
    apps                 Backup applications in /var/www
    ssl                  Backup SSL certificates
    pm2                  Backup PM2 processes
    all                  Backup everything (default)

Examples:
    # Backup everything
    sudo ./backup.sh

    # Backup only MongoDB
    sudo ./backup.sh --component mongodb

    # Setup automated daily backups (3 AM)
    sudo ./backup.sh --setup-cron

    # Backup and upload to S3
    sudo ./backup.sh --upload s3://my-backups

Backups are stored in: $BACKUP_ROOT
Retention: $RETENTION_DAYS days

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
║                     BACKUP SYSTEM                            ║
╚══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

show_banner

# List backups
if [[ "$LIST_BACKUPS" == true ]]; then
    echo -e "${BOLD}Available Backups:${NC}"
    echo ""

    if [[ ! -d "$BACKUP_ROOT" ]]; then
        log_warning "No backups directory found"
        exit 0
    fi

    for dir in mongodb postgresql configs apps ssl pm2; do
        if [[ -d "$BACKUP_ROOT/$dir" ]]; then
            echo -e "${CYAN}$dir:${NC}"
            ls -lh "$BACKUP_ROOT/$dir" 2>/dev/null | tail -n +2 | awk '{print "  " $9 " (" $5 ")"}'
            echo ""
        fi
    done

    echo -e "${BOLD}Total backup size:${NC} $(du -sh $BACKUP_ROOT 2>/dev/null | cut -f1)"
    exit 0
fi

# Setup cron
if [[ "$SETUP_CRON" == true ]]; then
    log_info "Setting up automated daily backups..."

    CRON_JOB="0 3 * * * $SCRIPT_DIR/backup.sh >> /var/log/backup.log 2>&1"

    # Check if already exists
    if crontab -l 2>/dev/null | grep -q "$SCRIPT_DIR/backup.sh"; then
        log_warning "Cron job already exists"
    else
        (crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -
        log_success "Automated backup scheduled: Daily at 3:00 AM"
        log_info "Logs will be in: /var/log/backup.log"
    fi

    exit 0
fi

# Create backup directories
mkdir -p "$BACKUP_ROOT"/{mongodb,postgresql,configs,apps,ssl,pm2}

# Backup MongoDB
backup_mongodb() {
    if ! command -v mongodump &>/dev/null; then
        log_warning "MongoDB not installed, skipping"
        return 0
    fi

    log_info "Backing up MongoDB..."

    local backup_dir="$BACKUP_ROOT/mongodb/mongo-$TIMESTAMP"

    # Get credentials from summary if available
    if [[ -f /root/ubuntu-setup-summary.txt ]]; then
        mongodump --out="$backup_dir" --gzip >> /var/log/backup.log 2>&1 || true
    else
        mongodump --out="$backup_dir" --gzip >> /var/log/backup.log 2>&1 || true
    fi

    if [[ -d "$backup_dir" ]]; then
        local size=$(du -sh "$backup_dir" | cut -f1)
        log_success "MongoDB backed up: $size"
    else
        log_error "MongoDB backup failed"
    fi
}

# Backup PostgreSQL
backup_postgresql() {
    if ! command -v pg_dumpall &>/dev/null; then
        log_warning "PostgreSQL not installed, skipping"
        return 0
    fi

    log_info "Backing up PostgreSQL..."

    local backup_file="$BACKUP_ROOT/postgresql/postgres-$TIMESTAMP.sql.gz"

    sudo -u postgres pg_dumpall | gzip > "$backup_file" 2>/dev/null

    if [[ -f "$backup_file" ]]; then
        local size=$(du -sh "$backup_file" | cut -f1)
        log_success "PostgreSQL backed up: $size"
    else
        log_error "PostgreSQL backup failed"
    fi
}

# Backup configurations
backup_configs() {
    log_info "Backing up configurations..."

    local backup_file="$BACKUP_ROOT/configs/configs-$TIMESTAMP.tar.gz"
    local items=(
        "/etc/nginx"
        "/etc/ssh/sshd_config"
        "/etc/openvpn"
        "/etc/ufw"
        "/etc/fail2ban"
        "/root/ubuntu-setup-summary.txt"
    )

    # Only backup existing items
    local existing_items=()
    for item in "${items[@]}"; do
        [[ -e "$item" ]] && existing_items+=("$item")
    done

    if [[ ${#existing_items[@]} -gt 0 ]]; then
        tar -czf "$backup_file" "${existing_items[@]}" 2>/dev/null
        local size=$(du -sh "$backup_file" | cut -f1)
        log_success "Configs backed up: $size"
    else
        log_warning "No configs to backup"
    fi
}

# Backup applications
backup_apps() {
    if [[ ! -d /var/www ]]; then
        log_warning "/var/www not found, skipping"
        return 0
    fi

    log_info "Backing up applications..."

    local backup_file="$BACKUP_ROOT/apps/apps-$TIMESTAMP.tar.gz"

    tar -czf "$backup_file" /var/www 2>/dev/null

    if [[ -f "$backup_file" ]]; then
        local size=$(du -sh "$backup_file" | cut -f1)
        log_success "Applications backed up: $size"
    else
        log_warning "No applications to backup"
    fi
}

# Backup SSL certificates
backup_ssl() {
    if [[ ! -d /etc/letsencrypt ]]; then
        log_warning "SSL certificates not found, skipping"
        return 0
    fi

    log_info "Backing up SSL certificates..."

    local backup_file="$BACKUP_ROOT/ssl/letsencrypt-$TIMESTAMP.tar.gz"

    tar -czf "$backup_file" /etc/letsencrypt 2>/dev/null

    if [[ -f "$backup_file" ]]; then
        local size=$(du -sh "$backup_file" | cut -f1)
        log_success "SSL certificates backed up: $size"
    fi
}

# Backup PM2
backup_pm2() {
    if ! command -v pm2 &>/dev/null; then
        log_warning "PM2 not installed, skipping"
        return 0
    fi

    log_info "Backing up PM2 processes..."

    local backup_file="$BACKUP_ROOT/pm2/pm2-$TIMESTAMP.tar.gz"

    # Save PM2 list
    pm2 save 2>/dev/null

    if [[ -d ~/.pm2 ]]; then
        tar -czf "$backup_file" ~/.pm2 2>/dev/null
        local size=$(du -sh "$backup_file" | cut -f1)
        log_success "PM2 backed up: $size"
    fi
}

# Clean old backups
cleanup_old_backups() {
    log_info "Cleaning backups older than $RETENTION_DAYS days..."

    local deleted=0
    for dir in mongodb postgresql configs apps ssl pm2; do
        if [[ -d "$BACKUP_ROOT/$dir" ]]; then
            find "$BACKUP_ROOT/$dir" -type f -mtime +$RETENTION_DAYS -delete 2>/dev/null && deleted=$((deleted + 1)) || true
            find "$BACKUP_ROOT/$dir" -type d -empty -delete 2>/dev/null || true
        fi
    done

    if [[ $deleted -gt 0 ]]; then
        log_success "Cleaned $deleted old backup(s)"
    fi
}

# Upload to remote
upload_remote() {
    if [[ -z "$UPLOAD_REMOTE" ]]; then
        return 0
    fi

    log_info "Uploading to remote: $UPLOAD_REMOTE"

    # Check if rclone or aws cli available
    if command -v rclone &>/dev/null; then
        rclone sync "$BACKUP_ROOT" "$UPLOAD_REMOTE" >> /var/log/backup.log 2>&1
        log_success "Uploaded via rclone"
    elif command -v aws &>/dev/null && [[ "$UPLOAD_REMOTE" == s3://* ]]; then
        aws s3 sync "$BACKUP_ROOT" "$UPLOAD_REMOTE" >> /var/log/backup.log 2>&1
        log_success "Uploaded to S3"
    else
        log_warning "No upload tool found (rclone or aws cli)"
        log_info "Install: apt install rclone  OR  apt install awscli"
    fi
}

# Main backup logic
echo ""
log_info "Starting backup process..."
log_info "Backup directory: $BACKUP_ROOT"
echo ""

START_TIME=$(date +%s)

if [[ -z "$COMPONENT" ]] || [[ "$COMPONENT" == "all" ]]; then
    backup_mongodb
    backup_postgresql
    backup_configs
    backup_apps
    backup_ssl
    backup_pm2
else
    case "$COMPONENT" in
        mongodb)
            backup_mongodb
            ;;
        postgresql)
            backup_postgresql
            ;;
        configs)
            backup_configs
            ;;
        apps)
            backup_apps
            ;;
        ssl)
            backup_ssl
            ;;
        pm2)
            backup_pm2
            ;;
        *)
            log_error "Unknown component: $COMPONENT"
            exit 1
            ;;
    esac
fi

# Cleanup old backups
cleanup_old_backups

# Upload if specified
upload_remote

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

echo ""
echo -e "${CYAN}═══════════════════════════════════════${NC}"
echo -e "${BOLD}${GREEN}Backup completed!${NC}"
echo -e "${CYAN}═══════════════════════════════════════${NC}"
echo ""
echo -e "${BOLD}Backup location:${NC} $BACKUP_ROOT"
echo -e "${BOLD}Backup time:${NC} ${DURATION}s"
echo -e "${BOLD}Total size:${NC} $(du -sh $BACKUP_ROOT 2>/dev/null | cut -f1)"
echo ""
echo -e "${DIM}To list backups: sudo ./backup.sh --list${NC}"
echo -e "${DIM}To setup automated backups: sudo ./backup.sh --setup-cron${NC}"
echo ""

# Log completion
echo "$(date): Backup completed in ${DURATION}s" >> /var/log/backup.log
