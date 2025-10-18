# Testing Guide

Complete testing guide for Ubuntu Server Setup v2.0.0

## Quick Test

Run automated test suite:

```bash
# Run all tests
./test.sh

# Run only shellcheck linting
./test.sh --lint-only

# Verbose output
./test.sh --verbose
```

## Test Categories

### 1. Automated Tests (./test.sh)

The test suite validates:

- **Shellcheck Linting** - Code quality and best practices
- **Syntax Validation** - Bash syntax correctness (bash -n)
- **File Structure** - lib/, modules/, docs/ directories
- **Module Files** - All 12 modules exist
- **Deprecated Files** - Old modules removed (nginx.sh, nginx-advanced.sh, cloudflare.sh)
- **Core Functions** - Logging, utilities, password generation
- **Module Functions** - Install/configure functions present
- **File Permissions** - Executable scripts
- **Security** - No hardcoded passwords, uses encryption
- **Version** - VERSION file, CHANGELOG.md, version strings
- **Component Count** - 12 components, no 13/14/15 references

### 2. Dry-Run Testing

Preview installation without making changes:

```bash
# Test interactive mode
sudo ./install.sh --dry-run

# Test all components
sudo ./install.sh --all --dry-run

# Test specific profile
sudo ./install.sh --profile nodejs-app --dry-run
```

### 3. Module-by-Module Testing

Test each module individually on a fresh Ubuntu 24.04 VM:

#### System Requirements

- Ubuntu 20.04+ (24.04 LTS recommended)
- 2GB+ RAM
- 10GB+ disk space
- Internet connection
- Root/sudo access

#### Testing Each Component

**Component 1: System Update**
```bash
sudo ./install.sh
# Select: 1
# Verify: build-essential, git, curl, wget, vim installed
```

**Component 2: MongoDB**
```bash
sudo ./install.sh
# Select: 2
# Save displayed password
# Test: mongosh -u admin -p 'SAVED_PASSWORD'
# Verify: systemctl status mongod
```

**Component 3: PostgreSQL**
```bash
sudo ./install.sh
# Select: 3
# Save displayed password and connection string
# Test: PGPASSWORD='SAVED_PASSWORD' psql -h localhost -U dbuser -d dbname
# Verify: systemctl status postgresql
```

**Component 4: Node.js**
```bash
sudo ./install.sh
# Select: 4
# Choose version: 20.x (LTS recommended)
# Test: node --version && npm --version
# Verify: which node && which npm
```

**Component 5: PM2**
```bash
sudo ./install.sh
# Select: 5 (requires Node.js - component 4)
# Test: pm2 --version
# Test: pm2 list
# Verify: pm2 startup shows systemd config
```

**Component 6: Docker**
```bash
sudo ./install.sh
# Select: 6
# Test: docker --version && docker compose version
# Test: docker run hello-world
# Verify: docker ps (should work without sudo after re-login)
```

**Component 7: Nginx Unified**
```bash
sudo ./install.sh
# Select: 7
# Choose: 1) Install Nginx
# Then re-run and select 7:
#   - Test Configure Advanced Settings (try all 6 modes)
#   - Test Setup Cloudflare Real IP
# Verify: systemctl status nginx
# Verify: nginx -t
# Verify: ls /etc/nginx/sites-available/
# Verify: cat /etc/nginx/conf.d/cloudflare-realip.conf
```

**Component 8: Security**
```bash
sudo ./install.sh
# Select: 8
# Configure UFW rules
# Test: sudo ufw status verbose
# Test: sudo fail2ban-client status
# Test: sudo fail2ban-client status sshd
```

**Component 9: OpenVPN**
```bash
sudo ./install.sh
# Select: 9
# Choose: 1) Setup OpenVPN Server
# Configure port, protocol, DNS
# Then re-run and select 9:
#   - Test Add VPN Client (create client1)
#   - Test List Clients
# Verify: systemctl status openvpn-server@server
# Verify: ls /etc/openvpn/client-configs/files/client1.ovpn
# Test .ovpn file on client device
```

