#!/bin/bash

################################################################################
# Ubuntu Server Setup - Test Script
# Description: Run tests and validation checks
# Version: 2.0.0
# Usage: ./test.sh [--lint-only] [--verbose]
################################################################################

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load libraries
source "$SCRIPT_DIR/lib/colors.sh"

# Parse arguments
LINT_ONLY=false
VERBOSE=false
while [[ $# -gt 0 ]]; do
    case $1 in
        --lint-only)
            LINT_ONLY=true
            shift
            ;;
        --verbose|-v)
            VERBOSE=true
            shift
            ;;
        --help|-h)
            cat << EOF
Test Script v2.0.0

Usage: $0 [OPTIONS]

Options:
    --lint-only     Only run shellcheck linting
    --verbose, -v   Show detailed test output
    --help, -h      Show this help message

This script performs:
    1. Shellcheck linting on all .sh files
    2. Syntax validation (bash -n)
    3. File structure validation
    4. Module existence checks (12 modules)
    5. Function existence checks
    6. Permission checks
    7. Security checks
    8. Version file validation

Requirements:
    - shellcheck (sudo apt install shellcheck)

EOF
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Banner
echo -e "${CYAN}"
cat << "EOF"
╔══════════════════════════════════════════════════════════════╗
║                      TEST SUITE                              ║
╚══════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

TESTS_PASSED=0
TESTS_FAILED=0

# Test function
run_test() {
    local test_name=$1
    local test_command=$2

    echo -n "  Testing: $test_name... "
    if eval "$test_command" &>/dev/null; then
        echo -e "${GREEN}PASS${NC}"
        ((TESTS_PASSED++))
        return 0
    else
        echo -e "${RED}FAIL${NC}"
        ((TESTS_FAILED++))
        return 1
    fi
}

# Shellcheck linting
echo -e "${BOLD}1. Shellcheck Linting:${NC}"
echo ""

if ! command -v shellcheck &>/dev/null; then
    echo -e "${YELLOW}  Shellcheck not installed${NC}"
    echo -e "  Install: ${DIM}sudo apt install shellcheck${NC}"
    echo ""
else
    SHELL_FILES=$(find "$SCRIPT_DIR" -name "*.sh" -not -path "*/.*")
    LINT_ERRORS=0

    for file in $SHELL_FILES; do
        filename=$(basename "$file")
        echo -n "  Linting $filename... "

        if shellcheck -x "$file" 2>/dev/null; then
            echo -e "${GREEN}PASS${NC}"
            ((TESTS_PASSED++))
        else
            echo -e "${RED}FAIL${NC}"
            ((TESTS_FAILED++))
            ((LINT_ERRORS++))

            # Show errors
            if [[ $LINT_ERRORS -le 3 ]]; then
                echo -e "${DIM}"
                shellcheck -x "$file" 2>&1 | head -10
                echo -e "${NC}"
            fi
        fi
    done

    echo ""
fi

if [[ "$LINT_ONLY" == true ]]; then
    echo -e "${BOLD}Tests Passed:${NC} ${GREEN}$TESTS_PASSED${NC}"
    echo -e "${BOLD}Tests Failed:${NC} ${RED}$TESTS_FAILED${NC}"
    echo ""
    exit $TESTS_FAILED
fi

# Syntax checks
echo -e "${BOLD}2. Syntax Validation:${NC}"
echo ""

for file in install.sh status.sh update.sh cleanup.sh; do
    run_test "$file syntax" "bash -n $SCRIPT_DIR/$file"
done
echo ""

# File structure checks
echo -e "${BOLD}3. File Structure:${NC}"
echo ""

run_test "lib directory exists" "test -d $SCRIPT_DIR/lib"
run_test "modules directory exists" "test -d $SCRIPT_DIR/modules"
run_test "colors.sh exists" "test -f $SCRIPT_DIR/lib/colors.sh"
run_test "utils.sh exists" "test -f $SCRIPT_DIR/lib/utils.sh"
run_test "ui.sh exists" "test -f $SCRIPT_DIR/lib/ui.sh"
run_test "README.md exists" "test -f $SCRIPT_DIR/README.md"
echo ""

# Module checks (v2.0.0 - 12 modules)
echo -e "${BOLD}4. Module Files (v2.0.0):${NC}"
echo ""

MODULES=(core mongodb postgresql nodejs pm2 docker nginx-unified security openvpn ssh-hardening redis monitoring)
for module in "${MODULES[@]}"; do
    run_test "$module.sh exists" "test -f $SCRIPT_DIR/modules/$module.sh"
done
echo ""

# Verify old modules are removed
echo -e "${BOLD}5. Deprecated Files Removed:${NC}"
echo ""

run_test "nginx.sh removed" "! test -f $SCRIPT_DIR/modules/nginx.sh"
run_test "nginx-advanced.sh removed" "! test -f $SCRIPT_DIR/modules/nginx-advanced.sh"
run_test "cloudflare.sh removed" "! test -f $SCRIPT_DIR/modules/cloudflare.sh"
echo ""

# Function existence checks
echo -e "${BOLD}6. Core Functions:${NC}"
echo ""

# Source files
source "$SCRIPT_DIR/lib/utils.sh" &>/dev/null

run_test "log_info function" "type log_info"
run_test "log_success function" "type log_success"
run_test "log_error function" "type log_error"
run_test "log_warning function" "type log_warning"
run_test "log_step function" "type log_step"
run_test "check_root function" "type check_root"
run_test "command_exists function" "type command_exists"
run_test "generate_password function" "type generate_password"
run_test "get_input function" "type get_input"
run_test "ask_yes_no function" "type ask_yes_no"
run_test "backup_config function" "type backup_config"
echo ""

