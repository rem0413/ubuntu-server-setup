#!/bin/bash

# PM2 installation
install_pm2() {
    log_info "Installing PM2..."

    # Check if Node.js is installed
    if ! command_exists node; then
        log_error "Node.js is required for PM2. Please install Node.js first."
        return 1
    fi

    # Check if npm is installed
    if ! command_exists npm; then
        log_error "npm is required for PM2. Please install Node.js with npm first."
        return 1
    fi

    log_info "Node.js version: $(node --version)"
    log_info "npm version: $(npm --version)"

    # Check if already installed
    if command_exists pm2; then
        local version=$(pm2 --version 2>/dev/null || echo "unknown")
        log_info "PM2 $version already installed"
        if ask_yes_no "Reinstall PM2?" "n"; then
            log_info "Proceeding with reinstallation..."
            npm uninstall -g pm2 >> "$LOG_FILE" 2>&1
        else
            return 0
        fi
    fi

    # Install PM2 globally
    log_info "Installing PM2 globally via npm..."
    npm install -g pm2 >> "$LOG_FILE" 2>&1

    if [[ $? -ne 0 ]]; then
        log_error "Failed to install PM2"
        log_info "Checking npm install error..."
        tail -20 "$LOG_FILE"
        return 1
    fi

    # Get npm global bin path
    local npm_bin=$(npm bin -g 2>/dev/null || echo "/usr/local/bin")
    log_info "npm global bin: $npm_bin"

    # Refresh PATH to pick up newly installed pm2
    export PATH="$npm_bin:$PATH:/usr/local/bin:/usr/bin"
    hash -r 2>/dev/null || true

    # Ensure PM2 is accessible globally for all users
    if [[ -f "$npm_bin/pm2" ]]; then
        # Create symlink to /usr/local/bin (in all users' PATH)
        ln -sf "$npm_bin/pm2" /usr/local/bin/pm2 2>/dev/null || true
        chmod +x /usr/local/bin/pm2 2>/dev/null || true
        log_info "PM2 symlinked to /usr/local/bin/pm2 (global access)"
    fi

    # Add npm bin to global PATH if not already there
    if ! grep -q "$npm_bin" /etc/environment 2>/dev/null; then
        # Backup /etc/environment
        cp /etc/environment /etc/environment.bak.$(date +%Y%m%d_%H%M%S) 2>/dev/null || true

        # Add npm bin to PATH in /etc/environment
        if grep -q "^PATH=" /etc/environment; then
            sed -i "s|PATH=\"|PATH=\"$npm_bin:|" /etc/environment
        else
            echo "PATH=\"$npm_bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin\"" >> /etc/environment
        fi
        log_info "Added npm bin to global PATH in /etc/environment"
    fi

    # Wait a moment for installation to complete
    sleep 2

    # Verify installation with multiple methods
    log_info "Verifying PM2 installation..."

    # Method 1: Check if pm2 command exists
    if command -v pm2 >/dev/null 2>&1; then
        local version=$(pm2 --version 2>/dev/null || echo "unknown")
        log_success "PM2 $version installed successfully"
    # Method 2: Check npm global packages
    elif npm list -g pm2 2>/dev/null | grep -q pm2; then
        log_success "PM2 installed via npm (found in global packages)"
        # Try to get version from npm
        local version=$(npm list -g pm2 2>/dev/null | grep pm2 | awk '{print $2}' | sed 's/@//')
        log_info "PM2 version: $version"
    else
        log_error "PM2 installation verification failed"
        log_info "Debugging information:"
        log_info "PATH: $PATH"
        log_info "which pm2: $(which pm2 2>&1 || echo 'not found')"
        log_info "npm global packages:"
        npm list -g --depth=0 2>&1 | grep -i pm2 || echo "PM2 not found in global packages"
        return 1
    fi

    # Setup PM2 startup script
    # Get the actual user (not root)
    local actual_user="${SUDO_USER:-$USER}"

    if [[ "$actual_user" == "root" ]]; then
        log_warning "PM2 installed globally - startup should be configured per user"
        log_info ""
        log_info "To configure PM2 startup for a user, run as that user:"
        log_info "  su - username"
        log_info "  pm2 startup"
        log_info "  # Then run the command it gives you"
        log_info "  pm2 save"
        log_info ""
    else
        if ask_yes_no "Setup PM2 startup script for user '$actual_user'?" "n"; then
            setup_pm2_startup || {
                log_warning "PM2 startup configuration failed or skipped"
                log_info "You can configure it manually later:"
                log_info "  su - $actual_user"
                log_info "  pm2 startup"
                log_info "  # Run the command it shows"
                log_info "  pm2 save"
            }
        else
            log_info "PM2 startup configuration skipped"
            log_info "Configure later with: pm2 startup"
        fi
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

    # Save to summary
    local pm2_version=$(pm2 --version 2>/dev/null || echo "unknown")
    cat >> /root/ubuntu-setup-summary.txt << EOF

PM2 Process Manager:
  Version: $pm2_version
  Installed: Globally (npm)
  Command: pm2

  Usage:
    pm2 start app.js              # Start application
    pm2 list                      # List all processes
    pm2 logs                      # View logs
    pm2 restart all               # Restart all apps
    pm2 stop all                  # Stop all apps
    pm2 delete all                # Remove all apps

  Startup (per user):
    su - username
    pm2 startup                   # Get startup command
    # Run the command it gives you
    pm2 save                      # Save process list

EOF

    log_info "PM2 information saved to: /root/ubuntu-setup-summary.txt"

    return 0
}

