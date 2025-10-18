#!/bin/bash

################################################################################
# Ubuntu Server Setup Automation Script
# Description: Interactive server setup for Ubuntu 24.04 LTS
# Author: Ubuntu Setup Team
# Version: 2.0.0
################################################################################

set -e

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load libraries
source "$SCRIPT_DIR/lib/colors.sh"
source "$SCRIPT_DIR/lib/utils.sh"
source "$SCRIPT_DIR/lib/ui.sh"

# Load modules
source "$SCRIPT_DIR/modules/core.sh"
source "$SCRIPT_DIR/modules/mongodb.sh"
source "$SCRIPT_DIR/modules/postgresql.sh"
source "$SCRIPT_DIR/modules/nodejs.sh"
source "$SCRIPT_DIR/modules/pm2.sh"
source "$SCRIPT_DIR/modules/docker.sh"
source "$SCRIPT_DIR/modules/nginx-unified.sh"
source "$SCRIPT_DIR/modules/security.sh"
source "$SCRIPT_DIR/modules/openvpn.sh"
source "$SCRIPT_DIR/modules/ssh-hardening.sh"
source "$SCRIPT_DIR/modules/redis.sh"
source "$SCRIPT_DIR/modules/monitoring.sh"

# Global variables
VERSION="2.0.0"
INSTALL_ALL=false
DRY_RUN=false
SELECTED_COMPONENTS=()
PROFILE=""
SUMMARY_FILE="/root/ubuntu-setup-summary.txt"
NON_INTERACTIVE=false  # Track if running with command-line args

################################################################################
# Main Functions
################################################################################

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --all)
                INSTALL_ALL=true
                NON_INTERACTIVE=true
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --profile)
                PROFILE="$2"
                NON_INTERACTIVE=true
                shift 2
                ;;
            --components)
                # Accept space-separated component numbers
                NON_INTERACTIVE=true
                shift
                SELECTED_COMPONENTS=()
                while [[ $# -gt 0 && ! "$1" =~ ^-- ]]; do
                    SELECTED_COMPONENTS+=("$1")
                    shift
                done
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            --version|-v)
                echo "Ubuntu Server Setup v${VERSION}"
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

# Show help message
show_help() {
    cat << EOF
Ubuntu Server Setup Automation Script

Usage: $0 [OPTIONS]

Options:
    --all                  Install all components
    --components <nums>    Install specific components (e.g., --components 1 4 7 8)
    --profile <name>       Use predefined profile (nodejs-app, docker-host, fullstack)
    --dry-run              Show what would be installed without executing
    --help, -h             Show this help message
    --version, -v          Show version information

Profiles:
    nodejs-app          Core + MongoDB + Node.js + PM2 + Nginx + Security
    docker-host         Core + Docker + Security
    fullstack           Core + MongoDB + PostgreSQL + Node.js + PM2 + Docker + Nginx + Security

Components:
    1.  System Update & Essential Tools
    2.  MongoDB Database
    3.  PostgreSQL Database
    4.  Node.js & npm
    5.  PM2 Process Manager
    6.  Docker & Docker Compose
    7.  Nginx Web Server (with Cloudflare & Advanced Config)
    8.  Security Tools (UFW, Fail2ban)
    9.  OpenVPN Server & Client Management
    10. SSH Security Hardening
    11. Redis Cache Server
    12. Monitoring Stack (Prometheus/Grafana)

Examples:
    # Interactive mode (shows menu)
    sudo ./install.sh

    # Install all components
    sudo ./install.sh --all

    # Install specific components
    sudo ./install.sh --components 1 4 7 8

    # Use predefined profile
    sudo ./install.sh --profile nodejs-app

    # Remote installation
    curl -fsSL https://raw.githubusercontent.com/rem0413/ubuntu-server-setup/master/remote-install.sh | sudo bash
    curl -fsSL https://raw.githubusercontent.com/rem0413/ubuntu-server-setup/master/remote-install.sh | sudo bash -s -- --all
    curl -fsSL https://raw.githubusercontent.com/rem0413/ubuntu-server-setup/master/remote-install.sh | sudo bash -s -- --components 1 4 7 8

EOF
}

# Perform system checks
perform_system_checks() {
    log_info "Performing system checks..."

    # Check root/sudo
    check_root || exit 1

    # Check Ubuntu version
    check_ubuntu_version || exit 1

    # Check internet connection
    check_internet || exit 1

    log_success "System checks passed"
}

# Load profile
load_profile() {
    case "$PROFILE" in
        nodejs-app)
            SELECTED_COMPONENTS=(1 2 4 5 7 8)
            log_info "Loading profile: Node.js Application Stack"
            ;;
        docker-host)
            SELECTED_COMPONENTS=(1 6 8)
            log_info "Loading profile: Docker Host"
            ;;
        fullstack)
            SELECTED_COMPONENTS=(1 2 3 4 5 6 7 8)
            log_info "Loading profile: Full Stack Development"
            ;;
        vpn-server)
            SELECTED_COMPONENTS=(1 8 9 10)
            log_info "Loading profile: VPN Server"
            ;;
        *)
            log_error "Unknown profile: $PROFILE"
            log_info "Available profiles: nodejs-app, docker-host, fullstack, vpn-server"
            exit 1
            ;;
    esac
}

