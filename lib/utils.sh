#!/bin/bash

# Load colors
source "$(dirname "${BASH_SOURCE[0]}")/colors.sh"

# Configuration
LOG_FILE="/var/log/ubuntu-setup.log"
BACKUP_DIR="/var/backups/ubuntu-setup"

# Initialize logging
init_logging() {
    sudo mkdir -p "$(dirname "$LOG_FILE")"
    sudo touch "$LOG_FILE"
    sudo chmod 666 "$LOG_FILE"
    echo "=== Ubuntu Server Setup - $(date) ===" >> "$LOG_FILE"
}

# Logging functions
log_info() {
    local message="$1"
    echo -e "${BLUE}[INFO]${NC} $message"
    echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') - $message" >> "$LOG_FILE"
}

log_success() {
    local message="$1"
    echo -e "${GREEN}${CHECK}${NC} $message"
    echo "[SUCCESS] $(date '+%Y-%m-%d %H:%M:%S') - $message" >> "$LOG_FILE"
}

log_error() {
    local message="$1"
    echo -e "${RED}${CROSS}${NC} $message"
    echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') - $message" >> "$LOG_FILE"
}

log_warning() {
    local message="$1"
    echo -e "${YELLOW}[WARN]${NC} $message"
    echo "[WARN] $(date '+%Y-%m-%d %H:%M:%S') - $message" >> "$LOG_FILE"
}

log_step() {
    local message="$1"
    echo ""
    echo -e "${BOLD}${MAGENTA}▶ ${message}${NC}"
    echo ""
    echo "[STEP] $(date '+%Y-%m-%d %H:%M:%S') - $message" >> "$LOG_FILE"
}

# Check if running as root or with sudo
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root or with sudo"
        exit 1
    fi
}

# Check Ubuntu version
check_ubuntu_version() {
    if [[ ! -f /etc/os-release ]]; then
        log_error "Cannot detect OS version"
        return 1
    fi

    source /etc/os-release
    if [[ "$ID" != "ubuntu" ]]; then
        log_error "This script is designed for Ubuntu only. Detected: $ID"
        return 1
    fi

    local version_id="${VERSION_ID%%.*}"
    if [[ "$version_id" -lt 20 ]]; then
        log_warning "Ubuntu $VERSION_ID detected. This script is optimized for Ubuntu 24.04"
    fi

    log_success "Ubuntu $VERSION_ID detected"
    return 0
}

# Check internet connection
check_internet() {
    log_info "Checking internet connection..."
    if ping -c 1 8.8.8.8 &> /dev/null; then
        log_success "Internet connection available"
        return 0
    else
        log_error "No internet connection"
        return 1
    fi
}

# Create backup of configuration file
backup_config() {
    local file="$1"
    if [[ -f "$file" ]]; then
        sudo mkdir -p "$BACKUP_DIR"
        local backup_file="$BACKUP_DIR/$(basename "$file").$(date +%Y%m%d_%H%M%S).bak"
        sudo cp "$file" "$backup_file"
        log_info "Backed up $file to $backup_file"
    fi
}

# Check if command exists
command_exists() {
    command -v "$1" &> /dev/null
}

# Check if service is installed
is_installed() {
    local package="$1"
    dpkg -l | grep -qw "$package"
}

# Get installed version
get_version() {
    local command="$1"
    if command_exists "$command"; then
        case "$command" in
            node)
                node --version 2>/dev/null | sed 's/v//'
                ;;
            docker)
                docker --version 2>/dev/null | awk '{print $3}' | sed 's/,//'
                ;;
            mongod)
                mongod --version 2>/dev/null | grep -oP 'v\K[0-9.]+'
                ;;
            psql)
                psql --version 2>/dev/null | awk '{print $3}'
                ;;
            pm2)
                pm2 --version 2>/dev/null
                ;;
            *)
                echo "unknown"
                ;;
        esac
    else
        echo "not installed"
    fi
}

