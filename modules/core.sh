#!/bin/bash

# Core system setup and essential tools
install_core() {
    log_info "Installing core system updates and essential tools..."

    # Update package lists
    update_system || return 1

    # Upgrade existing packages
    log_info "Upgrading existing packages..."
    DEBIAN_FRONTEND=noninteractive apt-get upgrade -y >> "$LOG_FILE" 2>&1
    if [[ $? -eq 0 ]]; then
        log_success "System packages upgraded"
    else
        log_warning "Some packages failed to upgrade"
    fi

    # Install essential build tools
    local packages=(
        "build-essential"
        "software-properties-common"
        "apt-transport-https"
        "ca-certificates"
        "curl"
        "wget"
        "git"
        "vim"
        "nano"
        "htop"
        "net-tools"
        "unzip"
        "tar"
        "gnupg"
        "lsb-release"
    )

    log_info "Installing essential tools..."
    for package in "${packages[@]}"; do
        if ! is_installed "$package"; then
            install_package "$package" || log_warning "Failed to install $package"
        else
            log_info "$package already installed"
        fi
    done

    log_success "Core system setup completed"
    return 0
}