# Get user selections
get_user_selections() {
    # Components from --components flag take precedence
    if [[ ${#SELECTED_COMPONENTS[@]} -gt 0 ]]; then
        log_info "Using components from command line: ${SELECTED_COMPONENTS[*]}"
        return 0
    fi

    # Profile takes precedence
    if [[ -n "$PROFILE" ]]; then
        load_profile
        return 0
    fi

    if [[ "$INSTALL_ALL" == true ]]; then
        SELECTED_COMPONENTS=(1 2 3 4 5 6 7 8 9 10 11 12)
        log_info "Installing all components"
        return 0
    fi

    # Simple component selection - works everywhere
    show_simple_selection_menu
}

# Simple selection menu
show_simple_selection_menu() {
    show_simple_menu

    printf "Enter choice: "
    read -r input || input=""
    input=$(echo "$input" | xargs)

    case "$input" in
        0)
            SELECTED_COMPONENTS=(1 2 3 4 5 6 7 8 9 10 11 12)
            echo "Installing all components"
            ;;
        q|Q)
            echo "Cancelled"
            exit 0
            ;;
        "")
            echo "ERROR: No input. Use --all or --profile or --components"
            echo "Examples:"
            echo "  sudo ./install.sh --all"
            echo "  sudo ./install.sh --profile nodejs-app"
            echo "  sudo ./install.sh --components 1 4 7 8"
            exit 1
            ;;
        *)
            if [[ "$input" =~ ^[0-9\ ]+$ ]]; then
                local temp_array=($input)
                local valid=true

                for num in "${temp_array[@]}"; do
                    if [[ $num -lt 1 || $num -gt 12 ]]; then
                        echo "ERROR: Invalid number '$num' (valid: 1-12)"
                        exit 1
                    fi
                done

                SELECTED_COMPONENTS=($input)
                echo "Selected: $input"
            else
                echo "ERROR: Invalid format. Use numbers (e.g., 1 4 7 8)"
                exit 1
            fi
            ;;
    esac
}

# Confirm selections
confirm_selections() {
    local components_text=""

    for component in "${SELECTED_COMPONENTS[@]}"; do
        case $component in
            1) components_text+="  - System Update & Essential Tools\n" ;;
            2) components_text+="  - MongoDB Database\n" ;;
            3) components_text+="  - PostgreSQL Database\n" ;;
            4) components_text+="  - Node.js & npm\n" ;;
            5) components_text+="  - PM2 Process Manager\n" ;;
            6) components_text+="  - Docker & Docker Compose\n" ;;
            7) components_text+="  - Nginx Web Server\n" ;;
            8) components_text+="  - Security Tools (UFW, Fail2ban)\n" ;;
            9) components_text+="  - OpenVPN Server\n" ;;
            10) components_text+="  - SSH Security Hardening\n" ;;
            11) components_text+="  - Redis Cache Server\n" ;;
            12) components_text+="  - Monitoring Stack\n" ;;
        esac
    done

    echo -e "$components_text"

    # Dry-run mode - just show and exit
    if [[ "$DRY_RUN" == true ]]; then
        echo ""
        echo "DRY-RUN MODE: No changes will be made"
        echo "To proceed with installation, run without --dry-run flag"
        exit 0
    fi

    if ! confirm_installation "$components_text"; then
        echo "Installation cancelled by user"
        exit 0
    fi
}

