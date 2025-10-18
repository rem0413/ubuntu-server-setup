#!/bin/bash

################################################################################
# Ubuntu Server Setup - Status Check Script
# Description: Check status of all installed components
# Usage: sudo ./status.sh
################################################################################

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load libraries
source "$SCRIPT_DIR/lib/colors.sh"

# Banner
echo -e "${CYAN}"
cat << "EOF"
╔══════════════════════════════════════════════════════════════╗
║                  SYSTEM STATUS CHECK                         ║
╚══════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

echo -e "${BOLD}Server Information:${NC}"
echo -e "  Hostname: ${GREEN}$(hostname)${NC}"
echo -e "  IP Address: ${GREEN}$(hostname -I | awk '{print $1}')${NC}"
echo -e "  Ubuntu: ${GREEN}$(lsb_release -d | cut -f2)${NC}"
echo -e "  Uptime: ${GREEN}$(uptime -p)${NC}"
echo ""

# Check service status
check_service() {
    local service=$1
    local display_name=$2

    if systemctl list-unit-files | grep -q "^${service}"; then
        local status=$(systemctl is-active "$service" 2>/dev/null)
        if [[ "$status" == "active" ]]; then
            echo -e "  ${GREEN}✓${NC} $display_name: ${GREEN}running${NC}"
            return 0
        else
            echo -e "  ${RED}✗${NC} $display_name: ${RED}stopped${NC}"
            return 1
        fi
    else
        echo -e "  ${DIM}○${NC} $display_name: ${DIM}not installed${NC}"
        return 2
    fi
}

# Check command
check_command() {
    local cmd=$1
    local display_name=$2
    local version_cmd=$3

    if command -v "$cmd" &>/dev/null; then
        local version=$($version_cmd 2>&1 | head -1)
        echo -e "  ${GREEN}✓${NC} $display_name: ${GREEN}installed${NC} ${DIM}($version)${NC}"
        return 0
    else
        echo -e "  ${DIM}○${NC} $display_name: ${DIM}not installed${NC}"
        return 1
    fi
}

echo -e "${BOLD}Services Status:${NC}"
check_service "mongod" "MongoDB"
check_service "postgresql" "PostgreSQL"
check_service "nginx" "Nginx"
check_service "docker" "Docker"
check_service "ufw" "UFW Firewall"
check_service "fail2ban" "Fail2ban"
check_service "openvpn-server@server" "OpenVPN Server"
echo ""

echo -e "${BOLD}Installed Software:${NC}"
check_command "node" "Node.js" "node --version"
check_command "npm" "npm" "npm --version"
check_command "pm2" "PM2" "pm2 --version"
check_command "docker" "Docker" "docker --version"
check_command "docker" "Docker Compose" "docker compose version"
check_command "mongosh" "MongoDB Shell" "mongosh --version"
check_command "psql" "PostgreSQL Client" "psql --version"
echo ""

# System resources
echo -e "${BOLD}System Resources:${NC}"
echo -e "  CPU Usage: ${CYAN}$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)%${NC}"
echo -e "  Memory: ${CYAN}$(free -h | awk '/^Mem:/ {print $3 "/" $2}')${NC}"
echo -e "  Disk: ${CYAN}$(df -h / | awk 'NR==2 {print $3 "/" $2 " (" $5 " used)"}')${NC}"
echo -e "  Load Average: ${CYAN}$(uptime | awk -F'load average:' '{print $2}')${NC}"
echo ""

# Firewall status
if command -v ufw &>/dev/null; then
    echo -e "${BOLD}Firewall Rules:${NC}"
    ufw status | grep -v "^$" | tail -n +3 | head -10
    echo ""
fi

# Docker containers
if command -v docker &>/dev/null && systemctl is-active docker &>/dev/null; then
    echo -e "${BOLD}Docker Containers:${NC}"
    if [[ $(docker ps -q | wc -l) -gt 0 ]]; then
        docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | head -10
    else
        echo -e "  ${DIM}No running containers${NC}"
    fi
    echo ""
fi

# PM2 processes
if command -v pm2 &>/dev/null; then
    echo -e "${BOLD}PM2 Processes:${NC}"
    if pm2 list 2>/dev/null | grep -q "online"; then
        pm2 list | grep -E "│|─" | head -10
    else
        echo -e "  ${DIM}No PM2 processes running${NC}"
    fi
    echo ""
fi

# Recent errors in log
if [[ -f /var/log/ubuntu-setup.log ]]; then
    echo -e "${BOLD}Recent Installation Log:${NC}"
    echo -e "  Log file: ${DIM}/var/log/ubuntu-setup.log${NC}"
    echo -e "  Size: ${CYAN}$(du -h /var/log/ubuntu-setup.log | cut -f1)${NC}"
    echo -e "  Last modified: ${CYAN}$(stat -c %y /var/log/ubuntu-setup.log | cut -d' ' -f1,2)${NC}"
    echo ""
fi

# Installation summary
if [[ -f /root/ubuntu-setup-summary.txt ]]; then
    echo -e "${BOLD}Installation Summary Available:${NC}"
    echo -e "  ${CYAN}cat /root/ubuntu-setup-summary.txt${NC}"
    echo ""
fi

echo -e "${GREEN}Status check complete!${NC}"
echo ""
