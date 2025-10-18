#!/bin/bash

# PostgreSQL installation
install_postgresql() {
    log_info "Installing PostgreSQL..."

    # Check if already installed
    if command_exists psql; then
        local version=$(get_version psql)
        log_info "PostgreSQL $version already installed"
        if ask_yes_no "Reinstall PostgreSQL?" "n"; then
            log_info "Proceeding with reinstallation..."
        else
            return 0
        fi
    fi

    # Ask for custom port
    local pg_port=$(get_input "PostgreSQL port" "5432")
    if ! [[ "$pg_port" =~ ^[0-9]+$ ]] || [[ "$pg_port" -lt 1024 ]] || [[ "$pg_port" -gt 65535 ]]; then
        log_warning "Invalid port number. Using default 5432"
        pg_port="5432"
    fi

    # Import PostgreSQL repository key
    log_info "Adding PostgreSQL repository..."
    curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc | \
        sudo gpg --dearmor -o /usr/share/keyrings/postgresql-keyring.gpg >> "$LOG_FILE" 2>&1

    if [[ $? -ne 0 ]]; then
        log_error "Failed to add PostgreSQL GPG key"
        return 1
    fi

    # Add PostgreSQL repository
    echo "deb [signed-by=/usr/share/keyrings/postgresql-keyring.gpg] http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" | \
        sudo tee /etc/apt/sources.list.d/pgdg.list >> "$LOG_FILE"

    # Update package lists
    update_system || return 1

    # Install PostgreSQL
    install_package "postgresql" || return 1
    install_package "postgresql-contrib" || log_warning "Failed to install postgresql-contrib"

    # Configure port if not default
    if [[ "$pg_port" != "5432" ]]; then
        # Get PostgreSQL version for config path
        local pg_version=$(sudo -u postgres psql -t -c "SHOW server_version;" 2>/dev/null | cut -d. -f1 | xargs)
        if [[ -z "$pg_version" ]]; then
            # Fallback: try to get version from dpkg
            pg_version=$(dpkg -l | grep postgresql | grep -oP 'postgresql-\K[0-9]+' | head -1)
        fi

        local pg_config_dir="/etc/postgresql/$pg_version/main"
        if [[ -d "$pg_config_dir" ]]; then
            backup_config "$pg_config_dir/postgresql.conf"
            sed -i "s/^#*port = 5432/port = $pg_port/" "$pg_config_dir/postgresql.conf"
            log_success "PostgreSQL port set to $pg_port"
        else
            log_warning "Could not find PostgreSQL config directory, port not changed"
        fi
    fi

    # Start and enable PostgreSQL service
    log_info "Starting PostgreSQL service..."
    systemctl start postgresql >> "$LOG_FILE" 2>&1
    systemctl enable postgresql >> "$LOG_FILE" 2>&1

    if systemctl is-active --quiet postgresql; then
        log_success "PostgreSQL service started and enabled"
    else
        log_error "Failed to start PostgreSQL service"
        return 1
    fi

    # Configure PostgreSQL
    if ask_yes_no "Create PostgreSQL user?" "y"; then
        configure_postgresql_user "$pg_port"
    fi

    # Show PostgreSQL status
    local version=$(get_version psql)
    log_success "PostgreSQL $version installed successfully"

    return 0
}

