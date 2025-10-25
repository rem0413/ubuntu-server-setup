#!/bin/bash

# Enable UFW routing for existing OpenVPN server
# Use this if you already have OpenVPN installed and need to add routing

set -e

echo "========================================="
echo "OpenVPN UFW Routing Setup"
echo "========================================="
echo ""

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "ERROR: This script must be run as root (use sudo)"
   exit 1
fi

# Check if UFW is installed
if ! command -v ufw &> /dev/null; then
    echo "ERROR: UFW is not installed"
    exit 1
fi

# Check if OpenVPN is installed
if ! command -v openvpn &> /dev/null; then
    echo "ERROR: OpenVPN is not installed"
    exit 1
fi

echo "This script will configure UFW for OpenVPN routing:"
echo ""
echo "  1. Enable UFW routing (default allow routed)"
echo "  2. Allow VPN subnet 10.8.0.0/24 (trusted full access)"
echo "  3. Reload UFW"
echo ""

read -p "Continue? (yes/no): " confirm
if [[ "$confirm" != "yes" ]]; then
    echo "Cancelled."
    exit 0
fi

echo ""
echo "Step 1: Enabling UFW routing..."
ufw default allow routed
echo "✓ UFW routing enabled"

echo ""
echo "Step 2: Allowing VPN subnet 10.8.0.0/24 (trusted)..."
ufw allow from 10.8.0.0/24 comment 'Trusted: VPN Clients'
echo "✓ VPN clients can route traffic through server"

echo ""
echo "Step 3: Reloading UFW..."
ufw reload
echo "✓ UFW reloaded"

echo ""
echo "========================================="
echo "✓ OpenVPN Routing Enabled"
echo "========================================="
echo ""
echo "UFW Configuration:"
echo "------------------"
ufw status verbose | grep -E "Default:|routed"
echo ""
echo "VPN Subnet Rule:"
echo "----------------"
ufw status | grep "10.8.0.0/24"
echo ""
echo "✓ VPN clients (10.8.0.0/24) now have full trusted access"
echo "✓ They can route all traffic through this VPN server"