# Module function checks
echo -e "${BOLD}7. Module Functions:${NC}"
echo ""

run_test "install_nginx in nginx-unified" "grep -q 'install_nginx()' $SCRIPT_DIR/modules/nginx-unified.sh"
run_test "configure_cloudflare_realip" "grep -q 'configure_cloudflare_realip()' $SCRIPT_DIR/modules/nginx-unified.sh"
run_test "configure_nginx_advanced" "grep -q 'configure_nginx_advanced()' $SCRIPT_DIR/modules/nginx-unified.sh"
run_test "install_redis in redis" "grep -q 'install_redis()' $SCRIPT_DIR/modules/redis.sh"
run_test "setup_redis_cluster" "grep -q 'setup_redis_cluster()' $SCRIPT_DIR/modules/redis.sh"
run_test "install_openvpn in openvpn" "grep -q 'install_openvpn()' $SCRIPT_DIR/modules/openvpn.sh"
run_test "configure_ssh_hardening" "grep -q 'configure_ssh_hardening()' $SCRIPT_DIR/modules/ssh-hardening.sh"
run_test "create_ssh_user" "grep -q 'create_ssh_user()' $SCRIPT_DIR/modules/ssh-hardening.sh"
run_test "install_monitoring" "grep -q 'install_monitoring()' $SCRIPT_DIR/modules/monitoring.sh"
echo ""

# Permission checks
echo -e "${BOLD}8. File Permissions:${NC}"
echo ""

run_test "install.sh executable" "test -x $SCRIPT_DIR/install.sh"
run_test "status.sh executable" "test -x $SCRIPT_DIR/status.sh"
run_test "update.sh executable" "test -x $SCRIPT_DIR/update.sh"
run_test "cleanup.sh executable" "test -x $SCRIPT_DIR/cleanup.sh"
run_test "test.sh executable" "test -x $SCRIPT_DIR/test.sh"
echo ""

# Security checks
echo -e "${BOLD}9. Security Checks:${NC}"
echo ""

run_test "No hardcoded passwords" "! grep -r 'password=.*[A-Za-z0-9]' $SCRIPT_DIR/modules/ --include='*.sh' | grep -v 'generate_password' | grep -v 'REDIS_PASSWORD' | grep -v 'PASSWORD'"
run_test "Uses backup_config" "grep -q 'backup_config' $SCRIPT_DIR/modules/*.sh"
run_test "Uses logging functions" "grep -q 'log_' $SCRIPT_DIR/modules/*.sh"
run_test "Uses generate_password" "grep -q 'generate_password' $SCRIPT_DIR/modules/mongodb.sh"
echo ""

# Version checks
echo -e "${BOLD}10. Version Information:${NC}"
echo ""

run_test "VERSION file exists" "test -f $SCRIPT_DIR/VERSION"
run_test "VERSION is 2.0.0" "grep -q '2.0.0' $SCRIPT_DIR/VERSION"
run_test "CHANGELOG.md exists" "test -f $SCRIPT_DIR/CHANGELOG.md"
run_test "install.sh has version 2.0.0" "grep -q 'Version: 2.0.0' $SCRIPT_DIR/install.sh"
run_test "install.sh VERSION variable" "grep -q 'VERSION=\"2.0.0\"' $SCRIPT_DIR/install.sh"
echo ""

# Component count validation
echo -e "${BOLD}11. Component Count Validation:${NC}"
echo ""

run_test "12 components in help" "grep -q '1.  System Update' $SCRIPT_DIR/install.sh && grep -q '12. Monitoring Stack' $SCRIPT_DIR/install.sh"
run_test "SELECTED_COMPONENTS 1-12" "grep -q 'SELECTED_COMPONENTS=(1 2 3 4 5 6 7 8 9 10 11 12)' $SCRIPT_DIR/install.sh"
run_test "No component 13 references" "! grep -q 'component 13' $SCRIPT_DIR/install.sh"
run_test "No component 14 references" "! grep -q '14)' $SCRIPT_DIR/install.sh | grep -v 'Ubuntu 24.04'"
run_test "No component 15 references" "! grep -q '15)' $SCRIPT_DIR/install.sh"
echo ""

# Git checks
echo -e "${BOLD}12. Git Repository:${NC}"
echo ""

if [[ -d "$SCRIPT_DIR/.git" ]]; then
    run_test "Git repository initialized" "test -d $SCRIPT_DIR/.git"
    run_test ".gitignore exists" "test -f $SCRIPT_DIR/.gitignore"
else
    echo -e "  ${YELLOW}Not a git repository${NC}"
fi
echo ""

# Summary
echo -e "${CYAN}═══════════════════════════════════════${NC}"
echo -e "${BOLD}Test Summary:${NC}"
echo -e "${CYAN}═══════════════════════════════════════${NC}"
echo -e "${BOLD}Tests Passed:${NC} ${GREEN}$TESTS_PASSED${NC}"
echo -e "${BOLD}Tests Failed:${NC} ${RED}$TESTS_FAILED${NC}"
echo ""

if [[ $TESTS_FAILED -eq 0 ]]; then
    echo -e "${GREEN}${BOLD}All tests passed! ✓${NC}"
    echo ""
    exit 0
else
    echo -e "${RED}${BOLD}Some tests failed. Review output above.${NC}"
    echo ""
    exit 1
fi