# Progress spinner
spinner() {
    local pid=$1
    local message=$2
    local spinstr='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    while ps -p $pid > /dev/null 2>&1; do
        local temp=${spinstr#?}
        printf " [%c] %s" "$spinstr" "$message"
        spinstr=$temp${spinstr%"$temp"}
        sleep 0.1
        printf "\r"
    done
    printf "    \r"
}

# Install package with retry
install_package() {
    local package="$1"
    local max_retries=3
    local retry=0

    log_info "Installing $package..."

    while [[ $retry -lt $max_retries ]]; do
        if DEBIAN_FRONTEND=noninteractive apt-get install -y "$package" >> "$LOG_FILE" 2>&1; then
            log_success "$package installed successfully"
            return 0
        else
            retry=$((retry + 1))
            if [[ $retry -lt $max_retries ]]; then
                log_warning "Installation failed, retrying ($retry/$max_retries)..."
                sleep 2
            fi
        fi
    done

    log_error "Failed to install $package after $max_retries attempts"
    return 1
}

# Update system packages
update_system() {
    log_info "Updating system packages..."
    apt-get update >> "$LOG_FILE" 2>&1
    if [[ $? -eq 0 ]]; then
        log_success "System packages updated"
        return 0
    else
        log_error "Failed to update system packages"
        return 1
    fi
}

# Generate random password
generate_password() {
    local length="${1:-20}"

    # Generate password with uppercase, lowercase, and digits
    local password=$(LC_ALL=C tr -dc 'A-Za-z0-9' < /dev/urandom | head -c "$length")

    echo "$password"
}

# Show summary
show_summary() {
    echo ""
    echo -e "${BOLD}${CYAN}═══════════════════════════════════════${NC}"
    echo -e "${BOLD}${CYAN}    Installation Summary${NC}"
    echo -e "${BOLD}${CYAN}═══════════════════════════════════════${NC}"
    echo ""

    local services=("node" "docker" "mongod" "psql" "pm2")
    local names=("Node.js" "Docker" "MongoDB" "PostgreSQL" "PM2")

    for i in "${!services[@]}"; do
        local version=$(get_version "${services[$i]}")
        if [[ "$version" != "not installed" ]]; then
            echo -e "${GREEN}${CHECK}${NC} ${names[$i]}: ${BOLD}$version${NC}"
        fi
    done

    echo ""
    echo -e "${CYAN}Log file:${NC} $LOG_FILE"
    echo ""
}

################################################################################
# Version Management Utilities
################################################################################

# Get current version from VERSION file
get_version() {
    local script_dir="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
    local version_file="$script_dir/VERSION"

    if [[ -f "$version_file" ]]; then
        cat "$version_file" | tr -d '[:space:]'
    else
        echo "2.0.0"
    fi
}

# Set version in VERSION file
set_version() {
    local new_version="$1"
    local script_dir="${2:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
    local version_file="$script_dir/VERSION"

    # Validate version format (X.Y.Z)
    if ! [[ "$new_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        log_error "Invalid version format. Use X.Y.Z (e.g., 2.1.0)"
        return 1
    fi

    echo "$new_version" > "$version_file"
    log_success "Version updated to: $new_version"

    # Show files that read this version
    echo ""
    echo -e "${BOLD}Files using VERSION file:${NC}"
    echo "  - install.sh"
    echo "  - setup-global.sh"
    echo "  - test.sh"
    echo ""
    echo -e "${DIM}No need to edit these files manually${NC}"

    return 0
}

# Show current version
show_version() {
    local script_dir="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
    local version=$(get_version "$script_dir")

    echo ""
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo -e "${BOLD}Ubuntu Server Setup${NC}"
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo -e "${BOLD}Version:${NC} ${GREEN}$version${NC}"
    echo -e "${BOLD}Location:${NC} $script_dir/VERSION"
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo ""
}

# Bump version (major, minor, or patch)
bump_version() {
    local bump_type="$1"  # major, minor, or patch
    local script_dir="${2:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
    local current_version=$(get_version "$script_dir")

    # Parse current version
    local major=$(echo "$current_version" | cut -d. -f1)
    local minor=$(echo "$current_version" | cut -d. -f2)
    local patch=$(echo "$current_version" | cut -d. -f3)

    # Bump based on type
    case "$bump_type" in
        major)
            major=$((major + 1))
            minor=0
            patch=0
            ;;
        minor)
            minor=$((minor + 1))
            patch=0
            ;;
        patch)
            patch=$((patch + 1))
            ;;
        *)
            log_error "Invalid bump type. Use: major, minor, or patch"
            return 1
            ;;
    esac

    local new_version="$major.$minor.$patch"

    echo ""
    echo -e "${BOLD}Version Bump:${NC}"
    echo -e "  Current: ${DIM}$current_version${NC}"
    echo -e "  New:     ${GREEN}$new_version${NC}"
    echo ""

    if ask_yes_no "Update version to $new_version?" "y"; then
        set_version "$new_version" "$script_dir"
    else
        log_info "Version update cancelled"
        return 1
    fi
}
