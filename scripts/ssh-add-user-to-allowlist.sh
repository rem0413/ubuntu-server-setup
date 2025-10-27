#!/bin/bash

# SSH AllowUsers Management Tool
# Add, remove, or list users in SSH AllowUsers directive

set -e

SSHD_CONFIG="/etc/ssh/sshd_config"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

echo -e "${CYAN}=========================================${NC}"
echo -e "${BOLD}SSH AllowUsers Management${NC}"
echo -e "${CYAN}=========================================${NC}"
echo ""

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}ERROR: This script must be run as root (use sudo)${NC}"
   exit 1
fi

# Function to show current config
show_config() {
    if grep -q "^AllowUsers" "$SSHD_CONFIG"; then
        echo -e "${BOLD}Current AllowUsers:${NC}"
        local users=$(grep "^AllowUsers" "$SSHD_CONFIG" | sed 's/^AllowUsers //')
        echo ""
        local count=0
        for user in $users; do
            ((count++))
            if id "$user" &>/dev/null; then
                echo -e "  ${GREEN}✓${NC} $user (exists on system)"
            else
                echo -e "  ${YELLOW}⚠${NC} $user (not found on system)"
            fi
        done
        echo ""
        echo -e "${BOLD}Total users:${NC} $count"
    else
        echo -e "${YELLOW}AllowUsers directive not configured${NC}"
        echo "All users can login via SSH (less secure)"
    fi
}

# Function to add user
add_user() {
    if ! grep -q "^AllowUsers" "$SSHD_CONFIG"; then
        echo -e "${YELLOW}INFO: AllowUsers directive not found${NC}"
        echo "This means all users can login via SSH (less secure)"
        echo ""
        read -p "Create AllowUsers directive? (yes/no): " create_directive

        if [[ "$create_directive" == "yes" ]]; then
            read -p "Enter username(s) to allow (space-separated): " usernames
            if [[ -z "$usernames" ]]; then
                echo -e "${RED}ERROR: No usernames provided${NC}"
                return 1
            fi
            echo "AllowUsers $usernames" >> "$SSHD_CONFIG"
            echo -e "${GREEN}✓ AllowUsers directive created with: $usernames${NC}"
        else
            echo "Cancelled."
            return 1
        fi
    else
        echo ""
        show_config
        echo ""

        # Get username to add
        read -p "Enter username to add: " username

        if [[ -z "$username" ]]; then
            echo -e "${RED}ERROR: Username is required${NC}"
            return 1
        fi

        # Check if user exists on system
        if ! id "$username" &>/dev/null; then
            echo -e "${YELLOW}WARNING: User '$username' does not exist on this system${NC}"
            read -p "Continue anyway? (yes/no): " continue_anyway
            if [[ "$continue_anyway" != "yes" ]]; then
                echo "Cancelled."
                return 1
            fi
        fi

        # Check if user already in AllowUsers
        if grep "^AllowUsers" "$SSHD_CONFIG" | grep -qw "$username"; then
            echo -e "${YELLOW}INFO: User '$username' is already in AllowUsers${NC}"
            return 0
        fi

        # Backup config
        backup_file="/var/backups/sshd_config.$(date +%Y%m%d-%H%M%S).bak"
        mkdir -p /var/backups
        cp "$SSHD_CONFIG" "$backup_file"
        echo -e "${GREEN}✓ Backup created: $backup_file${NC}"

        # Add user to AllowUsers
        echo ""
        echo "Adding '$username' to AllowUsers..."
        sed -i "s/^AllowUsers.*/& $username/" "$SSHD_CONFIG"
        echo -e "${GREEN}✓ User added${NC}"
    fi
}

