# How to Test - Simple Guide

## Test 1: Simple Input Test

```bash
# Run normally
./test-simple.sh

# Run via pipe (simulates curl | bash)
cat test-simple.sh | bash
```

**Expected:** Both should accept keyboard input.

## Test 2: Menu Test (Local)

```bash
# Simulate remote install locally
cat remote-install.sh | sudo bash
```

**Expected:**
1. Menu shows up (plain text)
2. You can type numbers: `1 4 7 8`
3. Confirmation works
4. Script proceeds

## Test 3: On Real VPS

```bash
# SSH to your VPS
ssh root@your-vps-ip

# Run the installer
curl -fsSL https://raw.githubusercontent.com/rem0413/ubuntu-server-setup/master/remote-install.sh | sudo bash
```

**Expected Menu:**
```
=========================================
  Ubuntu Server Setup - Select Components
=========================================

Core:
  1. System Update & Essential Tools (Recommended)
  2. MongoDB Database
  3. PostgreSQL Database
  4. Node.js & npm
  5. PM2 Process Manager
  6. Docker & Docker Compose

Web & Security:
  7. Nginx Web Server
  8. Security Tools (UFW, Fail2ban)
  9. OpenVPN Server
 10. SSH Security Hardening

Additional:
 11. Redis Cache Server
 12. Monitoring Stack

Options:
  0 = Install All
  q = Quit

Enter numbers separated by spaces (e.g., 1 4 7 8):
>
```

**What to do:**
1. Type numbers: `1 4 7 8` (with spaces)
2. Press Enter
3. When asked to confirm, type: `yes`
4. Script installs

## If Input Still Doesn't Work

Use non-interactive mode:

```bash
# Install all
curl -fsSL https://raw.githubusercontent.com/rem0413/ubuntu-server-setup/master/remote-install.sh | sudo bash -s -- --all

# Or use profile
curl -fsSL https://raw.githubusercontent.com/rem0413/ubuntu-server-setup/master/remote-install.sh | sudo bash -s -- --profile nodejs-app
```

## Debug

If menu shows but input doesn't work:

```bash
# Check if /dev/tty exists
ls -l /dev/tty

# Try reading from it manually
read -r test < /dev/tty
echo "Got: $test"
```

If that works, the script should work too.

## Quick Profiles

```bash
# Node.js App Server
curl -fsSL URL | sudo bash -s -- --profile nodejs-app

# Docker Host
curl -fsSL URL | sudo bash -s -- --profile docker-host

# Full Stack
curl -fsSL URL | sudo bash -s -- --profile fullstack

# VPN Server
curl -fsSL URL | sudo bash -s -- --profile vpn-server
```

Replace `URL` with:
```
https://raw.githubusercontent.com/rem0413/ubuntu-server-setup/master/remote-install.sh
```
