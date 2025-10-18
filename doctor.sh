#!/bin/bash

################################################################################
# Ubuntu Server Setup - Doctor Script
# Description: System diagnostic and auto-fix tool
# Usage: sudo ./doctor.sh [OPTIONS]
################################################################################

set -e

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load libraries
source "$SCRIPT_DIR/lib/colors.sh"
source "$SCRIPT_DIR/lib/utils.sh"

# Configuration
AUTO_FIX=false
SERVICE_NAME=""
ISSUES_FOUND=0
ISSUES_FIXED=0

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --fix)
            AUTO_FIX=true
            shift
            ;;
        --service)
            SERVICE_NAME="$2"
            shift 2
            ;;
        --help|-h)
            cat << EOF
Doctor Script - System diagnostic and auto-fix tool

Usage: $0 [OPTIONS]

Options:
    --fix               Auto-fix detected issues (with confirmation)
    --service <name>    Check specific service only
    --help, -h          Show this help message

Examples:
    # Run full diagnostic
    sudo ./doctor.sh

    # Check specific service
    sudo ./doctor.sh --service nginx

    # Auto-fix issues
    sudo ./doctor.sh --fix

Available services:
    mongodb, postgresql, nginx, docker, ufw, fail2ban, pm2

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
║                  SYSTEM DOCTOR                               ║
╚══════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

echo -e "${DIM}Running diagnostic checks...${NC}"
echo ""

# Check service
check_service() {
    local service=$1
    local display_name=$2

    echo -n "  Checking $display_name... "

    if ! systemctl list-unit-files | grep -q "^${service}"; then
        echo -e "${DIM}not installed${NC}"
        return 2
    fi

    if systemctl is-active --quiet "$service"; then
        echo -e "${GREEN}✓ running${NC}"
        return 0
    else
        echo -e "${RED}✗ stopped${NC}"
        ((ISSUES_FOUND++))

        if [[ "$AUTO_FIX" == true ]]; then
            echo -e "${YELLOW}    → Attempting to start...${NC}"
            if systemctl start "$service" 2>/dev/null; then
                echo -e "${GREEN}    ✓ Started successfully${NC}"
                ((ISSUES_FIXED++))
            else
                echo -e "${RED}    ✗ Failed to start${NC}"
                echo -e "${DIM}      Fix: sudo systemctl start $service${NC}"
                echo -e "${DIM}      Logs: sudo journalctl -xe -u $service${NC}"
            fi
        else
            echo -e "${DIM}    Fix: sudo systemctl start $service${NC}"
        fi
        return 1
    fi
}

# Check disk space
check_disk_space() {
    echo -n "  Checking disk space... "

    local usage=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')

    if [[ $usage -lt 80 ]]; then
        echo -e "${GREEN}✓ ${usage}% used${NC}"
    elif [[ $usage -lt 90 ]]; then
        echo -e "${YELLOW}⚠ ${usage}% used (warning)${NC}"
        ((ISSUES_FOUND++))
        echo -e "${DIM}    Fix: sudo ./cleanup.sh --component logs${NC}"
    else
        echo -e "${RED}✗ ${usage}% used (critical!)${NC}"
        ((ISSUES_FOUND++))

        if [[ "$AUTO_FIX" == true ]]; then
            echo -e "${YELLOW}    → Cleaning logs...${NC}"
            find /var/log -name "*.log.*" -mtime +7 -delete 2>/dev/null || true
            find /var/log -name "*.gz" -mtime +7 -delete 2>/dev/null || true
            journalctl --vacuum-time=7d &>/dev/null
            echo -e "${GREEN}    ✓ Logs cleaned${NC}"
            ((ISSUES_FIXED++))
        else
            echo -e "${DIM}    Fix: sudo ./cleanup.sh --component logs${NC}"
        fi
    fi
}

# Check memory
check_memory() {
    echo -n "  Checking memory... "

    local total=$(free -m | awk 'NR==2 {print $2}')
    local used=$(free -m | awk 'NR==2 {print $3}')
    local percent=$((used * 100 / total))

    if [[ $percent -lt 85 ]]; then
        echo -e "${GREEN}✓ ${percent}% used${NC}"
    else
        echo -e "${YELLOW}⚠ ${percent}% used (high)${NC}"
        ((ISSUES_FOUND++))
        echo -e "${DIM}    Check: top or htop${NC}"
    fi
}