**Component 10: SSH Hardening**
```bash
sudo ./install.sh
# Select: 10
# Test all 5 options:
#   1) Quick hardening
#   2) Create SSH user (create testuser)
#   3) Add/manage SSH keys
#   4) Change SSH port (try custom port)
#   5) Show current configuration
# Verify: sudo sshd -t
# Verify: grep -E "^(Port|PermitRootLogin)" /etc/ssh/sshd_config
# IMPORTANT: Test SSH connection in NEW terminal before closing current
```

**Component 11: Redis**
```bash
sudo ./install.sh
# Select: 11
# Test Standalone mode:
#   - Choose port (default 6379 or custom)
#   - Save displayed password
# Test: redis-cli -p PORT -a 'PASSWORD' ping
# Verify: systemctl status redis-server

# Test Cluster mode (on separate VM):
#   - Choose cluster mode
#   - Choose base port
# Test: redis-cli -c -p BASE_PORT -a 'PASSWORD' cluster info
# Verify: systemctl status redis-cluster-*
```

**Component 12: Monitoring**
```bash
sudo ./install.sh
# Select: 12
# Choose exporters (try multiple):
#   - 3) node_exporter (always recommended)
#   - 4) mysqld_exporter (if MongoDB installed)
#   - Others as needed
# Verify: systemctl status prometheus
# Verify: systemctl status grafana-server
# Verify: systemctl status node_exporter
# Test: curl http://localhost:9090 (Prometheus)
# Test: curl http://localhost:3000 (Grafana - admin/admin)
# Test: curl http://localhost:9100/metrics (node_exporter)
```

### 4. Profile Testing

Test predefined installation profiles:

**nodejs-app Profile**
```bash
sudo ./install.sh --profile nodejs-app
# Installs: 1, 2, 4, 5, 7, 8
# Verify all 6 components installed and running
```

**docker-host Profile**
```bash
sudo ./install.sh --profile docker-host
# Installs: 1, 6, 8
# Verify Docker working without sudo (after re-login)
```

**fullstack Profile**
```bash
sudo ./install.sh --profile fullstack
# Installs: 1, 2, 3, 4, 5, 6, 7, 8
# Verify all 8 components installed
```

**vpn-server Profile**
```bash
sudo ./install.sh --profile vpn-server
# Installs: 1, 8, 9, 10
# Verify VPN server + SSH hardening configured
```

### 5. Edge Case Testing

**Test Installation Summary**
```bash
# After any installation
cat /root/ubuntu-setup-summary.txt
# Verify correct components listed
# Verify credentials saved (MongoDB, PostgreSQL, Redis)
```

**Test Logs**
```bash
# Check installation logs
sudo tail -100 /var/log/ubuntu-setup.log
# Should show no errors
```

**Test Config Backups**
```bash
# Verify backups created
ls -la /var/backups/ubuntu-setup/
# Should show timestamped backups
```

**Test Re-running Installation**
```bash
# Run install twice with same component
sudo ./install.sh  # Select component 7
sudo ./install.sh  # Select component 7 again
# Should handle gracefully (idempotent)
```

**Test Component Removal**
```bash
# Test cleanup (if cleanup.sh exists)
sudo ./cleanup.sh --component nginx
sudo ./cleanup.sh --component mongodb --purge
```

### 6. Integration Testing

**Full Stack Test**
```bash
# Install full stack
sudo ./install.sh --all

# Deploy test application
mkdir -p /var/www/test-app
cd /var/www/test-app
npm init -y
npm install express

# Create test server
cat > server.js << 'EOF'
const express = require('express');
const app = express();
app.get('/', (req, res) => res.send('Hello from Ubuntu Setup!'));
app.listen(3000, () => console.log('Server running on port 3000'));
EOF

# Start with PM2
pm2 start server.js --name test-app
pm2 save

# Test locally
curl http://localhost:3000

# Configure Nginx reverse proxy (if Nginx installed)
# Test external access
```

