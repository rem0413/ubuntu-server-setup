#!/bin/bash

# Fix UFW Whitelist - Remove ALLOW Anywhere rules
# Keep only trusted IP rules

set -e

echo "========================================="
echo "UFW Whitelist Cleanup Script"
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

echo "Current UFW status:"
echo "-------------------"
ufw status numbered
echo ""

echo "⚠️  WARNING: This will remove ALL 'ALLOW Anywhere' rules"
echo "Only trusted IP rules (ALLOW from <specific-IP>) will be kept"
echo ""

read -p "Continue? (yes/no): " confirm
if [[ "$confirm" != "yes" ]]; then
    echo "Cancelled."
    exit 0
fi

echo ""
echo "Step 1: Backup current rules..."
ufw status numbered > /root/ufw-backup-$(date +%Y%m%d-%H%M%S).txt
echo "✓ Backup saved to /root/ufw-backup-*.txt"

echo ""
echo "Step 2: Removing 'ALLOW Anywhere' rules..."

# Get list of rule numbers to delete (in reverse order)
# We need to delete from highest number to lowest to avoid renumbering issues
rule_numbers=$(ufw status numbered | grep "ALLOW.*Anywhere" | grep -v "ALLOW.*\." | awk '{print $1}' | sed 's/\[//' | sed 's/\]//' | sort -rn)

if [[ -z "$rule_numbers" ]]; then
    echo "ℹ️  No 'ALLOW Anywhere' rules found"
else
    for num in $rule_numbers; do
        echo "  Deleting rule #$num..."
        echo "y" | ufw delete $num
    done
    echo "✓ Removed $(echo "$rule_numbers" | wc -l | xargs) rule(s)"
fi

echo ""
echo "Step 3: Ensure default deny policy..."
ufw default deny incoming
ufw default allow outgoing
echo "✓ Default policy set: DENY incoming, ALLOW outgoing"

echo ""
echo "Step 4: Reload UFW..."
ufw reload
echo "✓ UFW reloaded"

echo ""
echo "========================================="
echo "✓ Cleanup Complete"
echo "========================================="
echo ""
echo "Final UFW status:"
echo "-------------------"
ufw status numbered
echo ""

echo "Verification:"
echo "-------------"
echo "• Default policy: $(ufw status verbose | grep "Default:")"
echo "• Active rules: $(ufw status numbered | grep -c "^\[" || echo 0)"
echo ""
echo "✓ Server is now protected by whitelist-only access"
