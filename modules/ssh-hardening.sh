#!/bin/bash

################################################################################
# SSH Security Hardening Module
# Description: SSH hardening with user management
################################################################################

configure_ssh_hardening() {
    log_step "SSH Security Hardening..."

    # Detect SSH service name (ssh on Ubuntu, sshd on other systems)
    local ssh_service="ssh"
    if systemctl list-unit-files | grep -q "^sshd.service"; then
        ssh_service="sshd"
    fi
    log_info "Detected SSH service: $ssh_service"

    local sshd_config="/etc/ssh/sshd_config"
    backup_config "$sshd_config"

    # Interactive menu
    echo ""
    echo -e "${BOLD}SSH Security Options:${NC}"
    echo ""
    echo "  1) Quick hardening (recommended)"
    echo "  2) Create SSH user (disable root login)"
    echo "  3) Add/manage SSH keys"
    echo "  4) Change SSH port"
    echo "  5) Setup SFTP user (file transfer only)"
    echo "  6) Show current configuration"
    echo "  7) Cancel"
    echo ""

    read_prompt "Choice [1]: " choice "1"

    case $choice in
        1)
            # Get current user
            local current_user="${SUDO_USER:-$USER}"
            if [[ "$current_user" == "root" ]]; then
                read_prompt "Non-root username for SSH access: " current_user ""
                if [[ -z "$current_user" ]]; then
                    log_error "Username is required"
                    return 1
                fi

                # Check if user exists
                if ! id "$current_user" &>/dev/null; then
                    log_warning "User '$current_user' does not exist"
                    if ask_yes_no "Create user '$current_user'?" "y"; then
                        create_ssh_user "$current_user"
                    else
                        return 1
                    fi
                fi
            fi

            apply_ssh_quick_hardening "$current_user"
            return 0
            ;;
        2)
            create_ssh_user_interactive
            ;;
        3)
            local current_user="${SUDO_USER:-$USER}"
            if [[ "$current_user" == "root" ]]; then
                read_prompt "Username for SSH key management: " current_user ""
                if [[ -z "$current_user" ]] || ! id "$current_user" &>/dev/null; then
                    log_error "Valid username required"
                    return 1
                fi
            fi
            manage_ssh_keys "$current_user"
            return 0
            ;;
        4)
            change_ssh_port
            return 0
            ;;
        5)
            setup_sftp_user
            return 0
            ;;
        6)
            show_ssh_config
            return 0
            ;;
        *)
            log_info "SSH hardening cancelled"
            return 0
            ;;
    esac
}

create_ssh_user_interactive() {
    echo ""
    read_prompt "Enter username: " new_user ""

    if [[ -z "$new_user" ]]; then
        log_error "Username is required"
        return 1
    fi

    # Validate username
    if [[ ! "$new_user" =~ ^[a-z_][a-z0-9_-]*$ ]]; then
        log_error "Invalid username. Use lowercase letters, numbers, hyphens, and underscores"
        return 1
    fi

    # Check if user exists
    if id "$new_user" &>/dev/null; then
        log_warning "User '$new_user' already exists"
        if ask_yes_no "Configure SSH for existing user?" "y"; then
            configure_existing_user "$new_user"
        fi
        return 0
    fi

    create_ssh_user "$new_user"
}

