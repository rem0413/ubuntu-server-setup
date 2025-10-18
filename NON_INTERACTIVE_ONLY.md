# Non-Interactive Installation Guide

## Your Environment Has No TTY

If diagnostic shows `TTY: not a tty`, you CANNOT use interactive menu.

## Solution: Use Command-Line Flags

### Option 1: Install All Components

```bash
curl -fsSL https://raw.githubusercontent.com/rem0413/ubuntu-server-setup/master/remote-install.sh | sudo bash -s -- --all
```

### Option 2: Use Profile (Recommended)

**Node.js Application Server:**
```bash
curl -fsSL https://raw.githubusercontent.com/rem0413/ubuntu-server-setup/master/remote-install.sh | sudo bash -s -- --profile nodejs-app
```
Installs: Core, MongoDB, Node.js, PM2, Nginx, Security

**Docker Host:**
```bash
curl -fsSL https://raw.githubusercontent.com/rem0413/ubuntu-server-setup/master/remote-install.sh | sudo bash -s -- --profile docker-host
```
Installs: Core, Docker, Security

**Full Stack Development:**
```bash
curl -fsSL https://raw.githubusercontent.com/rem0413/ubuntu-server-setup/master/remote-install.sh | sudo bash -s -- --profile fullstack
```
Installs: Core, MongoDB, PostgreSQL, Node.js, PM2, Docker, Nginx, Security

**VPN Server:**
```bash
curl -fsSL https://raw.githubusercontent.com/rem0413/ubuntu-server-setup/master/remote-install.sh | sudo bash -s -- --profile vpn-server
```
Installs: Core, Security, OpenVPN, SSH Hardening

### Option 3: Dry Run (Preview Only)

```bash
curl -fsSL https://raw.githubusercontent.com/rem0413/ubuntu-server-setup/master/remote-install.sh | sudo bash -s -- --dry-run --profile nodejs-app
```

## Why Interactive Mode Doesn't Work

Your session is missing a controlling terminal (tty). This happens when:
- Using web-based terminal/console
- Running via automation/CI/CD
- Using serial console
- Running in container
- SSH with specific flags

## Alternative: Clone and Run Locally

If you want interactive menu, SSH properly first:

```bash
# SSH with proper terminal allocation
ssh -t root@your-vps

# Then clone and run
git clone https://github.com/rem0413/ubuntu-server-setup.git
cd ubuntu-server-setup
sudo ./install.sh
```

## Profile Details

### nodejs-app
Components: 1, 2, 4, 5, 7, 8
- System Update & Essential Tools
- MongoDB Database
- Node.js & npm
- PM2 Process Manager
- Nginx Web Server
- Security Tools

### docker-host
Components: 1, 6, 8
- System Update & Essential Tools
- Docker & Docker Compose
- Security Tools

### fullstack
Components: 1, 2, 3, 4, 5, 6, 7, 8
- System Update & Essential Tools
- MongoDB Database
- PostgreSQL Database
- Node.js & npm
- PM2 Process Manager
- Docker & Docker Compose
- Nginx Web Server
- Security Tools

### vpn-server
Components: 1, 8, 9, 10
- System Update & Essential Tools
- Security Tools
- OpenVPN Server
- SSH Security Hardening

## Available Components

If you want custom selection, clone the repo:

1. System Update & Essential Tools
2. MongoDB Database
3. PostgreSQL Database
4. Node.js & npm
5. PM2 Process Manager
6. Docker & Docker Compose
7. Nginx Web Server
8. Security Tools (UFW, Fail2ban)
9. OpenVPN Server
10. SSH Security Hardening
11. Redis Cache Server
12. Monitoring Stack (Prometheus/Grafana)

## Troubleshooting

**Issue:** Command not working

**Check:**
1. Are you using sudo? `sudo bash`
2. Is URL correct? Check for typos
3. Try without pipe: Download first, then run

```bash
curl -fsSL https://raw.githubusercontent.com/rem0413/ubuntu-server-setup/master/remote-install.sh -o install.sh
sudo bash install.sh --profile nodejs-app
```
