#!/bin/bash

################################################################################
# Ubuntu Server Setup - Inline Installation
# Simple component selection without complex menu
################################################################################

set -e

REPO_USER="${REPO_USER:-rem0413}"
REPO_NAME="${REPO_NAME:-ubuntu-server-setup}"
REPO_BRANCH="${REPO_BRANCH:-master}"
INSTALL_DIR="/tmp/ubuntu-setup-$$"
GITHUB_RAW="https://raw.githubusercontent.com/${REPO_USER}/${REPO_NAME}/${REPO_BRANCH}"

# Check root
if [[ $EUID -ne 0 ]]; then
   echo "ERROR: Must run as root"
   echo "Usage: curl URL | sudo bash"
   exit 1
fi

# Show components
cat << 'EOF'
=========================================
  Ubuntu Server Setup
=========================================

Available Components:
  1. System Update & Essential Tools
  2. MongoDB Database
  3. PostgreSQL Database
  4. Node.js & npm
  5. PM2 Process Manager
  6. Docker & Docker Compose
  7. Nginx Web Server
  8. Security Tools (UFW, Fail2ban)
  9. OpenVPN Server
 10. SSH Security Hardening
 11. Redis Cache Server
 12. Monitoring Stack

Quick Options:
  0 = Install All
  q = Quit

=========================================

EOF

# Ask for input
printf "Enter component numbers (space-separated, e.g. 1 4 7 8): "
read -r input

# Handle input
input=$(echo "$input" | xargs)

case "$input" in
    q|Q)
        echo "Cancelled"
        exit 0
        ;;
    0)
        COMPONENTS="--all"
        echo "Installing all components..."
        ;;
    "")
        echo "ERROR: No input"
        exit 1
        ;;
    *)
        # Validate numbers
        if [[ ! "$input" =~ ^[0-9\ ]+$ ]]; then
            echo "ERROR: Invalid format. Use numbers only (e.g. 1 4 7 8)"
            exit 1
        fi

        # Check range
        for num in $input; do
            if [[ $num -lt 1 || $num -gt 12 ]]; then
                echo "ERROR: Invalid number '$num' (valid: 1-12)"
                exit 1
            fi
        done

        echo "Selected components: $input"
        COMPONENTS="--components $input"
        ;;
esac

echo ""
echo "Downloading installer..."

# Create temp directory
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

# Download files
download_file() {
    local file=$1
    curl -fsSL "${GITHUB_RAW}/${file}" -o "$file" 2>/dev/null || return 1
}

download_file "install.sh" || { echo "ERROR: Download failed"; exit 1; }
chmod +x install.sh

mkdir -p lib modules
for lib in colors.sh utils.sh ui.sh; do
    download_file "lib/${lib}" || { echo "ERROR: Download lib/${lib} failed"; exit 1; }
done

MODULES=(core.sh mongodb.sh postgresql.sh nodejs.sh pm2.sh docker.sh nginx-unified.sh security.sh openvpn.sh ssh-hardening.sh redis.sh monitoring.sh)
for module in "${MODULES[@]}"; do
    download_file "modules/${module}" || { echo "ERROR: Download modules/${module} failed"; exit 1; }
done

download_file "VERSION" 2>/dev/null || true

echo ""
echo "Starting installation..."
echo ""

# Run with selected components
if [[ "$COMPONENTS" == "--all" ]]; then
    ./install.sh --all
else
    # Convert space-separated numbers to component selection
    # We'll use a profile approach
    COMP_ARRAY=($input)
    if [[ ${#COMP_ARRAY[@]} -eq 1 ]]; then
        # Single component - use direct flag if we add it
        ./install.sh --all  # For now, fallback to asking user to add component flag support
    else
        # Multiple components - need to pass somehow
        # For now, export and read in install.sh
        export INLINE_COMPONENTS="$input"
        ./install.sh
    fi
fi

# Cleanup
cd /
rm -rf "$INSTALL_DIR"

echo ""
echo "Installation complete!"
echo "Summary: /root/ubuntu-setup-summary.txt"
echo ""