create_ssh_user() {
    local username=$1

    log_info "Creating user '$username'..."

    # Create user with home directory
    useradd -m -s /bin/bash "$username"

    if [[ $? -ne 0 ]]; then
        log_error "Failed to create user"
        return 1
    fi

    log_success "User '$username' created"

    # Generate random password
    log_info "Generating random password for '$username'..."
    local user_password=$(generate_password 24)

    echo "$username:$user_password" | chpasswd

    if [[ $? -eq 0 ]]; then
        echo ""
        echo "========================================="
        echo "  User Credentials (SAVE THIS NOW!)"
        echo "========================================="
        echo ""
        echo "Username: $username"
        echo "Password: $user_password"
        echo ""
        echo "WARNING: This password will NOT be saved!"
        echo "         Copy it now or you will lose access!"
        echo ""
        echo "========================================="
        echo ""
        printf "Press Enter after saving the password..." >/dev/tty
        read -r </dev/tty
        log_success "Password set"
    else
        log_error "Failed to set password"
        return 1
    fi

    # Ask about sudo access
    echo ""
    log_info "User access level options:"
    echo "  1) Normal user (recommended - use 'su' to become root)"
    echo "  2) Sudo user (can use 'sudo' command)"
    echo ""
    read_prompt "Choice [1]: " sudo_choice "1"

    if [[ "$sudo_choice" == "2" ]]; then
        usermod -aG sudo "$username"
        log_success "User added to sudo group"
        log_info "User can use: sudo -i (to become root)"
    else
        log_success "User created as normal user"
        log_info "User can use: su - (to become root with root password)"
    fi

    # Setup SSH directory
    mkdir -p "/home/$username/.ssh"
    chmod 700 "/home/$username/.ssh"
    chown "$username:$username" "/home/$username/.ssh"

    # Ask for SSH key
    echo ""
    if ask_yes_no "Add SSH public key for '$username'?" "y"; then
        echo ""
        log_info "Paste your SSH public key (starts with ssh-rsa or ssh-ed25519):"
        read -r pubkey </dev/tty

        if [[ -n "$pubkey" ]]; then
            echo "$pubkey" > "/home/$username/.ssh/authorized_keys"
            chmod 600 "/home/$username/.ssh/authorized_keys"
            chown "$username:$username" "/home/$username/.ssh/authorized_keys"
            log_success "SSH key added"

            # Ask to disable password auth
            if ask_yes_no "Disable password authentication (keys only)?" "y"; then
                update_ssh_config "PasswordAuthentication" "no"
                update_ssh_config "PubkeyAuthentication" "yes"
                log_success "Password authentication disabled"
            fi
        fi
    fi

    # Disable root login
    if ask_yes_no "Disable root SSH login?" "y"; then
        update_ssh_config "PermitRootLogin" "no"
        log_success "Root login disabled"

        # Add user to AllowUsers
        if grep -q "^AllowUsers" /etc/ssh/sshd_config; then
            if ! grep "^AllowUsers" /etc/ssh/sshd_config | grep -q "$username"; then
                sed -i "s/^AllowUsers.*/& $username/" /etc/ssh/sshd_config
            fi
        else
            echo "AllowUsers $username" >> /etc/ssh/sshd_config
        fi
        log_success "SSH access allowed for '$username'"
    fi

    echo ""
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo -e "${BOLD}User Creation Summary:${NC}"
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo -e "${BOLD}Username:${NC} $username"
    echo -e "${BOLD}Home:${NC} /home/$username"
    echo -e "${BOLD}Shell:${NC} /bin/bash"
    echo -e "${BOLD}Sudo access:${NC} $(groups $username | grep -q sudo && echo 'Yes' || echo 'No')"
    echo -e "${BOLD}SSH key:${NC} $([[ -f "/home/$username/.ssh/authorized_keys" ]] && echo 'Configured' || echo 'Not configured')"
    echo ""
    echo -e "${BOLD}Next steps:${NC}"
    echo -e "  1. Test SSH connection: ${CYAN}ssh $username@$(hostname -I | awk '{print $1}')${NC}"
    echo -e "  2. Switch to new user: ${CYAN}su - $username${NC}"
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo ""

    return 0
}