# Configure PostgreSQL user
configure_postgresql_user() {
    local pg_port="$1"
    log_info "Configuring PostgreSQL user..."

    local db_user=$(get_input "Database username" "postgres")

    # Generate random password
    local db_pass=$(generate_password 20)
    log_info "Generated random password (20 characters)"

    # Create or update PostgreSQL user
    if [[ "$db_user" == "postgres" ]]; then
        # postgres user already exists, just set password
        sudo -u postgres psql -p "$pg_port" -c "ALTER USER $db_user WITH PASSWORD '$db_pass';" >> "$LOG_FILE" 2>&1
        local create_result=$?
    else
        # Create new user
        sudo -u postgres psql -p "$pg_port" -c "CREATE USER $db_user WITH PASSWORD '$db_pass' SUPERUSER CREATEDB CREATEROLE;" >> "$LOG_FILE" 2>&1
        local create_result=$?
    fi

    if [[ $create_result -eq 0 ]]; then
        local db_name=""

        # Create database for user (skip if user is postgres - database already exists)
        if [[ "$db_user" == "postgres" ]]; then
            db_name="postgres"
            log_info "Using existing 'postgres' database"
        else
            if ask_yes_no "Create database for user?" "y"; then
                db_name=$(get_input "Database name" "postgres")
                sudo -u postgres psql -p "$pg_port" -c "CREATE DATABASE $db_name OWNER $db_user;" >> "$LOG_FILE" 2>&1

                if [[ $? -eq 0 ]]; then
                    log_success "Database created: $db_name"
                else
                    log_error "Failed to create database"
                    db_name=""
                fi
            fi
        fi

        # Save credentials to file
        local cred_file="/root/postgresql-credentials.txt"
        cat > "$cred_file" << EOF
PostgreSQL Credentials
======================
Generated: $(date)

Username: $db_user
Password: $db_pass
Database: ${db_name:-postgres}
Port:     $pg_port

Connection string:
postgresql://$db_user:$db_pass@localhost:$pg_port/${db_name:-postgres}

psql command:
PGPASSWORD='$db_pass' psql -h localhost -p $pg_port -U $db_user -d ${db_name:-postgres}

EOF
        chmod 600 "$cred_file"

        # Display credentials on screen
        echo ""
        echo -e "${BOLD}${GREEN}═══════════════════════════════════════════════════${NC}"
        echo -e "${BOLD}${GREEN}     PostgreSQL Credentials${NC}"
        echo -e "${BOLD}${GREEN}═══════════════════════════════════════════════════${NC}"
        echo ""
        echo -e "${BOLD}Username:${NC} ${CYAN}$db_user${NC}"
        echo -e "${BOLD}Password:${NC} ${CYAN}$db_pass${NC}"
        if [[ -n "$db_name" ]]; then
            echo -e "${BOLD}Database:${NC} ${CYAN}$db_name${NC}"
        fi
        echo -e "${BOLD}Port:${NC}     ${CYAN}$pg_port${NC}"
        echo ""
        echo -e "${YELLOW}Connection string:${NC}"
        if [[ -n "$db_name" ]]; then
            echo -e "${DIM}postgresql://$db_user:$db_pass@localhost:$pg_port/$db_name${NC}"
        else
            echo -e "${DIM}postgresql://$db_user:$db_pass@localhost:$pg_port/postgres${NC}"
        fi
        echo ""
        echo -e "${YELLOW}psql command:${NC}"
        echo -e "${DIM}PGPASSWORD='$db_pass' psql -h localhost -p $pg_port -U $db_user -d ${db_name:-postgres}${NC}"
        echo ""
        echo -e "${GREEN}${BOLD}✓ Credentials saved to:${NC} ${CYAN}$cred_file${NC}"
        echo ""
        echo -e "${BOLD}${GREEN}═══════════════════════════════════════════════════${NC}"
        echo ""

        # Wait for user acknowledgment
        printf "Press Enter to continue..." >/dev/tty
        read -r </dev/tty

        if [[ "$db_user" == "postgres" ]]; then
            log_success "PostgreSQL password set for user: $db_user"
        else
            log_success "PostgreSQL user created: $db_user"
        fi

        # Configure remote access
        if ask_yes_no "Allow remote connections?" "n"; then
            configure_postgresql_remote "$pg_port"
        fi
    else
        if [[ "$db_user" == "postgres" ]]; then
            log_error "Failed to set password for PostgreSQL user"
        else
            log_error "Failed to create PostgreSQL user"
        fi
        return 1
    fi

    return 0
}

# Configure PostgreSQL for remote access
configure_postgresql_remote() {
    local pg_port="$1"
    log_info "Configuring PostgreSQL for remote access..."

    # Get PostgreSQL version
    local pg_version=$(sudo -u postgres psql -p "$pg_port" -t -c "SHOW server_version;" 2>/dev/null | cut -d. -f1 | xargs)
    if [[ -z "$pg_version" ]]; then
        pg_version=$(dpkg -l | grep postgresql | grep -oP 'postgresql-\K[0-9]+' | head -1)
    fi

    local pg_config_dir="/etc/postgresql/$pg_version/main"

    if [[ ! -d "$pg_config_dir" ]]; then
        log_error "PostgreSQL config directory not found: $pg_config_dir"
        return 1
    fi

    # Backup configs
    backup_config "$pg_config_dir/postgresql.conf"
    backup_config "$pg_config_dir/pg_hba.conf"

    # Configure postgresql.conf to listen on all addresses
    if ! grep -q "^listen_addresses" "$pg_config_dir/postgresql.conf"; then
        echo "listen_addresses = '*'" >> "$pg_config_dir/postgresql.conf"
    else
        sed -i "s/^#*listen_addresses.*/listen_addresses = '*'/" "$pg_config_dir/postgresql.conf"
    fi

    # Configure pg_hba.conf to allow password authentication
    echo "host    all             all             0.0.0.0/0               md5" >> "$pg_config_dir/pg_hba.conf"
    echo "host    all             all             ::/0                    md5" >> "$pg_config_dir/pg_hba.conf"

    # Restart PostgreSQL
    systemctl restart postgresql >> "$LOG_FILE" 2>&1
    log_success "PostgreSQL configured for remote access"
    log_warning "Remember to configure firewall to allow port $pg_port"

    return 0
}
