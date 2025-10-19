#!/bin/bash

################################################################################
# Install Ubuntu Setup as Global Command
# Usage: sudo ./setup-global.sh
################################################################################

set -e

INSTALL_DIR="/opt/ubuntu-setup"
BIN_LINK="/usr/local/bin/ubuntu-setup"

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load version from VERSION file
VERSION=$(cat "$SCRIPT_DIR/VERSION" 2>/dev/null || echo "2.0.0")

# Check root
if [[ $EUID -ne 0 ]]; then
   echo "ERROR: Must run as root"
   exit 1
fi

echo "========================================="
echo "  Installing Ubuntu Setup Globally"
echo "========================================="
echo ""

# Create installation directory
echo "Creating installation directory..."
mkdir -p "$INSTALL_DIR"

# Copy all files
echo "Copying files..."
cp -r . "$INSTALL_DIR/"
chmod +x "$INSTALL_DIR/install.sh"

# Create wrapper script
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
        cd /tmp
        rm -rf ubuntu-setup-update
        git clone https://github.com/rem0413/ubuntu-server-setup.git ubuntu-setup-update
        cd ubuntu-setup-update
        sudo cp -r . "$INSTALL_DIR/"
        chmod +x "$INSTALL_DIR/install.sh"
        cd /
        rm -rf /tmp/ubuntu-setup-update
        echo "Updated successfully!"
        ;;

    version|v)
        if [ -f "$INSTALL_DIR/VERSION" ]; then
            cat "$INSTALL_DIR/VERSION"
        else
            echo "Version 2.0.0"
        fi
        ;;

    uninstall)
        echo "Uninstalling ubuntu-setup..."
        rm -rf "$INSTALL_DIR"
        rm -f /usr/local/bin/ubuntu-setup
        echo "Uninstalled successfully"
        ;;

    help|h|--help|-h)
        cat << 'HELP'
Ubuntu Setup - Global Command

Usage:
  ubuntu-setup install [options]     Install components
  ubuntu-setup update                 Update from GitHub
  ubuntu-setup version                Show version
  ubuntu-setup uninstall              Remove ubuntu-setup
  ubuntu-setup help                   Show this help

Install Options:
  --all                               Install all components
  --components 1 4 7 8                Install specific components
  --profile nodejs-app                Use predefined profile
  --dry-run                           Preview without installing

Profiles:
  nodejs-app    Node.js + MongoDB + PM2 + Nginx + Security
  docker-host   Docker + Security
  fullstack     All databases + Node.js + Docker + Nginx
  vpn-server    OpenVPN + SSH Hardening + Security

Examples:
  ubuntu-setup install --all
  ubuntu-setup install --components 1 4 7 8
  ubuntu-setup install --profile nodejs-app
  ubuntu-setup update
  ubuntu-setup version

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
echo "You can now use 'ubuntu-setup' command:"
echo ""
echo "  ubuntu-setup install              # Interactive menu"
echo "  ubuntu-setup install --all        # Install everything"
echo "  ubuntu-setup install --profile nodejs-app"
echo "  ubuntu-setup update               # Update from GitHub"
echo "  ubuntu-setup version              # Show version"
echo "  ubuntu-setup help                 # Show help"
echo ""
echo "Installed to: $INSTALL_DIR"
echo "Command: $BIN_LINK"
echo ""