configure_existing_user() {
    local username=$1

    log_info "Configuring SSH for '$username'..."

    # Setup SSH directory if needed
    if [[ ! -d "/home/$username/.ssh" ]]; then
        mkdir -p "/home/$username/.ssh"
        chmod 700 "/home/$username/.ssh"
        chown "$username:$username" "/home/$username/.ssh"
    fi

    # Ask for SSH key
    if ask_yes_no "Add SSH public key for '$username'?" "y"; then
        echo ""
        log_info "Paste your SSH public key:"
        read -r pubkey </dev/tty

        if [[ -n "$pubkey" ]]; then
            echo "$pubkey" >> "/home/$username/.ssh/authorized_keys"
            chmod 600 "/home/$username/.ssh/authorized_keys"
            chown "$username:$username" "/home/$username/.ssh/authorized_keys"
            log_success "SSH key added"
        fi
    fi

    # Disable root login
    if ask_yes_no "Disable root SSH login?" "y"; then
        update_ssh_config "PermitRootLogin" "no"

        # Add to AllowUsers
        if grep -q "^AllowUsers" /etc/ssh/sshd_config; then
            if ! grep "^AllowUsers" /etc/ssh/sshd_config | grep -q "$username"; then
                sed -i "s/^AllowUsers.*/& $username/" /etc/ssh/sshd_config
            fi
        else
            echo "AllowUsers $username" >> /etc/ssh/sshd_config
        fi

        log_success "SSH configured for '$username'"
    fi
}

