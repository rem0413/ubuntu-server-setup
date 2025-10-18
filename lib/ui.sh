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
    echo -e "${BOLD}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}║           Select Components to Install                      ║${NC}"
    echo -e "${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${CYAN}═══ Core Installation ═══${NC}"
    echo -e "  ${GREEN}[1]${NC}  System Update & Essential Tools ${DIM}(Recommended)${NC}"
    echo -e "  ${GREEN}[2]${NC}  MongoDB Database"
    echo -e "  ${GREEN}[3]${NC}  PostgreSQL Database"
    echo -e "  ${GREEN}[4]${NC}  Node.js & npm"
    echo -e "  ${GREEN}[5]${NC}  PM2 Process Manager ${DIM}(Requires Node.js)${NC}"
    echo -e "  ${GREEN}[6]${NC}  Docker & Docker Compose"
    echo ""
    echo -e "${CYAN}═══ Web & Security ═══${NC}"
    echo -e "  ${GREEN}[7]${NC}  Nginx Web Server (Cloudflare & Advanced Config)"
    echo -e "  ${GREEN}[8]${NC}  Security Tools (UFW, Fail2ban)"
    echo -e "  ${GREEN}[9]${NC}  OpenVPN Server & Client Management"
    echo -e "  ${GREEN}[10]${NC} SSH Security Hardening"
    echo ""
    echo -e "${CYAN}═══ Additional Services ═══${NC}"
    echo -e "  ${GREEN}[11]${NC} Redis Cache Server"
    echo -e "  ${GREEN}[12]${NC} Monitoring Stack (Prometheus/Grafana)"
    echo ""
    echo -e "${CYAN}═══ Quick Options ═══${NC}"
    echo -e "  ${YELLOW}[0]${NC}  Install All Components"
    echo -e "  ${RED}[q]${NC}  Quit Installation"
    echo ""
    if [[ -n "$selections" ]]; then
        echo -e "${DIM}Current selection: $selections${NC}"
        echo ""
    fi
    echo -e "${BOLD}Enter your choice:${NC}"
    echo -e "${DIM}  - Single component: 1${NC}"
    echo -e "${DIM}  - Multiple components: 1 2 4 6 8${NC}"
    echo -e "${DIM}  - All components: 0${NC}"
    echo -e "${DIM}  - Cancel: q${NC}"
    echo ""
    echo -n "> "
}

# Confirm installation
confirm_installation() {
    local components="$1"

    echo ""
    echo -e "${BOLD}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}║              Installation Confirmation                      ║${NC}"
    echo -e "${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${CYAN}The following components will be installed:${NC}"
    echo ""
    echo -e "$components"
    echo ""
    echo -e "${YELLOW}⚠️  This will modify your system configuration${NC}"
    echo -e "${DIM}   Installation may take 10-30 minutes depending on components${NC}"
    echo ""
    echo -e "${BOLD}Do you want to continue?${NC}"
    echo -n "Type 'yes' to proceed, or 'no' to cancel: "

    # Read with timeout, handle piped input
    local response=""
    if [ -t 0 ]; then
        # stdin is a terminal, read normally
        read -r -t 60 response 2>/dev/null
    else
        # stdin is piped, try to read from /dev/tty
        read -r -t 60 response < /dev/tty 2>/dev/null || response=""
    fi

    if [[ -n "$response" ]]; then
        response=$(echo "$response" | xargs | tr '[:upper:]' '[:lower:]')

        if [[ "$response" == "yes" || "$response" == "y" ]]; then
            echo ""
            echo -e "${GREEN}✓ Starting installation...${NC}"
            return 0
        else
            echo ""
            echo -e "${RED}✗ Installation cancelled${NC}"
            return 1
        fi
    else
        echo ""
        echo -e "${RED}✗ No input received - installation cancelled${NC}"
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