# Install selected components
install_components() {
    local total=${#SELECTED_COMPONENTS[@]}
    local current=0

    for component in "${SELECTED_COMPONENTS[@]}"; do
        current=$((current + 1))

        case $component in
            1)
                show_step $current $total "System Update & Essential Tools"
                install_core || log_error "Core installation failed"
                ;;
            2)
                show_step $current $total "MongoDB Database"
                install_mongodb || log_error "MongoDB installation failed"
                ;;
            3)
                show_step $current $total "PostgreSQL Database"
                install_postgresql || log_error "PostgreSQL installation failed"
                ;;
            4)
                show_step $current $total "Node.js & npm"
                install_nodejs || log_error "Node.js installation failed"
                ;;
            5)
                show_step $current $total "PM2 Process Manager"
                install_pm2 || log_error "PM2 installation failed"
                ;;
            6)
                show_step $current $total "Docker & Docker Compose"
                install_docker || log_error "Docker installation failed"
                ;;
            7)
                show_step $current $total "Nginx Web Server"
                install_nginx || log_error "Nginx installation failed"
                ;;
            8)
                show_step $current $total "Security Tools"
                install_security || log_error "Security tools installation failed"
                ;;
            9)
                show_step $current $total "OpenVPN Server"
                install_openvpn || log_error "OpenVPN installation failed"
                ;;
            10)
                show_step $current $total "SSH Security Hardening"
                configure_ssh_hardening || log_error "SSH hardening failed"
                ;;
            11)
                show_step $current $total "Redis Cache Server"
                install_redis || log_error "Redis installation failed"
                ;;
            12)
                show_step $current $total "Monitoring Stack"
                install_monitoring || log_error "Monitoring stack installation failed"
                ;;
        esac

        progress_bar $current $total "Installing components..."
    done

    echo ""
}

# Generate installation summary file
generate_summary_file() {
    log_info "Generating installation summary..."

    cat > "$SUMMARY_FILE" << EOF
#################################################
# Ubuntu Server Setup - Installation Summary
# Date: $(date '+%Y-%m-%d %H:%M:%S')
# Hostname: $(hostname)
# IP Address: $(hostname -I | awk '{print $1}')
#################################################

INSTALLED COMPONENTS:
EOF

    for component in "${SELECTED_COMPONENTS[@]}"; do
        case $component in
            1) echo "  ✓ System Update & Essential Tools" >> "$SUMMARY_FILE" ;;
            2) echo "  ✓ MongoDB Database" >> "$SUMMARY_FILE" ;;
            3) echo "  ✓ PostgreSQL Database" >> "$SUMMARY_FILE" ;;
            4) echo "  ✓ Node.js & npm" >> "$SUMMARY_FILE" ;;
            5) echo "  ✓ PM2 Process Manager" >> "$SUMMARY_FILE" ;;
            6) echo "  ✓ Docker & Docker Compose" >> "$SUMMARY_FILE" ;;
            7) echo "  ✓ Nginx Web Server (Cloudflare & Advanced)" >> "$SUMMARY_FILE" ;;
            8) echo "  ✓ Security Tools (UFW, Fail2ban)" >> "$SUMMARY_FILE" ;;
            9) echo "  ✓ OpenVPN Server & Client Management" >> "$SUMMARY_FILE" ;;
            10) echo "  ✓ SSH Security Hardening" >> "$SUMMARY_FILE" ;;
            11) echo "  ✓ Redis Cache Server" >> "$SUMMARY_FILE" ;;
            12) echo "  ✓ Monitoring Stack (Prometheus/Grafana)" >> "$SUMMARY_FILE" ;;
        esac
    done

    cat >> "$SUMMARY_FILE" << EOF

