#!/bin/bash

# Load dependencies
source "$(dirname "${BASH_SOURCE[0]}")/colors.sh"

# Show banner
show_banner() {
    clear
    echo -e "${CYAN}"
    cat << "EOF"
╔══════════════════════════════════════════════════════════════╗
║                                                              ║
║   ██╗   ██╗██████╗ ██╗   ██╗███╗   ██╗████████╗██╗   ██╗   ║
║   ██║   ██║██╔══██╗██║   ██║████╗  ██║╚══██╔══╝██║   ██║   ║
║   ██║   ██║██████╔╝██║   ██║██╔██╗ ██║   ██║   ██║   ██║   ║
║   ██║   ██║██╔══██╗██║   ██║██║╚██╗██║   ██║   ██║   ██║   ║
║   ╚██████╔╝██████╔╝╚██████╔╝██║ ╚████║   ██║   ╚██████╔╝   ║
║    ╚═════╝ ╚═════╝  ╚═════╝ ╚═╝  ╚═══╝   ╚═╝    ╚═════╝    ║
║                                                              ║
║          Ubuntu Server Setup Automation Script              ║
║                    Version 1.0.0                            ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

# Show main menu
show_menu() {
    local selections=$1

    if command -v whiptail &> /dev/null; then
        show_whiptail_menu
    else
        show_simple_menu "$selections"
    fi
}

# Whiptail-based interactive menu
show_whiptail_menu() {
    local options=(
        "1" "System Update & Essential Tools" ON
        "2" "MongoDB Database" OFF
        "3" "PostgreSQL Database" OFF
        "4" "Node.js & npm" OFF
        "5" "PM2 Process Manager" OFF
        "6" "Docker & Docker Compose" OFF
        "7" "Nginx Web Server" OFF
        "8" "Security Tools (UFW, Fail2ban)" OFF
        "9" "OpenVPN Server" OFF
        "10" "Cloudflare Real IP (Nginx)" OFF
        "11" "Advanced Nginx Config" OFF
        "12" "SSH Security Hardening" OFF
        "13" "Add OpenVPN Client" OFF
    )

    local choices=$(whiptail --title "Ubuntu Server Setup" \
        --checklist "Select components to install (Space to select, Enter to confirm):" \
        24 75 13 \
        "${options[@]}" \
        3>&1 1>&2 2>&3)

    if [[ $? -ne 0 ]]; then
        echo "cancelled"
        return 1
    fi

    echo "$choices" | tr -d '"'
}

# Simple text-based menu
show_simple_menu() {
    local selections="$1"

    echo ""
    echo "========================================="
    echo "  Ubuntu Server Setup - Select Components"
    echo "========================================="
    echo ""
    echo "Core:"
    echo "  1. System Update & Essential Tools (Recommended)"
    echo "  2. MongoDB Database"
    echo "  3. PostgreSQL Database"
    echo "  4. Node.js & npm"
    echo "  5. PM2 Process Manager"
    echo "  6. Docker & Docker Compose"
    echo ""
    echo "Web & Security:"
    echo "  7. Nginx Web Server"
    echo "  8. Security Tools (UFW, Fail2ban)"
    echo "  9. OpenVPN Server"
    echo " 10. SSH Security Hardening"
    echo ""
    echo "Additional:"
    echo " 11. Redis Cache Server"
    echo " 12. Monitoring Stack"
    echo ""
    echo "Options:"
    echo "  0 = Install All"
    echo "  q = Quit"
    echo ""
    echo "Enter numbers separated by spaces (e.g., 1 4 7 8):"
    printf "> "
}

# Confirm installation
confirm_installation() {
    local components="$1"

    echo ""
    echo "========================================="
    echo "  Installation Confirmation"
    echo "========================================="
    echo ""
    echo "The following components will be installed:"
    echo ""
    echo "$components"
    echo ""
    echo "WARNING: This will modify your system configuration"
    echo "Installation may take 10-30 minutes"
    echo ""
    printf "Continue? Type 'yes' to proceed: "

    # Read with timeout, handle piped input
    local response=""
    if [ -t 0 ]; then
        read -r response
    else
        read -r response < /dev/tty 2>/dev/null || response=""
    fi

    response=$(echo "$response" | tr '[:upper:]' '[:lower:]')

    if [[ "$response" == "yes" || "$response" == "y" ]]; then
        echo ""
        echo "Starting installation..."
        return 0
    else
        echo ""
        echo "Installation cancelled"
        return 1
    fi
}

# Show progress bar
progress_bar() {
    local current=$1
    local total=$2
    local message=$3
    local width=50

    local percentage=$((current * 100 / total))
    local filled=$((width * current / total))
    local empty=$((width - filled))

    printf "\r${CYAN}Progress:${NC} ["
    printf "%${filled}s" | tr ' ' '█'
    printf "%${empty}s" | tr ' ' '░'
    printf "] ${BOLD}%3d%%${NC} - %s" "$percentage" "$message"

    if [[ $current -eq $total ]]; then
        echo ""
    fi
}

# Show installation step
show_step() {
    local step=$1
    local total=$2
    local message=$3

    echo ""
    echo -e "${BOLD}${MAGENTA}[Step $step/$total]${NC} $message"
    echo -e "${DIM}$(date '+%Y-%m-%d %H:%M:%S')${NC}"
}

# Show error message
show_error() {
    local message="$1"
    echo ""
    echo -e "${RED}${BOLD}ERROR:${NC} $message"
    echo ""
}

# Show success message
show_success() {
    local message="$1"
    echo ""
    echo -e "${GREEN}${BOLD}${CHECK} SUCCESS:${NC} $message"
    echo ""
}

# Ask yes/no question
ask_yes_no() {
    local question="$1"
    local default="${2:-n}"

    local prompt
    if [[ "$default" == "y" ]]; then
        prompt="(Y/n)"
    else
        prompt="(y/N)"
    fi

    echo -n "$question $prompt: "

    local response=""
    if [ -t 0 ]; then
        read -r response
    else
        read -r response < /dev/tty 2>/dev/null || response="$default"
    fi

    response=${response:-$default}

    if [[ "$response" =~ ^[Yy]$ ]]; then
        return 0
    else
        return 1
    fi
}

# Get user input with default value
get_input() {
    local prompt="$1"
    local default="$2"
    local secret="${3:-false}"
    local response=""

    if [[ "$secret" == "true" ]]; then
        echo -n "$prompt: "
        if [ -t 0 ]; then
            read -s response
        else
            read -s response < /dev/tty 2>/dev/null || response=""
        fi
        echo ""
    else
        echo -n "$prompt"
        if [[ -n "$default" ]]; then
            echo -n " ${DIM}[$default]${NC}"
        fi
        echo -n ": "
        if [ -t 0 ]; then
            read -r response
        else
            read -r response < /dev/tty 2>/dev/null || response=""
        fi
    fi

    echo "${response:-$default}"
}