# Setup PM2 startup script
setup_pm2_startup() {
    log_info "Setting up PM2 startup script..."

    # Get the actual user (not root)
    local actual_user="${SUDO_USER:-$USER}"

    # This function should only be called when actual_user is not root
    # The check is done in the caller function
    if [[ "$actual_user" == "root" ]]; then
        log_info "Skipping PM2 startup - should be configured per user"
        return 0
    fi

    log_info "Configuring PM2 for user: $actual_user"

    # Detect init system
    local startup_system
    if command_exists systemctl; then
        startup_system="systemd"
    elif command_exists initctl; then
        startup_system="upstart"
    else
        startup_system="systemv"
    fi
    log_info "Detected init system: $startup_system"

    # Generate startup script
    log_info "Generating PM2 startup command..."

    # Get npm bin path and ensure pm2 is accessible
    local npm_bin=$(npm bin -g 2>/dev/null || echo "/usr/local/bin")
    local pm2_path=$(which pm2 2>/dev/null || echo "$npm_bin/pm2")

    if [[ ! -f "$pm2_path" ]]; then
        log_error "PM2 executable not found at: $pm2_path"
        log_info "PM2 might not be properly installed or in PATH"
        return 1
    fi

    log_info "Using PM2 at: $pm2_path"

    # Run pm2 startup with explicit path
    local startup_output=$(sudo -u "$actual_user" env PATH="$npm_bin:$PATH" "$pm2_path" startup "$startup_system" -u "$actual_user" --hp $(eval echo ~$actual_user) 2>&1)
    local startup_cmd=$(echo "$startup_output" | grep "sudo env")

    if [[ -n "$startup_cmd" ]]; then
        log_info "Executing startup command..."
        log_info "Command: $startup_cmd"

        eval "$startup_cmd" >> "$LOG_FILE" 2>&1
        local result=$?

        if [[ $result -eq 0 ]]; then
            log_success "PM2 startup script configured for $actual_user"
            log_info "PM2 will now start automatically on system boot"

            # Save PM2 process list
            log_info "Saving PM2 process list..."
            sudo -u "$actual_user" env PATH="$npm_bin:$PATH" "$pm2_path" save >> "$LOG_FILE" 2>&1
            if [[ $? -eq 0 ]]; then
                log_success "PM2 process list saved"
            else
                log_warning "Failed to save PM2 process list (no processes running yet)"
            fi
        else
            log_error "Failed to configure PM2 startup script"
            log_info "Startup command output:"
            echo "$startup_output"
            log_info "Last 20 lines of log:"
            tail -20 "$LOG_FILE"
            return 1
        fi
    else
        log_error "Could not generate PM2 startup command"
        log_info "PM2 startup output:"
        echo "$startup_output"
        log_info "This might happen if:"
        log_info "  - PM2 is not properly installed"
        log_info "  - User $actual_user doesn't have proper permissions"
        log_info "  - PM2 version is incompatible"
        log_info "You can manually configure startup later with: pm2 startup"
        return 1
    fi

    return 0
}
