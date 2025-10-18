#!/bin/bash

################################################################################
# Quick Validation Script
# Description: Quick syntax and structure validation before deployment
# Version: 2.0.0
################################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}╔════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║     Quick Validation v2.0.0            ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════╝${NC}"
echo ""

ERRORS=0

# 1. Check bash syntax
echo "1. Checking bash syntax..."
for file in install.sh status.sh update.sh cleanup.sh test.sh lib/*.sh modules/*.sh; do
    if [[ -f "$file" ]]; then
        if bash -n "$file" 2>/dev/null; then
            echo -e "  ${GREEN}✓${NC} $file"
        else
            echo -e "  ${RED}✗${NC} $file - Syntax error!"
            bash -n "$file"
            ((ERRORS++))
        fi
    fi
done
echo ""

# 2. Check module count
echo "2. Checking module count..."
MODULE_COUNT=$(ls modules/*.sh 2>/dev/null | wc -l)
if [[ "$MODULE_COUNT" -eq 12 ]]; then
    echo -e "  ${GREEN}✓${NC} Found 12 modules (correct)"
else
    echo -e "  ${RED}✗${NC} Found $MODULE_COUNT modules (expected 12)"
    ((ERRORS++))
fi
echo ""

# 3. Check required modules exist
echo "3. Checking required modules..."
REQUIRED_MODULES=(core mongodb postgresql nodejs pm2 docker nginx-unified security openvpn ssh-hardening redis monitoring)
for module in "${REQUIRED_MODULES[@]}"; do
    if [[ -f "modules/$module.sh" ]]; then
        echo -e "  ${GREEN}✓${NC} $module.sh"
    else
        echo -e "  ${RED}✗${NC} $module.sh - MISSING!"
        ((ERRORS++))
    fi
done
echo ""

# 4. Check deprecated files removed
echo "4. Checking deprecated files removed..."
DEPRECATED=(modules/nginx.sh modules/nginx-advanced.sh modules/cloudflare.sh)
for file in "${DEPRECATED[@]}"; do
    if [[ ! -f "$file" ]]; then
        echo -e "  ${GREEN}✓${NC} $file removed"
    else
        echo -e "  ${RED}✗${NC} $file - Should be removed!"
        ((ERRORS++))
    fi
done
echo ""

# 5. Check VERSION file
echo "5. Checking version..."
if [[ -f "VERSION" ]] && grep -q "2.0.0" VERSION; then
    echo -e "  ${GREEN}✓${NC} VERSION file: $(cat VERSION)"
else
    echo -e "  ${RED}✗${NC} VERSION file missing or incorrect"
    ((ERRORS++))
fi

if grep -q "Version: 2.0.0" install.sh; then
    echo -e "  ${GREEN}✓${NC} install.sh version header"
else
    echo -e "  ${RED}✗${NC} install.sh version mismatch"
    ((ERRORS++))
fi

if grep -q 'VERSION="2.0.0"' install.sh; then
    echo -e "  ${GREEN}✓${NC} install.sh VERSION variable"
else
    echo -e "  ${RED}✗${NC} install.sh VERSION variable missing"
    ((ERRORS++))
fi
echo ""

# 6. Check key functions exist
echo "6. Checking key functions..."
source lib/utils.sh 2>/dev/null
FUNCTIONS=(log_info log_success log_error generate_password backup_config)
for func in "${FUNCTIONS[@]}"; do
    if type "$func" &>/dev/null; then
        echo -e "  ${GREEN}✓${NC} $func()"
    else
        echo -e "  ${RED}✗${NC} $func() - MISSING!"
        ((ERRORS++))
    fi
done
echo ""

# 7. Check install.sh component references
echo "7. Checking component references..."
if grep -q "1 2 3 4 5 6 7 8 9 10 11 12" install.sh; then
    echo -e "  ${GREEN}✓${NC} Components 1-12 defined"
else
    echo -e "  ${YELLOW}⚠${NC}  Component array may be incorrect"
fi

if grep -q "13)" install.sh && ! grep -q "# 13)" install.sh; then
    echo -e "  ${RED}✗${NC} Component 13 still referenced (should be removed)"
    ((ERRORS++))
else
    echo -e "  ${GREEN}✓${NC} No component 13 references"
fi

if grep -q "14)" install.sh | grep -v "Ubuntu 24.04" && ! grep -q "# 14)" install.sh; then
    echo -e "  ${RED}✗${NC} Component 14 still referenced (should be removed)"
    ((ERRORS++))
else
    echo -e "  ${GREEN}✓${NC} No component 14 references"
fi

if grep -q "15)" install.sh && ! grep -q "# 15)" install.sh; then
    echo -e "  ${RED}✗${NC} Component 15 still referenced (should be removed)"
    ((ERRORS++))
else
    echo -e "  ${GREEN}✓${NC} No component 15 references"
fi
echo ""

# 8. Check unified module functions
echo "8. Checking unified module functions..."
if grep -q "configure_cloudflare_realip()" modules/nginx-unified.sh; then
    echo -e "  ${GREEN}✓${NC} nginx-unified has cloudflare function"
else
    echo -e "  ${RED}✗${NC} nginx-unified missing cloudflare function"
    ((ERRORS++))
fi

if grep -q "configure_nginx_advanced()" modules/nginx-unified.sh; then
    echo -e "  ${GREEN}✓${NC} nginx-unified has advanced config function"
else
    echo -e "  ${RED}✗${NC} nginx-unified missing advanced config function"
    ((ERRORS++))
fi

if grep -q "setup_redis_cluster()" modules/redis.sh; then
    echo -e "  ${GREEN}✓${NC} redis has cluster setup function"
else
    echo -e "  ${RED}✗${NC} redis missing cluster function"
    ((ERRORS++))
fi

if grep -q "create_ssh_user()" modules/ssh-hardening.sh; then
    echo -e "  ${GREEN}✓${NC} ssh-hardening has user creation function"
else
    echo -e "  ${RED}✗${NC} ssh-hardening missing user creation"
    ((ERRORS++))
fi
echo ""

# Summary
echo -e "${CYAN}════════════════════════════════════════${NC}"
if [[ $ERRORS -eq 0 ]]; then
    echo -e "${GREEN}✓ ALL VALIDATIONS PASSED${NC}"
    echo ""
    echo "Ready to test:"
    echo "  1. Run full test suite:  ./test.sh"
    echo "  2. Test dry-run mode:    sudo ./install.sh --dry-run"
    echo "  3. Test on Ubuntu VM:    Fresh Ubuntu 24.04 installation"
    echo ""
    exit 0
else
    echo -e "${RED}✗ VALIDATION FAILED - $ERRORS errors found${NC}"
    echo ""
    echo "Fix errors before testing"
    exit 1
fi
