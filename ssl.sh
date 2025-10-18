#!/bin/bash

################################################################################
# Ubuntu Server Setup - SSL Certificate Manager
# Description: Automated SSL/TLS certificate management with Let's Encrypt
# Usage: sudo ./ssl.sh [OPTIONS]
################################################################################

set -e

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load libraries
source "$SCRIPT_DIR/lib/colors.sh"
source "$SCRIPT_DIR/lib/utils.sh"
source "$SCRIPT_DIR/lib/ui.sh"

# Configuration
DOMAIN=""
EMAIL=""
WEBROOT="/var/www/html"
FORCE_RENEWAL=false
DRY_RUN=false
NGINX_RELOAD=true

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --domain)
            DOMAIN="$2"
            shift 2
            ;;
        --email)
            EMAIL="$2"
            shift 2
            ;;
        --webroot)
            WEBROOT="$2"
            shift 2
            ;;
        --force)
            FORCE_RENEWAL=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --no-reload)
            NGINX_RELOAD=false
            shift
            ;;
        --status)
            # Check certificate status
            if [[ -z "$2" ]]; then
                echo -e "${RED}Error: --status requires domain${NC}"
                exit 1
            fi
            CERT_DIR="/etc/letsencrypt/live/$2"
            if [[ -f "$CERT_DIR/cert.pem" ]]; then
                echo -e "${BOLD}Certificate for $2:${NC}"
                openssl x509 -in "$CERT_DIR/cert.pem" -noout -text | grep -E "Subject:|Issuer:|Not After"

                expiry=$(openssl x509 -enddate -noout -in "$CERT_DIR/cert.pem" | cut -d= -f2)
                expiry_epoch=$(date -d "$expiry" +%s 2>/dev/null || echo 0)
                now=$(date +%s)
                days_left=$(( (expiry_epoch - now) / 86400 ))

                echo ""
                if [[ $days_left -lt 0 ]]; then
                    echo -e "${RED}Status: EXPIRED${NC}"
                elif [[ $days_left -lt 30 ]]; then
                    echo -e "${YELLOW}Status: Expires in $days_left days${NC}"
                else
                    echo -e "${GREEN}Status: Valid ($days_left days remaining)${NC}"
                fi
            else
                echo -e "${RED}No certificate found for $2${NC}"
            fi
            exit 0
            ;;
        --list)
            echo -e "${BOLD}Installed SSL Certificates:${NC}"
            echo ""
            if [[ -d /etc/letsencrypt/live ]]; then
                for cert_dir in /etc/letsencrypt/live/*/; do
                    if [[ -f "$cert_dir/cert.pem" ]]; then
                        domain=$(basename "$cert_dir")
                        expiry=$(openssl x509 -enddate -noout -in "$cert_dir/cert.pem" 2>/dev/null | cut -d= -f2)
                        expiry_epoch=$(date -d "$expiry" +%s 2>/dev/null || echo 0)
                        now=$(date +%s)
                        days_left=$(( (expiry_epoch - now) / 86400 ))

                        if [[ $days_left -lt 0 ]]; then
                            echo -e "${RED}✗${NC} $domain (EXPIRED)"
                        elif [[ $days_left -lt 30 ]]; then
                            echo -e "${YELLOW}⚠${NC} $domain ($days_left days)"
                        else
                            echo -e "${GREEN}✓${NC} $domain ($days_left days)"
                        fi
                    fi
                done
            else
                echo -e "${DIM}No certificates found${NC}"
            fi
            exit 0
            ;;
        --renew-all)
            echo -e "${CYAN}"
            cat << "EOF"
╔══════════════════════════════════════════════════════════════╗
║              RENEW ALL SSL CERTIFICATES                      ║
╚══════════════════════════════════════════════════════════════╝
EOF
            echo -e "${NC}"

            log_info "Renewing all certificates..."
            if certbot renew; then
                log_success "All certificates renewed"
                if [[ "$NGINX_RELOAD" == true ]] && command -v nginx &>/dev/null; then
                    systemctl reload nginx
                    log_success "Nginx reloaded"
                fi
            else
                log_error "Renewal failed"
                exit 1
            fi
            exit 0
            ;;
        --help|-h)
            cat << EOF
SSL Certificate Manager - Let's Encrypt automation

Usage: $0 [OPTIONS]

Options:
    --domain <domain>     Domain name (required)
    --email <email>       Email for notifications
    --webroot <path>      Webroot path (default: /var/www/html)
    --force               Force certificate renewal
    --dry-run             Test without making changes
    --no-reload           Don't reload Nginx after
    --status <domain>     Check certificate status
    --list                List all certificates
    --renew-all           Renew all certificates
    --help, -h            Show this help message

Examples:
    # Request new certificate
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

What it does:
    1. Install certbot if needed
    2. Request Let's Encrypt certificate
    3. Configure Nginx with SSL
    4. Setup auto-renewal
    5. Test SSL configuration

Requirements:
    - Nginx installed and running
    - Domain DNS pointed to this server
    - Port 80 accessible from internet

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
echo -e "${CYAN}"
cat << "EOF"
╔══════════════════════════════════════════════════════════════╗
║              SSL CERTIFICATE MANAGER                         ║
╚══════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

# Validate domain
if [[ -z "$DOMAIN" ]]; then
    log_error "Domain is required"
    log_info "Usage: sudo ./ssl.sh --domain example.com"
    exit 1
fi

# Validate email
if [[ -z "$EMAIL" ]]; then
    read -p "Enter email for Let's Encrypt notifications: " EMAIL
    if [[ -z "$EMAIL" ]]; then
        log_error "Email is required"
        exit 1
    fi
fi

# Check dependencies
log_info "Checking dependencies..."

if ! command -v nginx &>/dev/null; then
    log_error "Nginx is not installed"
    log_info "Install with: sudo ./install.sh (select option 7)"
    exit 1
fi

if ! systemctl is-active --quiet nginx; then
    log_warning "Nginx is not running, starting..."
    systemctl start nginx
fi

log_success "Dependencies OK"

# Install certbot
if ! command -v certbot &>/dev/null; then
    log_info "Installing certbot..."

    apt-get update >> /var/log/ubuntu-setup.log 2>&1
    apt-get install -y certbot python3-certbot-nginx >> /var/log/ubuntu-setup.log 2>&1

    log_success "Certbot installed"
else
    log_info "Certbot already installed"
fi

# Check if certificate exists
CERT_DIR="/etc/letsencrypt/live/$DOMAIN"
if [[ -f "$CERT_DIR/cert.pem" ]] && [[ "$FORCE_RENEWAL" == false ]]; then
    log_warning "Certificate already exists for $DOMAIN"

    expiry=$(openssl x509 -enddate -noout -in "$CERT_DIR/cert.pem" | cut -d= -f2)
    expiry_epoch=$(date -d "$expiry" +%s 2>/dev/null || echo 0)
    now=$(date +%s)
    days_left=$(( (expiry_epoch - now) / 86400 ))

    echo -e "  Expires in: ${CYAN}$days_left days${NC}"
    echo ""

    if ! ask_yes_no "Renew anyway?" "n"; then
        log_info "Certificate renewal cancelled"
        exit 0
    fi
    FORCE_RENEWAL=true
fi

# Display plan
echo ""
log_info "SSL Certificate Plan:"
echo -e "  Domain: ${CYAN}$DOMAIN${NC}"
echo -e "  Email: ${CYAN}$EMAIL${NC}"
echo -e "  Method: ${CYAN}Nginx plugin${NC}"
if [[ "$FORCE_RENEWAL" == true ]]; then
    echo -e "  Action: ${YELLOW}Force renewal${NC}"
else
    echo -e "  Action: ${GREEN}New certificate${NC}"
fi
echo ""

if [[ "$DRY_RUN" == true ]]; then
    log_info "DRY-RUN MODE: No changes will be made"
    exit 0
fi

if ! ask_yes_no "Continue with SSL setup?" "y"; then
    log_info "SSL setup cancelled"
    exit 0
fi

# Request certificate
echo ""
log_info "Requesting SSL certificate..."

CERTBOT_CMD="certbot --nginx -d $DOMAIN --email $EMAIL --agree-tos --non-interactive"

if [[ "$FORCE_RENEWAL" == true ]]; then
    CERTBOT_CMD="$CERTBOT_CMD --force-renewal"
fi

if $CERTBOT_CMD >> /var/log/ubuntu-setup.log 2>&1; then
    log_success "Certificate obtained successfully"
else
    log_error "Certificate request failed"
    echo ""
    log_info "Common issues:"
    echo "  1. DNS not pointing to this server"
    echo "  2. Port 80 not accessible from internet"
    echo "  3. Nginx not configured for domain"
    echo "  4. Firewall blocking HTTP/HTTPS"
    echo ""
    log_info "Check logs: tail -50 /var/log/letsencrypt/letsencrypt.log"
    exit 1
fi

# Test SSL configuration
log_info "Testing SSL configuration..."

if nginx -t >> /var/log/ubuntu-setup.log 2>&1; then
    log_success "Nginx configuration valid"
else
    log_error "Nginx configuration invalid"
    exit 1
fi

# Reload Nginx
if [[ "$NGINX_RELOAD" == true ]]; then
    log_info "Reloading Nginx..."
    systemctl reload nginx
    log_success "Nginx reloaded"
fi

# Setup auto-renewal
log_info "Setting up auto-renewal..."

# Certbot creates systemd timer automatically
if systemctl list-timers | grep -q certbot; then
    log_success "Auto-renewal timer active"
else
    # Fallback to cron if systemd timer not available
    CRON_JOB="0 3 * * * certbot renew --quiet --post-hook 'systemctl reload nginx' >> /var/log/letsencrypt/renewal.log 2>&1"

    if ! crontab -l 2>/dev/null | grep -q "certbot renew"; then
        (crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -
        log_success "Auto-renewal cron job created"
    else
        log_info "Auto-renewal cron job already exists"
    fi
fi

# Test certificate
log_info "Verifying certificate..."

CERT_FILE="/etc/letsencrypt/live/$DOMAIN/cert.pem"
if [[ -f "$CERT_FILE" ]]; then
    expiry=$(openssl x509 -enddate -noout -in "$CERT_FILE" | cut -d= -f2)
    expiry_epoch=$(date -d "$expiry" +%s 2>/dev/null || echo 0)
    now=$(date +%s)
    days_left=$(( (expiry_epoch - now) / 86400 ))

    log_success "Certificate valid for $days_left days"
else
    log_error "Certificate file not found"
    exit 1
fi

# Summary
echo ""
echo -e "${CYAN}═══════════════════════════════════════${NC}"
echo -e "${BOLD}${GREEN}SSL Setup Completed!${NC}"
echo -e "${CYAN}═══════════════════════════════════════${NC}"
echo ""
echo -e "${BOLD}Domain:${NC} $DOMAIN"
echo -e "${BOLD}Certificate:${NC} $CERT_FILE"
echo -e "${BOLD}Valid for:${NC} $days_left days"
echo -e "${BOLD}Auto-renewal:${NC} Enabled"
echo ""
echo -e "${BOLD}Next steps:${NC}"
echo -e "  1. Test HTTPS: ${CYAN}https://$DOMAIN${NC}"
echo -e "  2. Check SSL rating: ${CYAN}https://www.ssllabs.com/ssltest/${NC}"
echo -e "  3. Verify auto-renewal: ${CYAN}sudo certbot renew --dry-run${NC}"
echo ""
echo -e "${BOLD}Management commands:${NC}"
echo -e "  Check status: ${CYAN}sudo ./ssl.sh --status $DOMAIN${NC}"
echo -e "  List all: ${CYAN}sudo ./ssl.sh --list${NC}"
echo -e "  Renew all: ${CYAN}sudo ./ssl.sh --renew-all${NC}"
echo ""
