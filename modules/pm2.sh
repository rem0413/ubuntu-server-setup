#!/bin/bash

# PM2 installation
install_pm2() {
    log_info "Installing PM2..."

    # Check if Node.js is installed
    if ! command_exists node; then
        log_error "Node.js is required for PM2. Please install Node.js first."
        return 1
    fi

    # Check if already installed
    if command_exists pm2; then
        local version=$(get_version pm2)
        log_info "PM2 $version already installed"
        if ask_yes_no "Reinstall PM2?" "n"; then
            log_info "Proceeding with reinstallation..."
            npm uninstall -g pm2 >> "$LOG_FILE" 2>&1
        else
            return 0
        fi
    fi

    # Install PM2 globally
    log_info "Installing PM2 globally..."
    npm install -g pm2 >> "$LOG_FILE" 2>&1

    if [[ $? -ne 0 ]]; then
        log_error "Failed to install PM2"
        return 1
    fi

    # Verify installation
    if command_exists pm2; then
        local version=$(get_version pm2)
        log_success "PM2 $version installed successfully"
    else
        log_error "PM2 installation verification failed"
        return 1
    fi

    # Setup PM2 startup script
    if ask_yes_no "Setup PM2 startup script?" "y"; then
        setup_pm2_startup
    fi

    # Configure PM2 log rotation
    if ask_yes_no "Install PM2 log rotation module?" "y"; then
        pm2 install pm2-logrotate >> "$LOG_FILE" 2>&1
        log_success "PM2 log rotation installed"

        # Configure log rotation
        pm2 set pm2-logrotate:max_size 10M >> "$LOG_FILE" 2>&1
        pm2 set pm2-logrotate:retain 7 >> "$LOG_FILE" 2>&1
        log_info "Log rotation configured: 10MB max, 7 days retention"
    fi

    return 0
}

# Setup PM2 startup script
setup_pm2_startup() {
    log_info "Setting up PM2 startup script..."

    # Get the actual user (not root)
    local actual_user="${SUDO_USER:-$USER}"

    # Detect init system
    local startup_system
    if command_exists systemctl; then
        startup_system="systemd"
    elif command_exists initctl; then
        startup_system="upstart"
    else
        startup_system="systemv"
    fi

    # Generate startup script
    local startup_cmd=$(sudo -u "$actual_user" pm2 startup "$startup_system" -u "$actual_user" --hp $(eval echo ~$actual_user) 2>&1 | grep "sudo")

    if [[ -n "$startup_cmd" ]]; then
        eval "$startup_cmd" >> "$LOG_FILE" 2>&1
        if [[ $? -eq 0 ]]; then
            log_success "PM2 startup script configured for $actual_user"
            log_info "PM2 will now start automatically on system boot"

            # Save PM2 process list
            sudo -u "$actual_user" pm2 save >> "$LOG_FILE" 2>&1
            log_info "PM2 process list saved"
        else
            log_error "Failed to configure PM2 startup script"
            return 1
        fi
    else
        log_warning "Could not generate PM2 startup command"
        return 1
    fi

    return 0
}
