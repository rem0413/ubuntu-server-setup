#!/bin/bash

# Node.js installation
install_nodejs() {
    log_info "Installing Node.js..."

    # Check if already installed
    if command_exists node; then
        local version=$(get_version node)
        log_info "Node.js $version already installed"
        if ask_yes_no "Reinstall Node.js?" "n"; then
            log_info "Proceeding with reinstallation..."
        else
            return 0
        fi
    fi

    # Ask for Node.js version
    echo ""
    echo "Select Node.js version:"
    echo "  1) LTS (20.x) - Recommended"
    echo "  2) Current (21.x)"
    echo "  3) Previous LTS (18.x)"
    echo ""
    read_prompt "Choice [1]: " node_choice "1"

    local node_version
    case $node_choice in
        1) node_version="20" ;;
        2) node_version="21" ;;
        3) node_version="18" ;;
        *) node_version="20" ;;
    esac

    # Add NodeSource repository
    log_info "Adding NodeSource repository for Node.js $node_version.x..."
    curl -fsSL https://deb.nodesource.com/setup_${node_version}.x | sudo -E bash - >> "$LOG_FILE" 2>&1

    if [[ $? -ne 0 ]]; then
        log_error "Failed to add NodeSource repository"
        return 1
    fi

    # Install Node.js
    install_package "nodejs" || return 1

    # Verify installation
    if command_exists node && command_exists npm; then
        local node_ver=$(get_version node)
        local npm_ver=$(npm --version 2>/dev/null)
        log_success "Node.js $node_ver installed"
        log_success "npm $npm_ver installed"
    else
        log_error "Node.js installation verification failed"
        return 1
    fi

    # Configure npm global directory for non-root users
    if ask_yes_no "Configure npm for non-root global installs?" "y"; then
        configure_npm_global
    fi

    # Install additional package managers
    if ask_yes_no "Install Yarn?" "n"; then
        npm install -g yarn >> "$LOG_FILE" 2>&1
        log_success "Yarn installed: $(yarn --version 2>/dev/null)"
    fi

    if ask_yes_no "Install pnpm?" "n"; then
        npm install -g pnpm >> "$LOG_FILE" 2>&1
        log_success "pnpm installed: $(pnpm --version 2>/dev/null)"
    fi

    return 0
}

# Configure npm global directory
configure_npm_global() {
    log_info "Configuring npm global directory..."

    # Get the actual user (not root)
    local actual_user="${SUDO_USER:-$USER}"
    local user_home=$(eval echo ~$actual_user)

    # Create npm global directory
    local npm_dir="$user_home/.npm-global"
    mkdir -p "$npm_dir"

    # Set npm prefix
    sudo -u "$actual_user" npm config set prefix "$npm_dir" 2>> "$LOG_FILE"

    # Add to PATH in .bashrc if not already present
    local bashrc="$user_home/.bashrc"
    if [[ -f "$bashrc" ]] && ! grep -q "npm-global/bin" "$bashrc"; then
        echo "" >> "$bashrc"
        echo "# npm global packages" >> "$bashrc"
        echo "export PATH=\$HOME/.npm-global/bin:\$PATH" >> "$bashrc"
        log_success "npm global directory configured: $npm_dir"
        log_info "Run 'source ~/.bashrc' to update PATH"
    fi

    chown -R "$actual_user:$actual_user" "$npm_dir"

    return 0
}