SERVICE STATUS:
EOF

    # Check service status
    command -v mongod &>/dev/null && echo "  MongoDB: $(systemctl is-active mongod 2>/dev/null || echo 'not installed')" >> "$SUMMARY_FILE"
    command -v postgres &>/dev/null && echo "  PostgreSQL: $(systemctl is-active postgresql 2>/dev/null || echo 'not installed')" >> "$SUMMARY_FILE"
    command -v node &>/dev/null && echo "  Node.js: $(node --version 2>/dev/null || echo 'not installed')" >> "$SUMMARY_FILE"
    command -v pm2 &>/dev/null && echo "  PM2: $(pm2 --version 2>/dev/null || echo 'not installed')" >> "$SUMMARY_FILE"
    command -v docker &>/dev/null && echo "  Docker: $(docker --version 2>/dev/null || echo 'not installed')" >> "$SUMMARY_FILE"
    command -v nginx &>/dev/null && echo "  Nginx: $(systemctl is-active nginx 2>/dev/null || echo 'not installed')" >> "$SUMMARY_FILE"
    command -v ufw &>/dev/null && echo "  UFW: $(ufw status | head -1)" >> "$SUMMARY_FILE"

    cat >> "$SUMMARY_FILE" << EOF

IMPORTANT NOTES:
  - Log file: /var/log/ubuntu-setup.log
  - Config backups: /var/backups/ubuntu-setup/
  - This summary: $SUMMARY_FILE

NEXT STEPS:
EOF

    if [[ " ${SELECTED_COMPONENTS[@]} " =~ " 6 " ]]; then
        echo "  → Log out and back in to use Docker without sudo" >> "$SUMMARY_FILE"
    fi

    if [[ " ${SELECTED_COMPONENTS[@]} " =~ " 4 " ]]; then
        echo "  → Run 'source ~/.bashrc' to update your PATH" >> "$SUMMARY_FILE"
    fi

    if [[ " ${SELECTED_COMPONENTS[@]} " =~ " 8 " ]]; then
        echo "  → Check firewall: sudo ufw status" >> "$SUMMARY_FILE"
    fi

    echo "" >> "$SUMMARY_FILE"
    echo "Support: https://github.com/username/ubuntu-setup" >> "$SUMMARY_FILE"

    chmod 600 "$SUMMARY_FILE"
    log_success "Installation summary saved to: $SUMMARY_FILE"
}

# Show final summary
show_final_summary() {
    show_summary

    # Generate summary file
    generate_summary_file

    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo -e "${BOLD}${GREEN}Installation completed successfully!${NC}"
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo ""

    # Show next steps
    echo -e "${BOLD}Next Steps:${NC}"
    echo ""

    if [[ " ${SELECTED_COMPONENTS[@]} " =~ " 6 " ]]; then
        echo -e "  ${ARROW} Log out and back in to use Docker without sudo"
    fi

    if [[ " ${SELECTED_COMPONENTS[@]} " =~ " 4 " ]]; then
        echo -e "  ${ARROW} Run 'source ~/.bashrc' to update your PATH"
    fi

    if [[ " ${SELECTED_COMPONENTS[@]} " =~ " 8 " ]]; then
        echo -e "  ${ARROW} Check firewall status: sudo ufw status"
    fi

    echo ""
    echo -e "${BOLD}Installation summary saved to:${NC} $SUMMARY_FILE"
    echo ""
    echo -e "${DIM}For support and issues: https://github.com/username/ubuntu-setup${NC}"
    echo ""
}

################################################################################
# Main Execution
################################################################################

main() {
    # Parse arguments (only once at startup)
    parse_arguments "$@"

    # Main loop - allows returning to menu
    while true; do
        # Show banner
        show_banner

        # Initialize logging (only once)
        if [[ ! -f "$LOG_FILE" ]]; then
            init_logging
        fi

        # System checks
        perform_system_checks

        # Get user selections
        get_user_selections

        # Confirm selections
        if [[ ${#SELECTED_COMPONENTS[@]} -eq 0 ]]; then
            log_error "No components selected"
            exit 1
        fi

        confirm_selections

        # Install components
        echo ""
        log_info "Starting installation..."
        echo ""

        install_components

        # Show summary
        show_final_summary

        # Ask if user wants to return to menu (only in interactive mode)
        echo ""
        echo "========================================="
        log_info "Installation complete!"
        echo "========================================="
        echo ""

        # If non-interactive (command-line args), exit after first run
        if [[ "$NON_INTERACTIVE" == true ]]; then
            log_info "Exiting... Thank you for using Ubuntu Server Setup!"
            break
        fi

        # Interactive mode - ask to return to menu
        if ask_yes_no "Return to main menu?" "y"; then
            # Clear selections for next iteration
            SELECTED_COMPONENTS=()
            continue
        else
            log_info "Exiting... Thank you for using Ubuntu Server Setup!"
            break
        fi
    done
}

# Run main function
main "$@"
