# Global Installation Guide

Install Ubuntu Setup as a global command that you can use anywhere.

## Quick Install

```bash
curl -fsSL https://raw.githubusercontent.com/rem0413/ubuntu-server-setup/master/install-global.sh | sudo bash
```

This installs `ubuntu-setup` command globally.

## Usage After Installation

### Install Components

```bash
# Interactive mode (shows menu)
ubuntu-setup install

# Install all components
ubuntu-setup install --all

# Install specific components
ubuntu-setup install --components 1 4 7 8

# Use predefined profile
ubuntu-setup install --profile nodejs-app
```

### Update Command

```bash
# Update ubuntu-setup to latest version from GitHub
ubuntu-setup update
```

### Other Commands

```bash
# Show version
ubuntu-setup version

# Show help
ubuntu-setup help

# Uninstall
ubuntu-setup uninstall
```

## Available Profiles

**nodejs-app**
```bash
ubuntu-setup install --profile nodejs-app
```
Installs: MongoDB, Node.js, PM2, Nginx, Security

**docker-host**
```bash
ubuntu-setup install --profile docker-host
```
Installs: Docker, Docker Compose, Security

**fullstack**
```bash
ubuntu-setup install --profile fullstack
```
Installs: MongoDB, PostgreSQL, Node.js, PM2, Docker, Nginx, Security

**vpn-server**
```bash
ubuntu-setup install --profile vpn-server
```
Installs: OpenVPN, SSH Hardening, Security

## Components

Select individual components in interactive mode or use `--components`:

```bash
ubuntu-setup install --components 1 4 5 7 8
```

Available components:
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
12. Monitoring Stack

## Installation Location

- **Installation directory:** `/opt/ubuntu-setup`
- **Command link:** `/usr/local/bin/ubuntu-setup`
- **Repository:** Cloned from GitHub

## Update Process

When you run `ubuntu-setup update`:
1. Pulls latest changes from GitHub
2. Updates all scripts in `/opt/ubuntu-setup`
3. Command remains available immediately

## Examples

### First Time Setup

```bash
# Install globally
curl -fsSL https://raw.githubusercontent.com/rem0413/ubuntu-server-setup/master/install-global.sh | sudo bash

# Install Node.js stack
ubuntu-setup install --profile nodejs-app

# Later, update the command
ubuntu-setup update
```

### Development Server

```bash
# Install globally
curl -fsSL URL | sudo bash

# Install specific components
ubuntu-setup install --components 1 2 4 5 7 8

# Update anytime
ubuntu-setup update
```

### Production Server

```bash
# Install globally
curl -fsSL URL | sudo bash

# Full stack installation
ubuntu-setup install --profile fullstack

# Keep updated
ubuntu-setup update
```

## Advantages

✅ **Available everywhere:** Just type `ubuntu-setup`
✅ **Easy updates:** One command to update: `ubuntu-setup update`
✅ **No re-download:** Scripts stored locally in `/opt/ubuntu-setup`
✅ **Version control:** Uses git, always latest from GitHub
✅ **Clean uninstall:** `ubuntu-setup uninstall` removes everything

## Comparison

| Method | Command | Update |
|--------|---------|--------|
| **Global Install** | `ubuntu-setup install --all` | `ubuntu-setup update` |
| Remote One-Time | `curl URL \| bash -s -- --all` | Re-run full curl command |
| Local Clone | `cd dir && sudo ./install.sh --all` | `git pull && sudo ./install.sh` |

## Uninstall

```bash
ubuntu-setup uninstall
```

This removes:
- `/opt/ubuntu-setup` directory
- `/usr/local/bin/ubuntu-setup` command
- Does NOT remove installed components (MongoDB, Docker, etc.)

To remove installed components, use the cleanup script before uninstalling.

## Troubleshooting

**Command not found after install:**
```bash
# Check if installed
ls -l /usr/local/bin/ubuntu-setup

# Reinstall
curl -fsSL URL | sudo bash
```

**Update fails:**
```bash
# Manual update
cd /opt/ubuntu-setup
sudo git pull
```

**Permission denied:**
```bash
# Must use sudo
sudo ubuntu-setup install --all
```

## Local Installation (Alternative)

If you prefer local installation without global command:

```bash
git clone https://github.com/rem0413/ubuntu-server-setup.git
cd ubuntu-server-setup
sudo ./install.sh
```