apply_ssh_quick_hardening() {
    local current_user="$1"
    local sshd_config="/etc/ssh/sshd_config"

    log_info "Applying SSH security hardening..."

    # Change SSH port
    if ask_yes_no "Change SSH port from default 22?" "y"; then
        echo ""
        read_prompt "Enter new SSH port [2222]: " new_port "2222"

        # Validate port number
        if [[ ! "$new_port" =~ ^[0-9]+$ ]] || [[ "$new_port" -lt 1024 ]] || [[ "$new_port" -gt 65535 ]]; then
            log_error "Invalid port number. Using 2222"
            new_port="2222"
        fi

        update_ssh_config "Port" "$new_port"
        log_success "SSH port changed to $new_port"

        # Configure firewall for new SSH port
        if command_exists ufw; then
            log_info "Configuring firewall for SSH port $new_port..."

            # Allow new SSH port
            ufw allow "$new_port/tcp" comment 'SSH' >> /var/log/ubuntu-setup.log 2>&1
            log_success "Firewall rule added for port $new_port"

            # Enable UFW if not already enabled
            if ! ufw status | grep -q "Status: active"; then
                log_info "Enabling UFW firewall..."
                # Set default policies
                ufw default deny incoming >> /var/log/ubuntu-setup.log 2>&1
                ufw default allow outgoing >> /var/log/ubuntu-setup.log 2>&1
                # Enable firewall
                echo "y" | ufw enable >> /var/log/ubuntu-setup.log 2>&1
                log_success "UFW firewall enabled"
            fi

            # Remove old port 22 rule if new port is different
            if [[ "$new_port" != "22" ]]; then
                if ufw status numbered | grep -q "^\\[[0-9]\\+\\].*22/tcp"; then
                    log_info "Removing old SSH port 22 from firewall..."
                    # Get rule numbers for port 22 and delete them
                    ufw status numbered | grep "22/tcp" | grep -v "# SSH" | awk '{print $1}' | tr -d '[]' | sort -rn | while read rule_num; do
                        echo "y" | ufw delete "$rule_num" >> /var/log/ubuntu-setup.log 2>&1
                    done 2>/dev/null || true
                fi
            fi

            echo ""
            log_info "Current firewall status:"
            ufw status numbered | head -10
        else
            log_warning "UFW not installed. Install Security Tools to enable firewall protection."
        fi

        echo ""
        log_warning "IMPORTANT: You will need to reconnect using port $new_port"
        log_info "New SSH command: ssh -p $new_port user@server"
    else
        log_info "Keeping SSH port 22"
    fi

    # Disable root login
    log_info "Disabling root login..."
    update_ssh_config "PermitRootLogin" "no"
    log_success "Root login disabled"

    # Check for SSH keys
    if [[ -f "/home/$current_user/.ssh/authorized_keys" ]] && [[ -s "/home/$current_user/.ssh/authorized_keys" ]]; then
        log_success "SSH keys found for $current_user"

        if ask_yes_no "Disable password authentication (keys only)?" "y"; then
            update_ssh_config "PasswordAuthentication" "no"
            update_ssh_config "PubkeyAuthentication" "yes"
            log_success "Password authentication disabled (keys only)"
        else
            update_ssh_config "PasswordAuthentication" "yes"
            log_warning "Password authentication still enabled"
        fi
    else
        log_warning "No SSH keys found for $current_user"
        log_info "Keeping password authentication enabled"
        log_info "Add SSH keys first (option 3)"
        update_ssh_config "PasswordAuthentication" "yes"
    fi

    # Disable empty passwords
    update_ssh_config "PermitEmptyPasswords" "no"
    log_success "Empty passwords disabled"

    # Disable X11 forwarding
    update_ssh_config "X11Forwarding" "no"
    log_success "X11 forwarding disabled"

    # Set max auth tries
    update_ssh_config "MaxAuthTries" "3"
    log_success "Max auth tries set to 3"

    # Set login grace time
    update_ssh_config "LoginGraceTime" "30"
    log_success "Login grace time set to 30 seconds"

    # Note: Protocol directive removed in OpenSSH 7.4+ (SSH-2 is the only protocol)
    # No need to set Protocol 2 anymore

    # Configure allowed users
    if grep -q "^AllowUsers" "$sshd_config"; then
        if ! grep "^AllowUsers" "$sshd_config" | grep -q "$current_user"; then
            sed -i "s/^AllowUsers.*/& $current_user/" "$sshd_config"
        fi
    else
        echo "AllowUsers $current_user" >> "$sshd_config"
    fi
    log_success "Allowed users: $current_user"

    # Set client alive settings
    update_ssh_config "ClientAliveInterval" "300"
    update_ssh_config "ClientAliveCountMax" "2"
    log_success "Client alive settings configured"

    # Disable unused features
    update_ssh_config "PermitUserEnvironment" "no"
    update_ssh_config "PermitTunnel" "no"
    update_ssh_config "GatewayPorts" "no"
    log_success "Unused features disabled"

    # Test SSH configuration before restarting
    log_info "Testing SSH configuration..."
    local test_output=$(sshd -t 2>&1)

    if [[ $? -eq 0 ]]; then
        log_success "SSH configuration is valid"

        echo ""
        log_warning "⚠ IMPORTANT: About to restart SSH service"
        log_warning "Current SSH sessions will NOT be disconnected"
        log_warning "But make sure you:"
        echo ""
        log_info "  ✓ Have SSH keys configured (password auth will be disabled)"
        if [[ -n "$new_port" ]] && [[ "$new_port" != "22" ]]; then
            log_info "  ✓ Firewall allows port $new_port (already configured)"
            log_info "  ✓ Will reconnect using: ssh -p $new_port user@server"
        fi
        log_info "  ✓ Have physical/console access if something goes wrong"
        echo ""

        # Get SSH service name
        local ssh_service="ssh"
        if systemctl list-unit-files | grep -q "^sshd.service"; then
            ssh_service="sshd"
        fi

        if ask_yes_no "Apply changes and restart SSH service?" "y"; then
            # Backup config before restart
            backup_config "/etc/ssh/sshd_config"

            # Reload systemd daemon to recognize config changes
            log_info "Reloading systemd daemon..."
            systemctl daemon-reload >> /var/log/ubuntu-setup.log 2>&1

            # Restart SSH service
            log_info "Restarting SSH service..."
            systemctl restart "$ssh_service" >> /var/log/ubuntu-setup.log 2>&1

            # Wait for service to start
            sleep 2

            if systemctl is-active --quiet "$ssh_service"; then
                log_success "SSH service restarted successfully"
                log_success "SSH hardening complete"

                echo ""
                log_warning "🔐 NEXT STEPS:"
                if [[ -n "$new_port" ]] && [[ "$new_port" != "22" ]]; then
                    log_info "  1. Test new connection: ssh -p $new_port user@server"
                else
                    log_info "  1. Test new connection in another terminal"
                fi
                log_info "  2. Verify you can login before closing this session"
                log_info "  3. Keep this terminal open until confirmed working"
                echo ""
            else
                log_error "SSH service failed to start!"
                log_info "Checking service status..."
                systemctl status "$ssh_service" --no-pager --lines=15

                log_info "Restoring previous configuration..."
                local backup_dir="/var/backups/ubuntu-setup"
                local backup_file=$(ls -t "$backup_dir/sshd_config."*.bak 2>/dev/null | head -1)

                if [[ -n "$backup_file" ]] && [[ -f "$backup_file" ]]; then
                    cp "$backup_file" "/etc/ssh/sshd_config"
                    log_info "Restored from: $backup_file"
                    systemctl restart "$ssh_service" >> /var/log/ubuntu-setup.log 2>&1

                    sleep 2
                    if systemctl is-active --quiet "$ssh_service"; then
                        log_success "SSH service restored to previous configuration"
                        log_warning "SSH hardening was rolled back due to errors"
                    else
                        log_error "Failed to restore SSH service"
                        log_error "Manual intervention required!"
                        log_info "Check: journalctl -u $ssh_service -n 50"
                    fi
                else
                    log_error "No backup found. SSH may be in invalid state!"
                    log_info "Manual fix required: /etc/ssh/sshd_config"
                fi
                return 1
            fi
        else
            log_warning "SSH service NOT restarted"
            log_info "Changes saved to /etc/ssh/sshd_config but not applied"
            log_info "To apply manually: sudo systemctl restart $ssh_service"
        fi
    else
        log_error "SSH configuration test failed!"
        log_info "Errors:"
        echo "$test_output"
        log_error "SSH hardening aborted - no changes applied"
        return 1
    fi
}

