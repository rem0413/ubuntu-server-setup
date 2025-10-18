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

        # Show current status
        echo ""
        log_info "Current firewall status:"
        ufw status numbered
        echo ""

        # Offer to add ports
        if ask_yes_no "Add/manage firewall ports?" "y"; then
            manage_ufw_ports
        fi
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

    # Detect SSH port from config
    local detected_ssh_port=$(grep -E "^Port " /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}' || echo "22")
    echo ""
    read_prompt "SSH port [$detected_ssh_port]: " ssh_port "$detected_ssh_port"

    ufw allow "$ssh_port/tcp" comment 'SSH' >> "$LOG_FILE" 2>&1
    log_success "SSH port $ssh_port allowed"

    # Detect and ask about installed services
    echo ""
    log_info "Detecting installed services..."
    echo ""

    local detected_count=0

    # HTTP/HTTPS (Nginx/Apache)
    if command_exists nginx || command_exists apache2; then
        detected_count=$((detected_count + 1))
        log_info "✓ Web server detected (Nginx/Apache)"
        if ask_yes_no "Allow HTTP (80)?" "y"; then
            ufw allow 80/tcp comment 'HTTP' >> "$LOG_FILE" 2>&1
            log_success "HTTP port 80 allowed"
        fi

        if ask_yes_no "Allow HTTPS (443)?" "y"; then
            ufw allow 443/tcp comment 'HTTPS' >> "$LOG_FILE" 2>&1
            log_success "HTTPS port 443 allowed"
        fi
    fi

    # MongoDB
    if command_exists mongod; then
        detected_count=$((detected_count + 1))
        local mongo_port=$(grep -E "^\s*port:" /etc/mongod.conf 2>/dev/null | awk '{print $2}' || echo "27017")
        log_info "✓ MongoDB detected on port $mongo_port"
        if ask_yes_no "Allow MongoDB ($mongo_port)?" "n"; then
            ufw allow "$mongo_port/tcp" comment 'MongoDB' >> "$LOG_FILE" 2>&1
            log_success "MongoDB port $mongo_port allowed"
        fi
    fi

    # PostgreSQL
    if command_exists psql; then
        detected_count=$((detected_count + 1))
        local pg_port=$(sudo -u postgres psql -t -c "SHOW port;" 2>/dev/null | xargs || echo "5432")
        log_info "✓ PostgreSQL detected on port $pg_port"
        if ask_yes_no "Allow PostgreSQL ($pg_port)?" "n"; then
            ufw allow "$pg_port/tcp" comment 'PostgreSQL' >> "$LOG_FILE" 2>&1
            log_success "PostgreSQL port $pg_port allowed"
        fi
    fi

    # Redis
    if command_exists redis-server; then
        detected_count=$((detected_count + 1))
        local redis_port=$(grep -E "^port " /etc/redis/redis.conf 2>/dev/null | awk '{print $2}' || echo "6379")
        log_info "✓ Redis detected on port $redis_port"
        if ask_yes_no "Allow Redis ($redis_port)?" "n"; then
            ufw allow "$redis_port/tcp" comment 'Redis' >> "$LOG_FILE" 2>&1
            log_success "Redis port $redis_port allowed"
        fi
    fi

    # OpenVPN
    if [[ -d /etc/openvpn/server ]]; then
        detected_count=$((detected_count + 1))
        local vpn_port=$(grep -E "^port " /etc/openvpn/server/*.conf 2>/dev/null | head -1 | awk '{print $2}' || echo "1194")
        local vpn_proto=$(grep -E "^proto " /etc/openvpn/server/*.conf 2>/dev/null | head -1 | awk '{print $2}' || echo "udp")
        log_info "✓ OpenVPN detected on port $vpn_port/$vpn_proto"
        if ask_yes_no "Allow OpenVPN ($vpn_port/$vpn_proto)?" "y"; then
            ufw allow "$vpn_port/$vpn_proto" comment 'OpenVPN' >> "$LOG_FILE" 2>&1
            log_success "OpenVPN port $vpn_port/$vpn_proto allowed"
        fi
    fi

    # Prometheus/Grafana
    if systemctl is-active --quiet prometheus 2>/dev/null; then
        detected_count=$((detected_count + 1))
        log_info "✓ Prometheus detected on port 9090"
        if ask_yes_no "Allow Prometheus (9090)?" "n"; then
            ufw allow 9090/tcp comment 'Prometheus' >> "$LOG_FILE" 2>&1
            log_success "Prometheus port 9090 allowed"
        fi
    fi

    if systemctl is-active --quiet grafana-server 2>/dev/null; then
        detected_count=$((detected_count + 1))
        log_info "✓ Grafana detected on port 3000"
        if ask_yes_no "Allow Grafana (3000)?" "y"; then
            ufw allow 3000/tcp comment 'Grafana' >> "$LOG_FILE" 2>&1
            log_success "Grafana port 3000 allowed"
        fi
    fi

    # Show detection summary
    echo ""
    if [[ $detected_count -eq 0 ]]; then
        log_warning "No services detected (only SSH)"
        log_info "Services will be auto-detected when installed"
    else
        log_success "Detected $detected_count service(s)"
    fi

    # Custom ports - always show
    echo ""
    log_info "Custom ports (optional)"
    echo "Enter port numbers to allow, or type 'done' to skip"
    echo ""

    while true; do
        read_prompt "Enter port number (or 'done' to finish): " custom_port ""

        if [[ "$custom_port" == "done" ]] || [[ -z "$custom_port" ]]; then
            break
        fi

        # Validate port
        if [[ ! "$custom_port" =~ ^[0-9]+$ ]] || [[ "$custom_port" -lt 1 ]] || [[ "$custom_port" -gt 65535 ]]; then
            log_error "Invalid port number: $custom_port (must be 1-65535)"
            continue
        fi

        read_prompt "Protocol (tcp/udp) [tcp]: " custom_proto "tcp"
        read_prompt "Comment [Custom]: " custom_comment "Custom"

        ufw allow "$custom_port/$custom_proto" comment "$custom_comment" >> "$LOG_FILE" 2>&1
        log_success "Port $custom_port/$custom_proto allowed ($custom_comment)"
        echo ""
    done

    # Enable UFW
    echo ""
    log_info "Enabling UFW firewall..."
    echo "y" | ufw enable >> "$LOG_FILE" 2>&1
    log_success "UFW firewall enabled"

    # Show UFW status
    echo ""
    log_info "Current firewall rules:"
    ufw status numbered

    return 0
}

# Manage UFW ports (when already installed)
manage_ufw_ports() {
    log_info "UFW Port Management"
    echo ""

    # Detect installed services
    log_info "Detecting installed services..."
    echo ""

    local detected_count=0
    local ports_added=0

    # HTTP/HTTPS (Nginx/Apache)
    if command_exists nginx || command_exists apache2; then
        detected_count=$((detected_count + 1))

        # Check if port 80 is already allowed
        if ! ufw status | grep -q "^80/tcp"; then
            log_info "✓ Web server detected (Nginx/Apache)"
            if ask_yes_no "Allow HTTP (80)?" "y"; then
                ufw allow 80/tcp comment 'HTTP' >> "$LOG_FILE" 2>&1
                log_success "HTTP port 80 allowed"
                ports_added=$((ports_added + 1))
            fi
        fi

        # Check if port 443 is already allowed
        if ! ufw status | grep -q "^443/tcp"; then
            if ask_yes_no "Allow HTTPS (443)?" "y"; then
                ufw allow 443/tcp comment 'HTTPS' >> "$LOG_FILE" 2>&1
                log_success "HTTPS port 443 allowed"
                ports_added=$((ports_added + 1))
            fi
        fi
    fi

    # MongoDB
    if command_exists mongod; then
        detected_count=$((detected_count + 1))
        local mongo_port=$(grep -E "^\s*port:" /etc/mongod.conf 2>/dev/null | awk '{print $2}' || echo "27017")

        if ! ufw status | grep -q "^${mongo_port}/tcp"; then
            log_info "✓ MongoDB detected on port $mongo_port"
            if ask_yes_no "Allow MongoDB ($mongo_port)?" "n"; then
                ufw allow "$mongo_port/tcp" comment 'MongoDB' >> "$LOG_FILE" 2>&1
                log_success "MongoDB port $mongo_port allowed"
                ports_added=$((ports_added + 1))
            fi
        fi
    fi

    # PostgreSQL
    if command_exists psql; then
        detected_count=$((detected_count + 1))
        local pg_port=$(sudo -u postgres psql -t -c "SHOW port;" 2>/dev/null | xargs || echo "5432")

        if ! ufw status | grep -q "^${pg_port}/tcp"; then
            log_info "✓ PostgreSQL detected on port $pg_port"
            if ask_yes_no "Allow PostgreSQL ($pg_port)?" "n"; then
                ufw allow "$pg_port/tcp" comment 'PostgreSQL' >> "$LOG_FILE" 2>&1
                log_success "PostgreSQL port $pg_port allowed"
                ports_added=$((ports_added + 1))
            fi
        fi
    fi

    # Redis
    if command_exists redis-server; then
        detected_count=$((detected_count + 1))
        local redis_port=$(grep -E "^port " /etc/redis/redis.conf 2>/dev/null | awk '{print $2}' || echo "6379")

        if ! ufw status | grep -q "^${redis_port}/tcp"; then
            log_info "✓ Redis detected on port $redis_port"
            if ask_yes_no "Allow Redis ($redis_port)?" "n"; then
                ufw allow "$redis_port/tcp" comment 'Redis' >> "$LOG_FILE" 2>&1
                log_success "Redis port $redis_port allowed"
                ports_added=$((ports_added + 1))
            fi
        fi
    fi

    # OpenVPN
    if [[ -d /etc/openvpn/server ]]; then
        detected_count=$((detected_count + 1))
        local vpn_port=$(grep -E "^port " /etc/openvpn/server/*.conf 2>/dev/null | head -1 | awk '{print $2}' || echo "1194")
        local vpn_proto=$(grep -E "^proto " /etc/openvpn/server/*.conf 2>/dev/null | head -1 | awk '{print $2}' || echo "udp")

        if ! ufw status | grep -q "^${vpn_port}/${vpn_proto}"; then
            log_info "✓ OpenVPN detected on port $vpn_port/$vpn_proto"
            if ask_yes_no "Allow OpenVPN ($vpn_port/$vpn_proto)?" "y"; then
                ufw allow "$vpn_port/$vpn_proto" comment 'OpenVPN' >> "$LOG_FILE" 2>&1
                log_success "OpenVPN port $vpn_port/$vpn_proto allowed"
                ports_added=$((ports_added + 1))
            fi
        fi
    fi

    # Prometheus
    if systemctl is-active --quiet prometheus 2>/dev/null; then
        detected_count=$((detected_count + 1))

        if ! ufw status | grep -q "^9090/tcp"; then
            log_info "✓ Prometheus detected on port 9090"
            if ask_yes_no "Allow Prometheus (9090)?" "n"; then
                ufw allow 9090/tcp comment 'Prometheus' >> "$LOG_FILE" 2>&1
                log_success "Prometheus port 9090 allowed"
                ports_added=$((ports_added + 1))
            fi
        fi
    fi

    # Grafana
    if systemctl is-active --quiet grafana-server 2>/dev/null; then
        detected_count=$((detected_count + 1))

        if ! ufw status | grep -q "^3000/tcp"; then
            log_info "✓ Grafana detected on port 3000"
            if ask_yes_no "Allow Grafana (3000)?" "y"; then
                ufw allow 3000/tcp comment 'Grafana' >> "$LOG_FILE" 2>&1
                log_success "Grafana port 3000 allowed"
                ports_added=$((ports_added + 1))
            fi
        fi
    fi

    # Show detection summary
    echo ""
    if [[ $detected_count -eq 0 ]]; then
        log_warning "No new services detected"
    else
        log_success "Detected $detected_count service(s)"
    fi

    # Custom ports - always show
    echo ""
    log_info "Custom ports (optional)"
    echo "Enter port numbers to allow, or type 'done' to skip"
    echo ""

    while true; do
        read_prompt "Enter port number (or 'done' to finish): " custom_port ""

        if [[ "$custom_port" == "done" ]] || [[ -z "$custom_port" ]]; then
            break
        fi

        # Validate port
        if [[ ! "$custom_port" =~ ^[0-9]+$ ]] || [[ "$custom_port" -lt 1 ]] || [[ "$custom_port" -gt 65535 ]]; then
            log_error "Invalid port number: $custom_port (must be 1-65535)"
            continue
        fi

        read_prompt "Protocol (tcp/udp) [tcp]: " custom_proto "tcp"
        read_prompt "Comment [Custom]: " custom_comment "Custom"

        ufw allow "$custom_port/$custom_proto" comment "$custom_comment" >> "$LOG_FILE" 2>&1
        log_success "Port $custom_port/$custom_proto allowed ($custom_comment)"
        ports_added=$((ports_added + 1))
        echo ""
    done

    # Show updated status
    if [[ $ports_added -gt 0 ]]; then
        echo ""
        log_info "Updated firewall rules:"
        ufw status numbered
        log_success "Added $ports_added port(s) to firewall"
    else
        log_info "No ports were added"
    fi

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

    # Wait for service to start
    sleep 2

    if systemctl is-active --quiet fail2ban; then
        log_success "Fail2ban restarted with new configuration"

        # Show Fail2ban status
        echo ""
        log_info "Fail2ban status:"

        # Check which jails are enabled
        local jails=$(fail2ban-client status 2>/dev/null | grep "Jail list" | sed 's/.*:\s*//')

        if [[ -n "$jails" ]]; then
            echo "  Active jails: $jails"

            # Show detailed status for sshd jail if it exists
            if echo "$jails" | grep -q "sshd"; then
                echo ""
                fail2ban-client status sshd 2>/dev/null | sed 's/^/  /'
            fi
        else
            log_warning "No active jails found. Check configuration in /etc/fail2ban/jail.local"
        fi
    else
        log_error "Fail2ban failed to start. Check logs: journalctl -u fail2ban -n 20"
    fi

    return 0
}