# Function to remove user
remove_user() {
    if ! grep -q "^AllowUsers" "$SSHD_CONFIG"; then
        echo -e "${YELLOW}AllowUsers directive not configured${NC}"
        echo "Nothing to remove."
        return 1
    fi

    echo ""
    show_config
    echo ""

    # Get username to remove
    read -p "Enter username to remove: " username

    if [[ -z "$username" ]]; then
        echo -e "${RED}ERROR: Username is required${NC}"
        return 1
    fi

    # Check if user in AllowUsers
    if ! grep "^AllowUsers" "$SSHD_CONFIG" | grep -qw "$username"; then
        echo -e "${YELLOW}INFO: User '$username' is not in AllowUsers${NC}"
        return 0
    fi

    # Backup config
    backup_file="/var/backups/sshd_config.$(date +%Y%m%d-%H%M%S).bak"
    mkdir -p /var/backups
    cp "$SSHD_CONFIG" "$backup_file"
    echo -e "${GREEN}✓ Backup created: $backup_file${NC}"

    # Remove user from AllowUsers
    echo ""
    echo "Removing '$username' from AllowUsers..."

    # Use sed to remove the username (handle word boundaries)
    sed -i "s/\(^AllowUsers.*\)\<$username\>\s*/\1/" "$SSHD_CONFIG"

    # Clean up extra spaces
    sed -i "s/\(^AllowUsers\)  */\1 /g" "$SSHD_CONFIG"
    sed -i "s/\(^AllowUsers.*\)  *$/\1/" "$SSHD_CONFIG"

    echo -e "${GREEN}✓ User removed${NC}"

    # Check if AllowUsers is now empty
    if grep "^AllowUsers" "$SSHD_CONFIG" | grep -q "^AllowUsers\s*$"; then
        echo -e "${YELLOW}WARNING: AllowUsers is now empty!${NC}"
        echo "This will block ALL SSH access!"
        read -p "Remove AllowUsers directive entirely? (yes/no): " remove_directive

        if [[ "$remove_directive" == "yes" ]]; then
            sed -i "/^AllowUsers\s*$/d" "$SSHD_CONFIG"
            echo -e "${GREEN}✓ AllowUsers directive removed${NC}"
            echo "All users can now login via SSH (less secure)"
        fi
    fi
}

# Main menu
while true; do
    echo ""
    echo -e "${BOLD}Options:${NC}"
    echo "  1) Add user to AllowUsers"
    echo "  2) Remove user from AllowUsers"
    echo "  3) Show current configuration"
    echo "  4) Exit"
    echo ""
    read -p "Choice: " choice

    case $choice in
        1)
            add_user
            action_taken="yes"
            ;;
        2)
            remove_user
            action_taken="yes"
            ;;
        3)
            echo ""
            show_config
            continue
            ;;
        4)
            echo "Exiting."
            exit 0
            ;;
        *)
            echo -e "${RED}Invalid choice${NC}"
            continue
            ;;
    esac

    # If action was taken, test and restart
    if [[ "$action_taken" == "yes" ]]; then
        # Show updated configuration
        echo ""
        echo -e "${BOLD}Updated configuration:${NC}"
        echo "-----------------------------------"
        show_config
        echo ""

        # Test SSH configuration
        echo "Testing SSH configuration..."
        if sshd -t 2>/dev/null; then
            echo -e "${GREEN}✓ SSH configuration is valid${NC}"
        else
            echo -e "${RED}ERROR: SSH configuration test failed!${NC}"
            sshd -t
            continue
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
                echo -e "${GREEN}✓ SSH service restarted successfully${NC}"
                echo ""
                echo -e "${CYAN}=========================================${NC}"
                echo -e "${GREEN}✓ Changes Applied${NC}"
                echo -e "${CYAN}=========================================${NC}"
            else
                echo -e "${RED}ERROR: SSH service failed to start!${NC}"
                echo "Restoring from backup..."
                cp "$backup_file" "$SSHD_CONFIG"
                systemctl restart "$ssh_service"
            fi
        else
            echo ""
            echo "Changes saved but NOT applied."
            echo "To apply manually: sudo systemctl restart ssh"
        fi

        action_taken="no"
    fi
done
