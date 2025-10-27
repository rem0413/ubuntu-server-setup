#!/bin/bash

# Add user to SSH AllowUsers directive
# Use this when you have existing users that need SSH/SFTP access

set -e

echo "========================================="
echo "SSH AllowUsers Management"
echo "========================================="
echo ""

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "ERROR: This script must be run as root (use sudo)"
   exit 1
fi

SSHD_CONFIG="/etc/ssh/sshd_config"

# Check if AllowUsers exists
if ! grep -q "^AllowUsers" "$SSHD_CONFIG"; then
    echo "INFO: AllowUsers directive not found in sshd_config"
    echo "This means all users can login via SSH (less secure)"
    echo ""
    read -p "Create AllowUsers directive? (yes/no): " create_directive

    if [[ "$create_directive" == "yes" ]]; then
        read -p "Enter username(s) to allow (space-separated): " usernames
        if [[ -z "$usernames" ]]; then
            echo "ERROR: No usernames provided"
            exit 1
        fi
        echo "AllowUsers $usernames" >> "$SSHD_CONFIG"
        echo "✓ AllowUsers directive created with: $usernames"
    else
        echo "Cancelled."
        exit 0
    fi
else
    echo "Current AllowUsers configuration:"
    echo "-----------------------------------"
    grep "^AllowUsers" "$SSHD_CONFIG"
    echo ""

    # Get username to add
    read -p "Enter username to add to AllowUsers: " username

    if [[ -z "$username" ]]; then
        echo "ERROR: Username is required"
        exit 1
    fi

    # Check if user exists on system
    if ! id "$username" &>/dev/null; then
        echo "WARNING: User '$username' does not exist on this system"
        read -p "Continue anyway? (yes/no): " continue_anyway
        if [[ "$continue_anyway" != "yes" ]]; then
            echo "Cancelled."
            exit 0
        fi
    fi

    # Check if user already in AllowUsers
    if grep "^AllowUsers" "$SSHD_CONFIG" | grep -qw "$username"; then
        echo "INFO: User '$username' is already in AllowUsers"
        exit 0
    fi

    # Backup config
    backup_file="/var/backups/sshd_config.$(date +%Y%m%d-%H%M%S).bak"
    mkdir -p /var/backups
    cp "$SSHD_CONFIG" "$backup_file"
    echo "✓ Backup created: $backup_file"

    # Add user to AllowUsers
    echo ""
    echo "Adding '$username' to AllowUsers..."
    sed -i "s/^AllowUsers.*/& $username/" "$SSHD_CONFIG"
    echo "✓ User added"
fi

# Show updated configuration
echo ""
echo "Updated AllowUsers configuration:"
echo "-----------------------------------"
grep "^AllowUsers" "$SSHD_CONFIG"
echo ""

# Test SSH configuration
echo "Testing SSH configuration..."
if sshd -t 2>/dev/null; then
    echo "✓ SSH configuration is valid"
else
    echo "ERROR: SSH configuration test failed!"
    sshd -t
    exit 1
fi

# Ask to restart SSH
echo ""
read -p "Restart SSH service to apply changes? (yes/no): " restart_ssh

if [[ "$restart_ssh" == "yes" ]]; then
    # Detect SSH service name
    ssh_service="ssh"
    if systemctl list-unit-files | grep -q "^sshd.service"; then
        ssh_service="sshd"
    fi

    echo "Restarting $ssh_service service..."
    systemctl restart "$ssh_service"
    sleep 2

    if systemctl is-active --quiet "$ssh_service"; then
        echo "✓ SSH service restarted successfully"
        echo ""
        echo "========================================="
        echo "✓ User Added to SSH AllowUsers"
        echo "========================================="
        echo ""
        echo "User '$username' can now login via SSH/SFTP"
    else
        echo "ERROR: SSH service failed to start!"
        echo "Restoring from backup..."
        cp "$backup_file" "$SSHD_CONFIG"
        systemctl restart "$ssh_service"
        exit 1
    fi
else
    echo ""
    echo "Changes saved but NOT applied."
    echo "To apply manually: sudo systemctl restart ssh"
fi