# Check failed services
check_failed_services() {
    echo -n "  Checking failed services... "

    local failed=$(systemctl --failed --no-legend | wc -l)

    if [[ $failed -eq 0 ]]; then
        echo -e "${GREEN}✓ none${NC}"
    else
        echo -e "${RED}✗ $failed failed${NC}"
        ((ISSUES_FOUND++))
        systemctl --failed --no-legend | while read line; do
            echo -e "${DIM}      $line${NC}"
        done
        echo -e "${DIM}    Fix: sudo systemctl reset-failed${NC}"
    fi
}

# Check SSL certificates
check_ssl() {
    if [[ ! -d /etc/letsencrypt/live ]]; then
        return 0
    fi

    echo -n "  Checking SSL certificates... "

    local expired=0
    local expiring_soon=0

    for cert_dir in /etc/letsencrypt/live/*/; do
        if [[ -f "$cert_dir/cert.pem" ]]; then
            local domain=$(basename "$cert_dir")
            local expiry=$(openssl x509 -enddate -noout -in "$cert_dir/cert.pem" 2>/dev/null | cut -d= -f2)
            local expiry_epoch=$(date -d "$expiry" +%s 2>/dev/null || echo 0)
            local now=$(date +%s)
            local days_left=$(( (expiry_epoch - now) / 86400 ))

            if [[ $days_left -lt 0 ]]; then
                ((expired++))
            elif [[ $days_left -lt 30 ]]; then
                ((expiring_soon++))
            fi
        fi
    done

    if [[ $expired -gt 0 ]]; then
        echo -e "${RED}✗ $expired expired${NC}"
        ((ISSUES_FOUND++))

        if [[ "$AUTO_FIX" == true ]]; then
            echo -e "${YELLOW}    → Renewing certificates...${NC}"
            if certbot renew --force-renewal &>/dev/null; then
                echo -e "${GREEN}    ✓ Certificates renewed${NC}"
                ((ISSUES_FIXED++))
            else
                echo -e "${RED}    ✗ Renewal failed${NC}"
                echo -e "${DIM}      Fix: sudo certbot renew --force-renewal${NC}"
            fi
        else
            echo -e "${DIM}    Fix: sudo certbot renew --force-renewal${NC}"
        fi
    elif [[ $expiring_soon -gt 0 ]]; then
        echo -e "${YELLOW}⚠ $expiring_soon expiring soon${NC}"
        echo -e "${DIM}    Fix: sudo certbot renew${NC}"
    else
        echo -e "${GREEN}✓ all valid${NC}"
    fi
}

# Check firewall
check_firewall() {
    if ! command -v ufw &>/dev/null; then
        return 0
    fi

    echo -n "  Checking firewall... "

    if ufw status | grep -q "Status: active"; then
        local rules=$(ufw status numbered | grep -c "^\[" || echo 0)
        echo -e "${GREEN}✓ active ($rules rules)${NC}"
    else
        echo -e "${YELLOW}⚠ inactive${NC}"
        ((ISSUES_FOUND++))
        echo -e "${DIM}    Fix: sudo ufw enable${NC}"
    fi
}

# Check database connectivity
check_database() {
    local db_type=$1

    if [[ "$db_type" == "mongodb" ]]; then
        if ! command -v mongosh &>/dev/null; then
            return 0
        fi

        echo -n "  Checking MongoDB connectivity... "

        if mongosh --eval "db.adminCommand('ping')" &>/dev/null; then
            echo -e "${GREEN}✓ connected${NC}"
        else
            echo -e "${RED}✗ connection failed${NC}"
            ((ISSUES_FOUND++))
            echo -e "${DIM}    Check: sudo systemctl status mongod${NC}"
            echo -e "${DIM}    Logs: sudo tail -50 /var/log/mongodb/mongod.log${NC}"
        fi

    elif [[ "$db_type" == "postgresql" ]]; then
        if ! command -v psql &>/dev/null; then
            return 0
        fi

        echo -n "  Checking PostgreSQL connectivity... "

        if sudo -u postgres psql -c "SELECT 1" &>/dev/null; then
            echo -e "${GREEN}✓ connected${NC}"
        else
            echo -e "${RED}✗ connection failed${NC}"
            ((ISSUES_FOUND++))
            echo -e "${DIM}    Check: sudo systemctl status postgresql${NC}"
            echo -e "${DIM}    Logs: sudo tail -50 /var/log/postgresql/*.log${NC}"
        fi
    fi
}

# Check PM2
check_pm2() {
    if ! command -v pm2 &>/dev/null; then
        return 0
    fi

    echo -n "  Checking PM2 processes... "

    local total=$(pm2 jlist 2>/dev/null | jq length 2>/dev/null || echo 0)
    local errored=$(pm2 jlist 2>/dev/null | jq '[.[] | select(.pm2_env.status == "errored")] | length' 2>/dev/null || echo 0)

    if [[ $total -eq 0 ]]; then
        echo -e "${DIM}no processes${NC}"
    elif [[ $errored -eq 0 ]]; then
        echo -e "${GREEN}✓ $total running${NC}"
    else
        echo -e "${RED}✗ $errored errored${NC}"
        ((ISSUES_FOUND++))

        if [[ "$AUTO_FIX" == true ]]; then
            echo -e "${YELLOW}    → Restarting errored processes...${NC}"
            pm2 restart all &>/dev/null
            echo -e "${GREEN}    ✓ Processes restarted${NC}"
            ((ISSUES_FIXED++))
        else
            echo -e "${DIM}    Fix: pm2 restart all${NC}"
            echo -e "${DIM}    Logs: pm2 logs${NC}"
        fi
    fi
}

# Check nginx configuration
check_nginx_config() {
    if ! command -v nginx &>/dev/null; then
        return 0
    fi

    echo -n "  Checking Nginx config... "

    if nginx -t &>/dev/null; then
        echo -e "${GREEN}✓ valid${NC}"
    else
        echo -e "${RED}✗ invalid${NC}"
        ((ISSUES_FOUND++))
        echo -e "${DIM}    Check: sudo nginx -t${NC}"
    fi
}

# Check Docker
check_docker() {
    if ! command -v docker &>/dev/null; then
        return 0
    fi

    echo -n "  Checking Docker... "

    if systemctl is-active --quiet docker; then
        local containers=$(docker ps -q | wc -l)
        local exited=$(docker ps -a --filter "status=exited" -q | wc -l)

        if [[ $exited -gt 0 ]]; then
            echo -e "${YELLOW}⚠ $exited exited containers${NC}"
            echo -e "${DIM}    Check: docker ps -a${NC}"
            echo -e "${DIM}    Clean: docker system prune${NC}"
        else
            echo -e "${GREEN}✓ $containers running${NC}"
        fi
    else
        echo -e "${RED}✗ not running${NC}"
        ((ISSUES_FOUND++))
    fi
}

# Main diagnostic
echo -e "${BOLD}1. System Resources:${NC}"
check_disk_space
check_memory
check_failed_services
echo ""

echo -e "${BOLD}2. Services:${NC}"
if [[ -z "$SERVICE_NAME" ]]; then
    check_service "mongod" "MongoDB"
    check_service "postgresql" "PostgreSQL"
    check_service "nginx" "Nginx"
    check_service "docker" "Docker"
    check_service "ufw" "UFW"
    check_service "fail2ban" "Fail2ban"
else
    check_service "$SERVICE_NAME" "$SERVICE_NAME"
fi
echo ""

echo -e "${BOLD}3. Configurations:${NC}"
check_nginx_config
check_firewall
echo ""

echo -e "${BOLD}4. Applications:${NC}"
check_database "mongodb"
check_database "postgresql"
check_pm2
check_docker
echo ""

echo -e "${BOLD}5. Security:${NC}"
check_ssl
echo ""

# Summary
echo -e "${CYAN}═══════════════════════════════════════${NC}"
if [[ $ISSUES_FOUND -eq 0 ]]; then
    echo -e "${BOLD}${GREEN}✓ All checks passed!${NC}"
else
    echo -e "${BOLD}${RED}Found $ISSUES_FOUND issue(s)${NC}"

    if [[ $ISSUES_FIXED -gt 0 ]]; then
        echo -e "${BOLD}${GREEN}Fixed $ISSUES_FIXED issue(s)${NC}"
    fi

    if [[ "$AUTO_FIX" == false ]] && [[ $ISSUES_FOUND -gt $ISSUES_FIXED ]]; then
        echo ""
        echo -e "${YELLOW}Run with --fix to auto-fix issues${NC}"
    fi
fi
echo -e "${CYAN}═══════════════════════════════════════${NC}"
echo ""

exit $ISSUES_FOUND