update_ssh_config() {
    local key="$1"
    local value="$2"
    local sshd_config="/etc/ssh/sshd_config"

    # Check if key exists (commented or uncommented, with optional spaces)
    if grep -qE "^[[:space:]]*#?[[:space:]]*${key}[[:space:]]" "$sshd_config"; then
        # Show what we're replacing (for debugging)
        local old_line=$(grep -E "^[[:space:]]*#?[[:space:]]*${key}[[:space:]]" "$sshd_config" | head -1)
        log_info "Updating: '$old_line' → '${key} ${value}'"

        # Replace existing line (handles #Port 22, Port 22, # Port 22, etc.)
        sed -i "s|^[[:space:]]*#*[[:space:]]*${key}[[:space:]].*|${key} ${value}|" "$sshd_config"

        # Verify the change
        local new_line=$(grep -E "^${key}[[:space:]]" "$sshd_config" | head -1)
        if [[ -n "$new_line" ]]; then
            log_success "Verified: $new_line"
        else
            log_warning "Could not verify change in config file"
        fi
    else
        # Append new line
        log_info "Adding new line: ${key} ${value}"
        echo "${key} ${value}" >> "$sshd_config"
    fi
}

manage_ssh_keys() {
    local current_user="$1"

    echo ""
    echo -e "${BOLD}SSH Key Management:${NC}"
    echo ""
    echo "  1) Add SSH public key"
    echo "  2) Show current keys"
    echo "  3) Remove a key"
    echo "  4) Generate new SSH key pair"
    echo ""

    read_prompt "Choice: " key_choice ""

    case $key_choice in
        1)
            echo ""
            log_info "Paste your public key (starts with ssh-rsa or ssh-ed25519):"
            read -r pubkey </dev/tty

            if [[ -z "$pubkey" ]]; then
                log_error "No key provided"
                return 1
            fi

            mkdir -p "/home/$current_user/.ssh"
            echo "$pubkey" >> "/home/$current_user/.ssh/authorized_keys"
            chmod 700 "/home/$current_user/.ssh"
            chmod 600 "/home/$current_user/.ssh/authorized_keys"
            chown -R "$current_user:$current_user" "/home/$current_user/.ssh"

            log_success "SSH key added for $current_user"
            ;;

        2)
            echo ""
            if [[ -f "/home/$current_user/.ssh/authorized_keys" ]]; then
                log_info "Authorized keys for $current_user:"
                cat -n "/home/$current_user/.ssh/authorized_keys"
            else
                log_warning "No keys found"
            fi
            ;;

        3)
            if [[ ! -f "/home/$current_user/.ssh/authorized_keys" ]]; then
                log_warning "No keys found"
                return 1
            fi

            echo ""
            log_info "Current keys:"
            cat -n "/home/$current_user/.ssh/authorized_keys"
            echo ""
            read_prompt "Enter line number to remove: " line_num ""

            if [[ "$line_num" =~ ^[0-9]+$ ]]; then
                sed -i "${line_num}d" "/home/$current_user/.ssh/authorized_keys"
                log_success "Key removed"
            else
                log_error "Invalid line number"
            fi
            ;;

        4)
            echo ""
            log_info "Generating SSH key pair..."
            read_prompt "Key name [id_ed25519]: " keyname "id_ed25519"

            sudo -u "$current_user" ssh-keygen -t ed25519 -f "/home/$current_user/.ssh/$keyname" -C "$current_user@$(hostname)"

            if [[ $? -eq 0 ]]; then
                log_success "Key pair generated"
                echo ""
                log_info "Public key:"
                cat "/home/$current_user/.ssh/$keyname.pub"
            fi
            ;;
    esac

    return 0
}

