#!/bin/bash

################################################################################
# Remote Global Installation
# Usage: curl URL | sudo bash
################################################################################

set -e

REPO_USER="${REPO_USER:-rem0413}"
REPO_NAME="${REPO_NAME:-ubuntu-server-setup}"
REPO_BRANCH="${REPO_BRANCH:-master}"
INSTALL_DIR="/opt/ubuntu-setup"
BIN_LINK="/usr/local/bin/ubuntu-setup"

# Check root
if [[ $EUID -ne 0 ]]; then
   echo "ERROR: Must run as root"
   echo "Usage: curl URL | sudo bash"
   exit 1
fi

echo "========================================="
echo "  Installing Ubuntu Setup Globally"
echo "========================================="
echo ""

# Install git if not present
if ! command -v git &> /dev/null; then
    echo "Installing git..."
    apt-get update -qq
    apt-get install -y git -qq
fi

# Clone or update repository
if [ -d "$INSTALL_DIR" ]; then
    echo "Updating existing installation..."
    cd "$INSTALL_DIR"
    git pull origin "$REPO_BRANCH"
else
    echo "Cloning repository..."
    git clone -b "$REPO_BRANCH" "https://github.com/${REPO_USER}/${REPO_NAME}.git" "$INSTALL_DIR"
fi

chmod +x "$INSTALL_DIR/install.sh"

# Create global command
echo "Creating global command..."
cat > "$BIN_LINK" << 'EOF'
#!/bin/bash

INSTALL_DIR="/opt/ubuntu-setup"

case "$1" in
    install|i)
        shift
        cd "$INSTALL_DIR"
        sudo "$INSTALL_DIR/install.sh" "$@"
        ;;

    update|u)
        echo "Updating ubuntu-setup from GitHub..."
        cd "$INSTALL_DIR"
        git pull
        echo "Updated successfully!"
        ;;

    version|v|--version|-v)
        if [ -f "$INSTALL_DIR/VERSION" ]; then
            cat "$INSTALL_DIR/VERSION"
        else
            echo "Ubuntu Setup v2.0.0"
        fi
        ;;

    uninstall)
        echo "Uninstalling ubuntu-setup..."
        sudo rm -rf "$INSTALL_DIR"
        sudo rm -f /usr/local/bin/ubuntu-setup
        echo "Uninstalled successfully"
        ;;

    help|h|--help|-h)
        cat << 'HELP'
=========================================
  Ubuntu Setup - Global Command
=========================================

Usage:
  ubuntu-setup install [options]     Install components
  ubuntu-setup update                 Update from GitHub
  ubuntu-setup version                Show version
  ubuntu-setup uninstall              Remove ubuntu-setup
  ubuntu-setup help                   Show this help

Install Options:
  --all                               Install all components
  --components 1 4 7 8                Install specific components
  --profile <name>                    Use predefined profile
  --dry-run                           Preview without installing

Available Profiles:
  nodejs-app    MongoDB + Node.js + PM2 + Nginx + Security
  docker-host   Docker + Security
  fullstack     All databases + Node.js + Docker + Nginx
  vpn-server    OpenVPN + SSH Hardening + Security

Components (12 total):
  1.  System Update & Essential Tools
  2.  MongoDB Database
  3.  PostgreSQL Database
  4.  Node.js & npm
  5.  PM2 Process Manager
  6.  Docker & Docker Compose
  7.  Nginx Web Server
  8.  Security Tools (UFW, Fail2ban)
  9.  OpenVPN Server
  10. SSH Security Hardening
  11. Redis Cache Server
  12. Monitoring Stack

Examples:
  # Interactive mode (shows menu)
  ubuntu-setup install

  # Install all
  ubuntu-setup install --all

  # Install specific components
  ubuntu-setup install --components 1 4 7 8

  # Use profile
  ubuntu-setup install --profile nodejs-app

  # Update command itself
  ubuntu-setup update

HELP
        ;;

    *)
        echo "Usage: ubuntu-setup {install|update|version|uninstall|help}"
        echo "Try 'ubuntu-setup help' for more information"
        exit 1
        ;;
esac
EOF

chmod +x "$BIN_LINK"

echo ""
echo "========================================="
echo "  Installation Complete!"
echo "========================================="
echo ""
echo "Ubuntu Setup installed as global command!"
echo ""
echo "Quick Start:"
echo "  ubuntu-setup install              # Interactive menu"
echo "  ubuntu-setup install --all        # Install everything"
echo "  ubuntu-setup install --profile nodejs-app"
echo "  ubuntu-setup update               # Update from GitHub"
echo "  ubuntu-setup help                 # Show full help"
echo ""
echo "Installed to: $INSTALL_DIR"
echo "Command available: ubuntu-setup"
echo ""
