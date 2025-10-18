#!/bin/bash

################################################################################
# SSH Security Hardening Module
# Description: SSH hardening with user management
################################################################################

configure_ssh_hardening() {
    log_step "SSH Security Hardening..."

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
    echo "  5) Show current configuration"
    echo "  6) Cancel"
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
            ;;
        5)
            show_ssh_config
            return 0
            ;;
        *)
            log_info "SSH hardening cancelled"
            return 0
            ;;
    esac

    # Test SSH configuration
    log_info "Testing SSH configuration..."
    local test_output=$(sshd -t 2>&1)
    local test_result=$?

    if [[ $test_result -eq 0 ]]; then
        log_success "SSH configuration is valid"

        echo ""
        log_warning "About to restart SSH service"
        log_warning "Make sure you have:"
        log_info "  - SSH keys configured (if password auth disabled)"
        log_info "  - Another terminal session open"
        log_info "  - Physical/console access if needed"
        echo ""

        if ask_yes_no "Restart SSH service?" "n"; then
            systemctl restart sshd >> /var/log/ubuntu-setup.log 2>&1

            # Wait for service to start
            sleep 2

            if systemctl is-active --quiet sshd; then
                log_success "SSH service restarted successfully"
                log_warning "Test your SSH connection NOW in a new terminal!"
                return 0
            else
                log_error "SSH service failed to start"
                log_info "Service status:"
                systemctl status sshd --no-pager --lines=20
                log_info "Recent logs:"
                journalctl -u sshd -n 30 --no-pager
                log_info "Configuration test:"
                sshd -t 2>&1

                log_info "Restoring backup..."
                local backup_file=$(ls -t "$sshd_config.bak."* 2>/dev/null | head -1)
                if [[ -f "$backup_file" ]]; then
                    cp "$backup_file" "$sshd_config"
                    log_info "Restored from: $backup_file"
                    systemctl restart sshd >> /var/log/ubuntu-setup.log 2>&1
                    if systemctl is-active --quiet sshd; then
                        log_success "SSH service restored successfully"
                    else
                        log_error "Failed to restore SSH service"
                    fi
                else
                    log_error "No backup file found to restore"
                fi
                return 1
            fi
        else
            log_info "SSH not restarted. Apply manually: sudo systemctl restart sshd"
        fi
    else
        log_error "SSH configuration test failed"
        log_info "Configuration errors:"
        echo "$test_output"
        log_info "Please fix the errors above and try again"
        return 1
    fi

    return 0
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

    # Add to sudo group
    if ask_yes_no "Add '$username' to sudo group?" "y"; then
        usermod -aG sudo "$username"
        log_success "User added to sudo group"
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

    # Enforce SSH Protocol 2
    update_ssh_config "Protocol" "2"
    log_success "SSH Protocol 2 enforced"

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

    log_success "SSH hardening complete"
}

update_ssh_config() {
    local key="$1"
    local value="$2"
    local sshd_config="/etc/ssh/sshd_config"

    if grep -q "^#*${key}" "$sshd_config"; then
        sed -i "s/^#*${key}.*/${key} ${value}/" "$sshd_config"
    else
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