change_ssh_port() {
    # Detect SSH service name
    local ssh_service="ssh"
    if systemctl list-unit-files | grep -q "^sshd.service"; then
        ssh_service="sshd"
    fi

    local sshd_config="/etc/ssh/sshd_config"
    local current_port=$(grep "^Port" "$sshd_config" | awk '{print $2}')
    current_port=${current_port:-22}

    log_info "Current SSH port: $current_port"

    read_prompt "New SSH port [22]: " new_port "22"

    if [[ ! "$new_port" =~ ^[0-9]+$ ]] || [[ "$new_port" -lt 1024 ]] || [[ "$new_port" -gt 65535 ]]; then
        log_error "Invalid port number (must be 1024-65535)"
        return 1
    fi

    update_ssh_config "Port" "$new_port"
    log_success "SSH port changed to $new_port"

    # Update firewall
    if command -v ufw &>/dev/null && ufw status | grep -q "Status: active"; then
        ufw allow "$new_port/tcp" comment 'SSH' >> /var/log/ubuntu-setup.log 2>&1
        if [[ "$new_port" != "22" ]]; then
            ufw delete allow 22/tcp >> /var/log/ubuntu-setup.log 2>&1
        fi
        log_success "Firewall updated"
    fi

    log_warning "You will need to reconnect using port $new_port"
    log_info "Command: ssh -p $new_port user@server"

    return 0
}

show_ssh_config() {
    local sshd_config="/etc/ssh/sshd_config"

    echo ""
    log_info "Current SSH Configuration:"
    echo ""

    grep -E "^(Port|PermitRootLogin|PasswordAuthentication|PubkeyAuthentication|AllowUsers)" "$sshd_config" | while read line; do
        echo -e "  ${CYAN}$line${NC}"
    done

    echo ""
}

################################################################################
# SFTP Configuration
################################################################################

