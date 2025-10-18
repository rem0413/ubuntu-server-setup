#!/bin/bash

################################################################################
# Ubuntu Server Setup - Remote Installation Script
# Description: Download and run installer from GitHub
# Version: 2.0.0
# Usage: curl -fsSL https://raw.githubusercontent.com/USER/REPO/main/remote-install.sh | bash
################################################################################

set -e

# Configuration
REPO_USER="${REPO_USER:-rem0413}"
REPO_NAME="${REPO_NAME:-ubuntu-server-setup}"
REPO_BRANCH="${REPO_BRANCH:-master}"
INSTALL_DIR="/tmp/ubuntu-server-setup-$$"
GITHUB_RAW="https://raw.githubusercontent.com/${REPO_USER}/${REPO_NAME}/${REPO_BRANCH}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Banner
echo -e "${CYAN}"
cat << "EOF"
╔══════════════════════════════════════════════════════════════╗
║          Ubuntu Server Setup - Remote Install                ║
║                     Version 2.0.0                            ║
╚══════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}Error: This script must be run as root${NC}"
   echo "Usage: curl -fsSL URL | sudo bash"
   exit 1
fi

# Check Ubuntu version
if ! grep -q "Ubuntu" /etc/os-release; then
    echo -e "${RED}Error: This script is designed for Ubuntu${NC}"
    exit 1
fi

echo -e "${BOLD}Installation Configuration:${NC}"
echo -e "  Repository: ${CYAN}${REPO_USER}/${REPO_NAME}${NC}"
echo -e "  Branch: ${CYAN}${REPO_BRANCH}${NC}"
echo -e "  Install Directory: ${CYAN}${INSTALL_DIR}${NC}"
echo ""
echo -e "${YELLOW}Note:${NC} For non-interactive installation, use:"
echo -e "${DIM}  curl -fsSL URL | sudo bash -s -- --all${NC}"
echo -e "${DIM}  curl -fsSL URL | sudo bash -s -- --profile nodejs-app${NC}"
echo ""

# Create temp directory
echo -e "${BOLD}[1/5]${NC} Creating temporary directory..."
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

# Download files
echo -e "${BOLD}[2/5]${NC} Downloading installation files from GitHub..."

download_file() {
    local file=$1
    local url="${GITHUB_RAW}/${file}"

    echo -n "  Downloading ${file}... "
    if curl -fsSL "$url" -o "$file" 2>/dev/null; then
        echo -e "${GREEN}✓${NC}"
        return 0
    else
        echo -e "${RED}✗${NC}"
        return 1
    fi
}

# Download main script
if ! download_file "install.sh"; then
    echo -e "${RED}Failed to download install.sh${NC}"
    echo -e "${YELLOW}Check repository URL and branch name${NC}"
    exit 1
fi

chmod +x install.sh

# Download lib files
echo -e "${BOLD}[3/5]${NC} Downloading library files..."
mkdir -p lib
for lib in colors.sh utils.sh ui.sh; do
    if ! download_file "lib/${lib}"; then
        echo -e "${RED}Failed to download lib/${lib}${NC}"
        exit 1
    fi
done

# Download module files
echo -e "${BOLD}[4/5]${NC} Downloading module files..."
mkdir -p modules

MODULES=(
    core.sh
    mongodb.sh
    postgresql.sh
    nodejs.sh
    pm2.sh
    docker.sh
    nginx-unified.sh
    security.sh
    openvpn.sh
    ssh-hardening.sh
    redis.sh
    monitoring.sh
)

for module in "${MODULES[@]}"; do
    if ! download_file "modules/${module}"; then
        echo -e "${RED}Failed to download modules/${module}${NC}"
        exit 1
    fi
done

# Download VERSION
download_file "VERSION" || true

echo ""
echo -e "${GREEN}✓ All files downloaded successfully${NC}"
echo ""

# Run installer
echo -e "${BOLD}[5/5]${NC} Starting installation..."
echo ""
echo -e "${CYAN}═══════════════════════════════════════${NC}"
echo ""

# Pass arguments to install.sh
# Redirect stdin from /dev/tty to allow interactive input when piped from curl
if [ -t 0 ]; then
    # stdin is already a terminal
    ./install.sh "$@"
else
    # stdin is piped, redirect entire script input from /dev/tty
    exec < /dev/tty
    ./install.sh "$@"
fi

# Cleanup
echo ""
echo -e "${BOLD}Cleaning up temporary files...${NC}"
cd /
rm -rf "$INSTALL_DIR"

echo -e "${GREEN}✓ Cleanup complete${NC}"
echo ""
