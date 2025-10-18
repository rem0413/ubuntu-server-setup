#!/bin/bash

# Security tools installation
install_security() {
    log_info "Installing security tools..."

    # Install UFW (Uncomplicated Firewall)
    if ! is_installed "ufw"; then
        install_package "ufw" || return 1
        log_success "UFW installed"

        if ask_yes_no "Configure UFW firewall?" "y"; then
            configure_ufw
        fi
    else
        log_info "UFW already installed"
    fi

    # Install Fail2ban
    if ! is_installed "fail2ban"; then
        if ask_yes_no "Install Fail2ban?" "y"; then
            install_fail2ban
        fi
    else
        log_info "Fail2ban already installed"
    fi

    return 0
}

# Configure UFW firewall
configure_ufw() {
    log_info "Configuring UFW firewall..."

    # Set default policies
    ufw default deny incoming >> "$LOG_FILE" 2>&1
    ufw default allow outgoing >> "$LOG_FILE" 2>&1

    # Allow SSH
    local ssh_port=$(get_input "SSH port" "22")
    ufw allow "$ssh_port/tcp" comment 'SSH' >> "$LOG_FILE" 2>&1
    log_success "SSH port $ssh_port allowed"

    # Ask about common ports
    if ask_yes_no "Allow HTTP (80)?" "y"; then
        ufw allow 80/tcp comment 'HTTP' >> "$LOG_FILE" 2>&1
        log_success "HTTP port 80 allowed"
    fi

    if ask_yes_no "Allow HTTPS (443)?" "y"; then
        ufw allow 443/tcp comment 'HTTPS' >> "$LOG_FILE" 2>&1
        log_success "HTTPS port 443 allowed"
    fi

    # Ask about database ports
    if command_exists mongod; then
        if ask_yes_no "Allow MongoDB (27017)?" "n"; then
            ufw allow 27017/tcp comment 'MongoDB' >> "$LOG_FILE" 2>&1
            log_success "MongoDB port 27017 allowed"
        fi
    fi

    if command_exists psql; then
        if ask_yes_no "Allow PostgreSQL (5432)?" "n"; then
            ufw allow 5432/tcp comment 'PostgreSQL' >> "$LOG_FILE" 2>&1
            log_success "PostgreSQL port 5432 allowed"
        fi
    fi

    # Enable UFW
    echo "y" | ufw enable >> "$LOG_FILE" 2>&1
    log_success "UFW firewall enabled"

    # Show UFW status
    log_info "Current firewall rules:"
    ufw status numbered

    return 0
}

# Install and configure Fail2ban
install_fail2ban() {
    log_info "Installing Fail2ban..."

    install_package "fail2ban" || return 1

    # Start and enable service
    systemctl start fail2ban >> "$LOG_FILE" 2>&1
    systemctl enable fail2ban >> "$LOG_FILE" 2>&1

    if systemctl is-active --quiet fail2ban; then
        log_success "Fail2ban service started and enabled"
    else
        log_error "Failed to start Fail2ban service"
        return 1
    fi

    # Configure Fail2ban
    if ask_yes_no "Configure Fail2ban for SSH?" "y"; then
        configure_fail2ban
    fi

    return 0
}

# Configure Fail2ban
configure_fail2ban() {
    log_info "Configuring Fail2ban..."

    local jail_local="/etc/fail2ban/jail.local"
    backup_config "$jail_local"

    # Create jail.local configuration
    cat > "$jail_local" << 'EOF'
[DEFAULT]
# Ban for 1 hour
bantime = 3600

# Find time window (10 minutes)
findtime = 600

# Max retry attempts
maxretry = 5

# Destination email for notifications
destemail = root@localhost

# Sender email
sender = fail2ban@localhost

# Action to take
action = %(action_)s

[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 7200
EOF

    log_success "Fail2ban configuration created"

    # Restart Fail2ban
    systemctl restart fail2ban >> "$LOG_FILE" 2>&1
    log_success "Fail2ban restarted with new configuration"

    # Show Fail2ban status
    log_info "Fail2ban status:"
    fail2ban-client status sshd 2>/dev/null || log_warning "Could not get Fail2ban status"

    return 0
}
