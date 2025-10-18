# Usage Guide

## Installation Methods

### Method 1: Global Install (Recommended) ⭐

**Install once, use forever:**

```bash
curl -fsSL https://raw.githubusercontent.com/rem0413/ubuntu-server-setup/master/install-global.sh | sudo bash
```

**Then use anywhere:**

```bash
# Interactive mode
ubuntu-setup install

# Install all
ubuntu-setup install --all

# Specific components
ubuntu-setup install --components 1 4 7 8

# Use profile
ubuntu-setup install --profile nodejs-app

# Update anytime
ubuntu-setup update
```

### Method 2: One-Time Remote

```bash
curl -fsSL https://raw.githubusercontent.com/rem0413/ubuntu-server-setup/master/remote-install.sh | sudo bash -s -- --all
```

### Method 3: Local Clone

```bash
git clone https://github.com/rem0413/ubuntu-server-setup.git
cd ubuntu-server-setup
sudo ./install.sh
```

## Common Commands

### After Global Install

```bash
# Interactive menu
ubuntu-setup install

# Install everything
ubuntu-setup install --all

# Node.js stack
ubuntu-setup install --profile nodejs-app

# Custom components
ubuntu-setup install --components 1 4 7 8

# Update ubuntu-setup itself
ubuntu-setup update

# Show version
ubuntu-setup version

# Show help
ubuntu-setup help

# Uninstall ubuntu-setup command
ubuntu-setup uninstall
```

### One-Time Remote

```bash
# All components
curl -fsSL URL | sudo bash -s -- --all

# Specific components
curl -fsSL URL | sudo bash -s -- --components 1 4 7 8

# Profile
curl -fsSL URL | sudo bash -s -- --profile nodejs-app
```

Replace `URL` with:
```
https://raw.githubusercontent.com/rem0413/ubuntu-server-setup/master/remote-install.sh
```

## Profiles

| Profile | Components | Use Case |
|---------|-----------|----------|
| `nodejs-app` | MongoDB + Node.js + PM2 + Nginx + Security | Web apps, APIs |
| `docker-host` | Docker + Security | Container hosting |
| `fullstack` | All databases + Node.js + Docker + Nginx | Development |
| `vpn-server` | OpenVPN + SSH Hardening + Security | VPN gateway |

## Components

| # | Component | Description |
|---|-----------|-------------|
| 1 | System Tools | Build essentials, git, curl, vim |
| 2 | MongoDB | NoSQL database |
| 3 | PostgreSQL | Relational database |
| 4 | Node.js | JavaScript runtime |
| 5 | PM2 | Process manager |
| 6 | Docker | Container platform |
| 7 | Nginx | Web server |
| 8 | Security | UFW + Fail2ban |
| 9 | OpenVPN | VPN server |
| 10 | SSH Hardening | SSH security |
| 11 | Redis | Cache server |
| 12 | Monitoring | Prometheus + Grafana + Exporters |

## Examples

### Fresh VPS Setup

```bash
# Install globally
curl -fsSL https://raw.githubusercontent.com/rem0413/ubuntu-server-setup/master/install-global.sh | sudo bash

# Install Node.js stack
ubuntu-setup install --profile nodejs-app

# Done! Deploy your app
```

### Development Environment

```bash
# Global install
curl -fsSL URL/install-global.sh | sudo bash

# Full stack
ubuntu-setup install --profile fullstack

# Update later
ubuntu-setup update
```

### Specific Components Only

```bash
# Global install
curl -fsSL URL/install-global.sh | sudo bash

# Just what you need
ubuntu-setup install --components 1 6 8
# (Core + Docker + Security)
```

### Quick One-Time Install

```bash
# No global install, just run once
curl -fsSL https://raw.githubusercontent.com/rem0413/ubuntu-server-setup/master/remote-install.sh | sudo bash -s -- --profile nodejs-app
```

## Update Methods

### Global Install

```bash
# Update the ubuntu-setup command itself
ubuntu-setup update

# Then use as normal
ubuntu-setup install --components 11 12
```

### One-Time Usage

```bash
# Just re-run with latest from GitHub
curl -fsSL URL | sudo bash -s -- --all
```

### Local Clone

```bash
cd ubuntu-server-setup
git pull
sudo ./install.sh
```

## Which Method to Use?

| Scenario | Best Method | Why |
|----------|-------------|-----|
| **Regular use on VPS** | Global Install | Easy updates, use anywhere |
| **One-time setup** | Remote Install | Quick, no local files |
| **Development/testing** | Local Clone | Full control, easy to modify |
| **Automation/CI** | Remote with flags | Scriptable, no interaction |

## Tips

1. **Use global install** if you manage multiple VPS or update frequently
2. **Use profiles** for common setups instead of selecting components
3. **Run `ubuntu-setup update`** regularly to get latest fixes
4. **Use `--dry-run`** to preview before installing
5. **Check summary** file at `/root/ubuntu-setup-summary.txt`

## Getting Help

```bash
# After global install
ubuntu-setup help

# Or check docs
https://github.com/rem0413/ubuntu-server-setup
```

## Summary

**Recommended workflow:**

```bash
# 1. Install globally (one time)
curl -fsSL https://raw.githubusercontent.com/rem0413/ubuntu-server-setup/master/install-global.sh | sudo bash

# 2. Use it
ubuntu-setup install --profile nodejs-app

# 3. Update when needed
ubuntu-setup update

# 4. Install more components anytime
ubuntu-setup install --components 11 12
```

That's it! 🚀
