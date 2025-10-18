#!/bin/bash

# MongoDB installation
install_mongodb() {
    log_info "Installing MongoDB..."

    # Check if already installed
    if command_exists mongod; then
        local version=$(get_version mongod)
        log_info "MongoDB $version already installed"
        if ask_yes_no "Reinstall MongoDB?" "n"; then
            log_info "Proceeding with reinstallation..."
        else
            return 0
        fi
    fi

    # Ask for custom port
    local mongodb_port=$(get_input "MongoDB port" "27017")
    if ! [[ "$mongodb_port" =~ ^[0-9]+$ ]] || [[ "$mongodb_port" -lt 1024 ]] || [[ "$mongodb_port" -gt 65535 ]]; then
        log_warning "Invalid port number. Using default 27017"
        mongodb_port="27017"
    fi

    # Import MongoDB public GPG key
    log_info "Adding MongoDB repository..."
    curl -fsSL https://www.mongodb.org/static/pgp/server-7.0.asc | \
        sudo gpg --dearmor -o /usr/share/keyrings/mongodb-server-7.0.gpg >> "$LOG_FILE" 2>&1

    if [[ $? -ne 0 ]]; then
        log_error "Failed to add MongoDB GPG key"
        return 1
    fi

    # Add MongoDB repository (use jammy for noble compatibility)
    local ubuntu_codename=$(lsb_release -cs)
    if [[ "$ubuntu_codename" == "noble" ]]; then
        ubuntu_codename="jammy"
        log_info "Using jammy repository for Ubuntu 24.04 compatibility"
    fi

    echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg ] https://repo.mongodb.org/apt/ubuntu ${ubuntu_codename}/mongodb-org/7.0 multiverse" | \
        sudo tee /etc/apt/sources.list.d/mongodb-org-7.0.list >> "$LOG_FILE"

    # Update package lists
    update_system || return 1

    # Install MongoDB
    install_package "mongodb-org" || return 1

    # Configure port if not default
    if [[ "$mongodb_port" != "27017" ]]; then
        backup_config "/etc/mongod.conf"
        sed -i "s/port: 27017/port: $mongodb_port/" /etc/mongod.conf
        log_success "MongoDB port set to $mongodb_port"
    fi

    # Start and enable MongoDB service
    log_info "Starting MongoDB service..."
    systemctl start mongod >> "$LOG_FILE" 2>&1
    systemctl enable mongod >> "$LOG_FILE" 2>&1

    if systemctl is-active --quiet mongod; then
        log_success "MongoDB service started and enabled"
    else
        log_error "Failed to start MongoDB service"
        return 1
    fi

    # Configure MongoDB
    if ask_yes_no "Configure MongoDB admin user?" "y"; then
        configure_mongodb_user "$mongodb_port"
    fi

    # Show MongoDB status
    local version=$(get_version mongod)
    log_success "MongoDB $version installed successfully"

    return 0
}

# Configure MongoDB admin user
configure_mongodb_user() {
    local mongodb_port="$1"
    log_info "Configuring MongoDB admin user..."

    local admin_user=$(get_input "Admin username" "admin")

    # Generate random password
    local admin_pass=$(generate_password 20)
    log_info "Generated random password (20 characters)"

    # Create admin user
    mongosh --port "$mongodb_port" admin --eval "
        db.createUser({
            user: '$admin_user',
            pwd: '$admin_pass',
            roles: [
                { role: 'userAdminAnyDatabase', db: 'admin' },
                { role: 'readWriteAnyDatabase', db: 'admin' },
                { role: 'dbAdminAnyDatabase', db: 'admin' }
            ]
        })
    " >> "$LOG_FILE" 2>&1

    if [[ $? -eq 0 ]]; then
        # Display credentials on screen (not saved to file)
        echo ""
        echo -e "${BOLD}${GREEN}═══════════════════════════════════════════════════${NC}"
        echo -e "${BOLD}${GREEN}       MongoDB Credentials (SAVE THIS NOW!)${NC}"
        echo -e "${BOLD}${GREEN}═══════════════════════════════════════════════════${NC}"
        echo ""
        echo -e "${BOLD}Username:${NC} ${CYAN}$admin_user${NC}"
        echo -e "${BOLD}Password:${NC} ${CYAN}$admin_pass${NC}"
        echo -e "${BOLD}Port:${NC}     ${CYAN}$mongodb_port${NC}"
        echo ""
        echo -e "${YELLOW}Connection string:${NC}"
        echo -e "${DIM}mongodb://$admin_user:$admin_pass@localhost:$mongodb_port/admin${NC}"
        echo ""
        echo -e "${RED}${BOLD}⚠ WARNING:${NC} ${RED}This password will NOT be saved to any file!${NC}"
        echo -e "${RED}           Copy it now or you will lose access!${NC}"
        echo ""
        echo -e "${BOLD}${GREEN}═══════════════════════════════════════════════════${NC}"
        echo ""

        # Wait for user to copy
        echo -n "Press Enter after you have saved these credentials..."
        read -r

        log_success "MongoDB admin user created: $admin_user"

        # Enable authentication
        if ask_yes_no "Enable authentication?" "y"; then
            backup_config "/etc/mongod.conf"

            if grep -q "^security:" /etc/mongod.conf; then
                sed -i '/^security:/a\  authorization: enabled' /etc/mongod.conf
            else
                echo -e "\nsecurity:\n  authorization: enabled" >> /etc/mongod.conf
            fi

            systemctl restart mongod >> "$LOG_FILE" 2>&1
            log_success "MongoDB authentication enabled"
        fi
    else
        log_error "Failed to create MongoDB admin user"
        return 1
    fi

    return 0
}