setup_sftp_user() {
    log_info "SFTP User Setup (File Transfer Only)"
    echo ""

    # Get username
    read_prompt "SFTP username: " sftp_user ""
    if [[ -z "$sftp_user" ]]; then
        log_error "Username is required"
        return 1
    fi

    # Check if user exists
    if id "$sftp_user" &>/dev/null; then
        log_warning "User '$sftp_user' already exists"
        if ! ask_yes_no "Configure existing user for SFTP?" "y"; then
            return 0
        fi
        local user_exists=true
    else
        local user_exists=false
    fi

    # SFTP directory
    local sftp_root="/sftp"
    read_prompt "SFTP root directory [$sftp_root]: " sftp_root "$sftp_root"

    local user_home="$sftp_root/$sftp_user"
    local upload_dir="$user_home/upload"

    # Create user if not exists
    if [[ "$user_exists" == false ]]; then
        log_info "Creating SFTP user '$sftp_user'..."

        # Create user with no shell (SFTP only)
        useradd -m -d "$user_home" -s /usr/sbin/nologin "$sftp_user"

        if [[ $? -ne 0 ]]; then
            log_error "Failed to create user"
            return 1
        fi

        log_success "User '$sftp_user' created"

        # Set password
        log_info "Generating random password..."
        local user_password=$(generate_password 24)

        echo "$sftp_user:$user_password" | chpasswd

        if [[ $? -eq 0 ]]; then
            echo ""
            echo "========================================="
            echo "  SFTP User Credentials (SAVE THIS!)"
            echo "========================================="
            echo ""
            echo "Username: $sftp_user"
            echo "Password: $user_password"
            echo "SFTP Directory: $upload_dir"
            echo ""
            echo "WARNING: Password will NOT be saved!"
            echo ""
            echo "Connect with: sftp $sftp_user@server"
            echo "========================================="
            echo ""
            printf "Press Enter after saving..." >/dev/tty
            read -r </dev/tty
            log_success "Password set"
        else
            log_error "Failed to set password"
            return 1
        fi
    fi

    # Create SFTP directory structure
    log_info "Setting up SFTP directory structure..."

    # Create root (owned by root)
    mkdir -p "$sftp_root"
    chown root:root "$sftp_root"
    chmod 755 "$sftp_root"

    # Create user home (owned by root for chroot)
    mkdir -p "$user_home"
    chown root:root "$user_home"
    chmod 755 "$user_home"

    # Create upload directory (owned by user)
    mkdir -p "$upload_dir"
    chown "$sftp_user:$sftp_user" "$upload_dir"
    chmod 755 "$upload_dir"

    log_success "Directory structure created"
    log_info "  Root: $sftp_root (root:root)"
    log_info "  Home: $user_home (root:root)"
    log_info "  Upload: $upload_dir ($sftp_user:$sftp_user)"

    # Configure SSH for SFTP
    log_info "Configuring SSH for SFTP..."

    local sshd_config="/etc/ssh/sshd_config"
    backup_config "$sshd_config"

    # Check if SFTP subsystem is configured
    if ! grep -q "^Subsystem[[:space:]]*sftp" "$sshd_config"; then
        echo "Subsystem sftp internal-sftp" >> "$sshd_config"
    fi

    # Add Match User block for chroot
    if ! grep -q "Match User $sftp_user" "$sshd_config"; then
        cat >> "$sshd_config" << EOF

# SFTP chroot for $sftp_user
Match User $sftp_user
    ChrootDirectory $user_home
    ForceCommand internal-sftp
    AllowTcpForwarding no
    X11Forwarding no
    PermitTunnel no
EOF
        log_success "SFTP configuration added"
    else
        log_warning "SFTP configuration already exists for $sftp_user"
    fi

    # Test configuration
    log_info "Testing SSH configuration..."
    local test_output=$(sshd -t 2>&1)

    if [[ $? -eq 0 ]]; then
        log_success "SSH configuration is valid"

        # Restart SSH
        echo ""
        if ask_yes_no "Restart SSH to apply SFTP configuration?" "y"; then
            # Detect SSH service name
            local ssh_service="ssh"
            if systemctl list-unit-files | grep -q "^sshd.service"; then
                ssh_service="sshd"
            fi

            systemctl daemon-reload >> /var/log/ubuntu-setup.log 2>&1
            systemctl restart "$ssh_service" >> /var/log/ubuntu-setup.log 2>&1
            sleep 2

            if systemctl is-active --quiet "$ssh_service"; then
                log_success "SSH service restarted successfully"

                echo ""
                log_success "SFTP User Setup Complete!"
                echo ""
                log_info "Connection details:"
                echo "  Command: sftp $sftp_user@$(hostname -I | awk '{print $1}')"
                echo "  Upload to: /upload directory"
                echo ""
                log_info "Test connection:"
                echo "  sftp> cd upload"
                echo "  sftp> put yourfile.txt"
                echo ""
            else
                log_error "SSH service failed to start"
                return 1
            fi
        fi
    else
        log_error "SSH configuration test failed!"
        echo "$test_output"
        return 1
    fi

    return 0
}