**Database Connection Test**
```bash
# Test MongoDB
mongosh -u admin -p 'PASSWORD' --eval 'db.version()'

# Test PostgreSQL
PGPASSWORD='PASSWORD' psql -h localhost -U dbuser -d dbname -c 'SELECT version();'

# Test Redis
redis-cli -a 'PASSWORD' ping
```

**Monitoring Stack Test**
```bash
# Access Grafana
curl http://localhost:3000/login

# Access Prometheus
curl http://localhost:9090/api/v1/status/config

# Check exporters
curl http://localhost:9100/metrics | grep node_
```

### 7. Performance Testing

**Resource Usage**
```bash
# Check system resources after installation
free -h
df -h
systemctl list-units --type=service --state=running
```

**Service Startup Time**
```bash
systemd-analyze blame | head -20
```

### 8. Security Testing

**Firewall Verification**
```bash
sudo ufw status numbered
# Verify only necessary ports open
```

**SSH Hardening Verification**
```bash
sudo sshd -t
grep -E "^(Port|PermitRootLogin|PasswordAuthentication|PubkeyAuthentication)" /etc/ssh/sshd_config
```

**Password Generation Verification**
```bash
# Verify no plaintext passwords in logs
sudo grep -i password /var/log/ubuntu-setup.log | grep -v generate_password
```

## Common Issues

### Shellcheck Not Installed
```bash
sudo apt update
sudo apt install shellcheck
```

### Permission Denied
```bash
# Make scripts executable
chmod +x *.sh
```

### Module Not Found
```bash
# Verify all modules present
ls -la modules/
# Should show 12 modules
```

### Test Failures
```bash
# Run verbose mode
./test.sh --verbose

# Check specific module syntax
bash -n modules/nginx-unified.sh
```

## Test Checklist

- [ ] All automated tests pass (`./test.sh`)
- [ ] Shellcheck passes on all files
- [ ] Syntax validation passes (bash -n)
- [ ] All 12 modules present
- [ ] Old modules removed (nginx.sh, nginx-advanced.sh, cloudflare.sh)
- [ ] VERSION file shows 2.0.0
- [ ] Dry-run mode works
- [ ] Interactive installation works
- [ ] All 4 profiles install correctly
- [ ] Each component installs individually
- [ ] Services start and run properly
- [ ] Passwords generated and displayed
- [ ] SSH hardening doesn't lock out user
- [ ] Config backups created
- [ ] Installation summary generated
- [ ] Logs show no errors
- [ ] Re-installation is idempotent

## CI/CD Integration

For automated testing in CI/CD:

```bash
#!/bin/bash
# ci-test.sh

set -e

# Run linting
./test.sh --lint-only

# Run syntax checks
bash -n install.sh
bash -n modules/*.sh

# Verify structure
test -f VERSION
test -f CHANGELOG.md
grep -q "2.0.0" VERSION

# Count modules
MODULE_COUNT=$(ls modules/*.sh | wc -l)
if [ "$MODULE_COUNT" -ne 12 ]; then
    echo "Expected 12 modules, found $MODULE_COUNT"
    exit 1
fi

echo "All CI tests passed!"
```

## Manual Testing VM Setup

Recommended VM configuration for testing:

```bash
# Using VirtualBox/VMware/Multipass
# Ubuntu 24.04 LTS
# 2GB RAM minimum
# 20GB disk space
# NAT + Host-only network

# Clone and test
git clone <repo-url>
cd ubuntu-server-setup
./test.sh
sudo ./install.sh --dry-run
```

## Reporting Issues

When reporting test failures, include:

1. Test output from `./test.sh`
2. Ubuntu version: `lsb_release -a`
3. Log file: `sudo tail -100 /var/log/ubuntu-setup.log`
4. Component being tested
5. Expected vs actual behavior
