#!/bin/bash

# Docker installation
install_docker() {
    log_info "Installing Docker..."

    # Check if already installed
    if command_exists docker; then
        local version=$(get_version docker)
        log_info "Docker $version already installed"
        if ask_yes_no "Reinstall Docker?" "n"; then
            log_info "Proceeding with reinstallation..."
        else
            return 0
        fi
    fi

    # Remove old versions
    log_info "Removing old Docker versions (if any)..."
    apt-get remove -y docker docker-engine docker.io containerd runc >> "$LOG_FILE" 2>&1

    # Install prerequisites
    install_package "ca-certificates" || return 1
    install_package "curl" || return 1
    install_package "gnupg" || return 1

    # Add Docker's official GPG key
    log_info "Adding Docker repository..."
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
        sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg >> "$LOG_FILE" 2>&1

    if [[ $? -ne 0 ]]; then
        log_error "Failed to add Docker GPG key"
        return 1
    fi

    chmod a+r /etc/apt/keyrings/docker.gpg

    # Add Docker repository
    echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
        $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
        sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    # Update package lists
    update_system || return 1

    # Install Docker packages
    local docker_packages=(
        "docker-ce"
        "docker-ce-cli"
        "containerd.io"
        "docker-buildx-plugin"
        "docker-compose-plugin"
    )

    for package in "${docker_packages[@]}"; do
        install_package "$package" || {
            log_error "Failed to install $package"
            return 1
        }
    done

    # Start and enable Docker service
    log_info "Starting Docker service..."
    systemctl start docker >> "$LOG_FILE" 2>&1
    systemctl enable docker >> "$LOG_FILE" 2>&1

    if systemctl is-active --quiet docker; then
        log_success "Docker service started and enabled"
    else
        log_error "Failed to start Docker service"
        return 1
    fi

    # Add user to docker group
    local actual_user="${SUDO_USER:-$USER}"
    if [[ "$actual_user" != "root" ]]; then
        if ask_yes_no "Add $actual_user to docker group?" "y"; then
            usermod -aG docker "$actual_user" >> "$LOG_FILE" 2>&1
            log_success "User $actual_user added to docker group"
            log_warning "Log out and back in for group changes to take effect"
        fi
    fi

    # Test Docker installation
    log_info "Testing Docker installation..."
    docker run --rm hello-world >> "$LOG_FILE" 2>&1

    if [[ $? -eq 0 ]]; then
        log_success "Docker test successful"
    else
        log_warning "Docker test failed, but installation may still be successful"
    fi

    # Show Docker version
    local docker_ver=$(get_version docker)
    local compose_ver=$(docker compose version 2>/dev/null | awk '{print $4}' | sed 's/v//')
    log_success "Docker $docker_ver installed"
    log_success "Docker Compose $compose_ver installed"

    # Configure Docker daemon
    if ask_yes_no "Configure Docker daemon settings?" "n"; then
        configure_docker_daemon
    fi

    return 0
}

# Configure Docker daemon
configure_docker_daemon() {
    log_info "Configuring Docker daemon..."

    local daemon_config="/etc/docker/daemon.json"
    backup_config "$daemon_config"

    # Create daemon.json if it doesn't exist
    if [[ ! -f "$daemon_config" ]]; then
        cat > "$daemon_config" << 'EOF'
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "storage-driver": "overlay2"
}
EOF
        log_success "Docker daemon configuration created"

        # Restart Docker to apply changes
        systemctl restart docker >> "$LOG_FILE" 2>&1
        log_success "Docker daemon restarted"
    else
        log_info "Docker daemon.json already exists, skipping configuration"
    fi

    return 0
}
