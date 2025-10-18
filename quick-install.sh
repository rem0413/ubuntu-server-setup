#!/bin/bash

################################################################################
# Quick Install Wrapper
# Usage: curl URL | bash
# This shows menu and auto-generates the correct command
################################################################################

set -e

REPO_URL="https://raw.githubusercontent.com/rem0413/ubuntu-server-setup/master/remote-install.sh"

clear
cat << "EOF"
=========================================
  Ubuntu Server Setup - Quick Install
=========================================

Choose installation type:

  1. Node.js Application Stack
     (MongoDB + Node.js + PM2 + Nginx + Security)

  2. Docker Host
     (Docker + Security)

  3. Full Stack Development
     (All databases + Node.js + Docker + Nginx)

  4. VPN Server
     (OpenVPN + SSH Hardening + Security)

  5. Install Everything
     (All 12 components)

  0. Custom Selection
     (Clone repo for interactive menu)

=========================================

EOF

printf "Enter choice (1-5, or 0): "
read -r choice

case $choice in
    1)
        echo ""
        echo "Installing Node.js Application Stack..."
        echo "Command: curl -fsSL $REPO_URL | sudo bash -s -- --profile nodejs-app"
        echo ""
        curl -fsSL "$REPO_URL" | sudo bash -s -- --profile nodejs-app
        ;;
    2)
        echo ""
        echo "Installing Docker Host..."
        echo "Command: curl -fsSL $REPO_URL | sudo bash -s -- --profile docker-host"
        echo ""
        curl -fsSL "$REPO_URL" | sudo bash -s -- --profile docker-host
        ;;
    3)
        echo ""
        echo "Installing Full Stack..."
        echo "Command: curl -fsSL $REPO_URL | sudo bash -s -- --profile fullstack"
        echo ""
        curl -fsSL "$REPO_URL" | sudo bash -s -- --profile fullstack
        ;;
    4)
        echo ""
        echo "Installing VPN Server..."
        echo "Command: curl -fsSL $REPO_URL | sudo bash -s -- --profile vpn-server"
        echo ""
        curl -fsSL "$REPO_URL" | sudo bash -s -- --profile vpn-server
        ;;
    5)
        echo ""
        echo "Installing Everything..."
        echo "Command: curl -fsSL $REPO_URL | sudo bash -s -- --all"
        echo ""
        curl -fsSL "$REPO_URL" | sudo bash -s -- --all
        ;;
    0)
        echo ""
        echo "For custom component selection, clone the repository:"
        echo ""
        echo "  git clone https://github.com/rem0413/ubuntu-server-setup.git"
        echo "  cd ubuntu-server-setup"
        echo "  sudo ./install.sh"
        echo ""
        echo "This gives you an interactive menu to select individual components."
        exit 0
        ;;
    *)
        echo ""
        echo "Invalid choice. Exiting."
        exit 1
        ;;
esac
