# Use Cases & Examples

Practical examples for common server setup scenarios using the Ubuntu Server Setup automation script.

## Table of Contents

1. [Node.js Application Server](#nodejs-application-server)
2. [Full Stack Development Environment](#full-stack-development-environment)
3. [Docker Container Host](#docker-container-host)
4. [Database Server](#database-server)
5. [Web Server with Reverse Proxy](#web-server-with-reverse-proxy)
6. [VPN Server](#vpn-server)
7. [Production Web Application](#production-web-application)

---

## Node.js Application Server

**Goal:** Setup server for deploying Node.js applications with MongoDB

**Time:** ~15 minutes

### 1. Run Installation

```bash
# Using profile (recommended)
sudo ./install.sh --profile nodejs-app

# Or interactive selection
sudo ./install.sh
# Select: 1, 2, 4, 5, 7, 8
```

**Components installed:**
- System essentials
- MongoDB (with random password)
- Node.js 20 LTS
- PM2 process manager
- Nginx
- Security (UFW + Fail2ban)

### 2. Save MongoDB Credentials

**IMPORTANT:** Credentials are displayed once - copy them now!

```
MongoDB Credentials:
  Host: localhost
  Port: 27017
  Admin User: admin
  Password: Abc123XyzDef456Ghijk  (SAVE THIS!)

  Connection string:
  mongodb://admin:Abc123XyzDef456Ghijk@localhost:27017/admin
```

### 3. Deploy Your App

```bash
# Clone your repository
cd /var/www
git clone https://github.com/yourusername/your-node-app.git
cd your-node-app

# Install dependencies
npm install

# Update config with MongoDB credentials
nano .env

# Start with PM2
pm2 start app.js --name my-app
pm2 save
pm2 startup
```

### 4. Configure Nginx

```bash
# Create nginx config
sudo nano /etc/nginx/sites-available/my-app

# Add configuration
server {
    listen 80;
    server_name yourdomain.com;

    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }
}

# Enable site
sudo ln -s /etc/nginx/sites-available/my-app /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx

# Open firewall
sudo ufw allow 'Nginx Full'
```

### 5. Verify

```bash
# Check services
sudo ./status.sh

# Check PM2
pm2 list
pm2 logs my-app

# Test application
curl http://localhost:3000
curl http://yourdomain.com
```

**Result:** Production-ready Node.js app with MongoDB, process manager, and web server.

---

## Full Stack Development Environment

**Goal:** Complete development environment with multiple databases and Docker

**Time:** ~25 minutes

### 1. Run Installation

```bash
sudo ./install.sh --profile fullstack
```

**Components:**
- System essentials
- MongoDB
- PostgreSQL
- Node.js
- PM2
- Docker
- Nginx
- Security tools

### 2. Save Database Credentials

Save both MongoDB and PostgreSQL credentials shown during installation.

### 3. Setup Development

```bash
# Create project directory
mkdir -p ~/projects
cd ~/projects

# Clone multiple projects
git clone repo1
git clone repo2

# Run database migrations
cd repo1
npm install
npm run migrate  # Uses PostgreSQL credentials

# Start services with Docker Compose
docker compose up -d redis rabbitmq

# Start Node.js apps with PM2
pm2 start ecosystem.config.js
```

### 4. Verify Environment

```bash
# Check all services
sudo ./status.sh

# Test databases
mongosh -u admin -p
psql -U dbuser -h localhost

# Check Docker containers
docker ps

# Check PM2 processes
pm2 list
```

**Result:** Complete development environment ready for full-stack work.

---

## Docker Container Host

**Goal:** Minimal server optimized for running Docker containers

**Time:** ~10 minutes

### 1. Run Installation

```bash
sudo ./install.sh --profile docker-host
```

**Components:**
- System essentials
- Docker + Docker Compose
- Security (UFW + Fail2ban)

### 2. Deploy Containers

```bash
# Create docker-compose.yml
mkdir -p ~/docker
cd ~/docker
nano docker-compose.yml
```

**Example: Web application stack**
```yaml
version: '3.8'

services:
  app:
    image: node:20-alpine
    volumes:
      - ./app:/usr/src/app
    working_dir: /usr/src/app
    command: npm start
    ports:
      - "3000:3000"
    environment:
      - NODE_ENV=production

  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf
    depends_on:
      - app

  redis:
    image: redis:alpine
    ports:
      - "6379:6379"
```

```bash
# Start services
docker compose up -d

# Check status
docker compose ps
docker compose logs -f
```

### 3. Manage Containers

```bash
# View logs
docker compose logs -f app

# Restart service
docker compose restart app

# Update images
docker compose pull
docker compose up -d

# Cleanup
docker system prune -a
```

**Result:** Lightweight Docker host ready for containerized applications.

---

## Database Server

**Goal:** Dedicated database server with MongoDB and PostgreSQL

**Time:** ~15 minutes

### 1. Run Installation

```bash
sudo ./install.sh
# Select: 1, 2, 3, 8
```

### 2. Configure Remote Access

**MongoDB:**
```bash
sudo nano /etc/mongod.conf

# Change bindIp
net:
  bindIp: 0.0.0.0

# Restart
sudo systemctl restart mongod

# Allow through firewall
sudo ufw allow from YOUR_APP_SERVER_IP to any port 27017
```

**PostgreSQL:**
```bash
sudo nano /etc/postgresql/16/main/postgresql.conf
# Change: listen_addresses = '*'

sudo nano /etc/postgresql/16/main/pg_hba.conf
# Add: host all all YOUR_APP_SERVER_IP/32 md5

sudo systemctl restart postgresql
sudo ufw allow from YOUR_APP_SERVER_IP to any port 5432
```

### 3. Create Application Databases

**MongoDB:**
```bash
mongosh -u admin -p

use myapp_production
db.createUser({
  user: "appuser",
  pwd: "strongpassword",
  roles: ["readWrite"]
})
```

**PostgreSQL:**
```bash
sudo -u postgres psql

CREATE DATABASE myapp_production;
CREATE USER appuser WITH PASSWORD 'strongpassword';
GRANT ALL PRIVILEGES ON DATABASE myapp_production TO appuser;
```

### 4. Backup Strategy

```bash
# MongoDB backup
mongodump --uri="mongodb://admin:password@localhost:27017" --out=/backup/mongo-$(date +%Y%m%d)

# PostgreSQL backup
pg_dump -U appuser myapp_production > /backup/postgres-$(date +%Y%m%d).sql

# Automate with cron
crontab -e
# Add: 0 2 * * * /path/to/backup-script.sh
```

**Result:** Secure database server with remote access configured.

---

## Web Server with Reverse Proxy

**Goal:** High-performance web server with advanced Nginx configuration

**Time:** ~20 minutes

### 1. Run Installation

```bash
sudo ./install.sh
# Select: 1, 7, 8, 10, 11
```

### 2. Configure Advanced Nginx

During installation, select:
- Option 11: Advanced Nginx Configuration
- Choose: All configurations (option 6)

This enables:
- Performance optimization
- Security headers
- SSL/TLS hardening
- Rate limiting
- Caching

### 3. Setup Multiple Sites

```bash
# Copy reverse proxy template
cd /etc/nginx/sites-available
sudo cp reverse-proxy-template api.example.com

# Edit for your API
sudo nano api.example.com

# Update:
upstream backend {
    server 127.0.0.1:3000;
}

server {
    listen 80;
    server_name api.example.com;
    # ... rest of config
}

# Enable site
sudo ln -s /etc/nginx/sites-available/api.example.com /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

### 4. Add SSL with Let's Encrypt

```bash
# Install certbot
sudo apt install certbot python3-certbot-nginx -y

# Get certificate
sudo certbot --nginx -d api.example.com

# Auto-renewal is configured
sudo certbot renew --dry-run
```

### 5. Configure Cloudflare

If using Cloudflare (already configured by option 10):

```bash
# Verify real IP logging
sudo tail -f /var/log/nginx/access.log
# Should show real visitor IPs, not Cloudflare IPs
```

**Result:** Production-grade web server with SSL, caching, and security.

---

## VPN Server

**Goal:** Secure VPN server for remote access

**Time:** ~20 minutes

### 1. Run Installation

```bash
sudo ./install.sh --profile vpn-server
```

**Components:**
- System essentials
- Security tools
- OpenVPN server
- SSH hardening

### 2. Configure OpenVPN

During installation:
- Server IP: (auto-detected or enter manually)
- Port: 1194 (default) or custom
- Protocol: UDP (recommended) or TCP
- DNS: Choose Cloudflare, Google, or system DNS

### 3. Create Client Profiles

```bash
# Add first client
sudo ./install.sh
# Select: 13 (Add OpenVPN Client)
# Client name: laptop

# Add more clients
# Name: phone
# Name: tablet

# Clients are in:
ls -la /etc/openvpn/client-configs/files/
```

### 4. Transfer Client Config

```bash
# From server to local machine
scp root@vpn-server:/etc/openvpn/client-configs/files/laptop.ovpn ~/

# Or display and copy
cat /etc/openvpn/client-configs/files/laptop.ovpn
```

### 5. Connect Clients

**Linux/macOS:**
```bash
sudo openvpn --config laptop.ovpn
```

**Windows:** Import laptop.ovpn in OpenVPN GUI

**Android/iOS:** Import in OpenVPN Connect app

### 6. Verify Connection

```bash
# On server - check connected clients
sudo cat /var/log/openvpn/status.log

# On client - check IP
curl ifconfig.me
# Should show VPN server IP
```

**Result:** Secure VPN server with multiple client profiles.

---

## Production Web Application

**Goal:** Complete production setup with monitoring and security

**Time:** ~30 minutes

### 1. Full Installation

```bash
sudo ./install.sh --all
```

Or select all components interactively.

### 2. Harden Security

SSH hardening (component 12):
- Disable root login
- Enable key-only authentication
- Change SSH port to non-standard (e.g., 2222)
- Configure allowed users

```bash
# During SSH hardening:
# 1. Quick hardening (yes)
# 2. Disable password auth (yes - ensure SSH keys are setup first!)
# 3. Change port to 2222

# Reconnect using new port
ssh -p 2222 user@server
```

### 3. Deploy Application

```bash
# Setup application
cd /var/www
git clone your-repo
cd your-repo
npm install
cp .env.example .env

# Update .env with saved MongoDB/PostgreSQL credentials
nano .env

# Build production
npm run build

# Start with PM2
pm2 start ecosystem.config.js --env production
pm2 save
```

### 4. Configure Nginx + SSL

```bash
# Use advanced template
sudo cp /etc/nginx/sites-available/reverse-proxy-template /etc/nginx/sites-available/myapp

# Edit configuration
sudo nano /etc/nginx/sites-available/myapp

# Enable and test
sudo ln -s /etc/nginx/sites-available/myapp /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx

# Setup SSL
sudo certbot --nginx -d yourdomain.com -d www.yourdomain.com
```

### 5. Setup Monitoring

```bash
# Check status regularly
sudo ./status.sh

# Monitor PM2
pm2 monit

# Setup PM2 web interface (optional)
pm2 install pm2-server-monit
```

### 6. Backup Strategy

```bash
# Create backup script
nano /root/backup.sh

#!/bin/bash
# Backup databases
mongodump --out=/backup/mongo-$(date +%Y%m%d)
pg_dumpall > /backup/postgres-$(date +%Y%m%d).sql

# Backup application
tar -czf /backup/app-$(date +%Y%m%d).tar.gz /var/www

# Upload to S3 (if configured)
# aws s3 sync /backup s3://my-backups/

# Automate
chmod +x /root/backup.sh
crontab -e
# Add: 0 3 * * * /root/backup.sh
```

### 7. Final Checks

```bash
# Run full status check
sudo ./status.sh

# Check firewall
sudo ufw status verbose

# Check fail2ban
sudo fail2ban-client status sshd

# Test application
curl https://yourdomain.com

# Check SSL rating
# Visit: https://www.ssllabs.com/ssltest/
```

**Result:** Production-ready application with security, monitoring, and backups.

---

## Quick Reference

### Installation Profiles

| Profile | Use Case | Components | Time |
|---------|----------|------------|------|
| `nodejs-app` | Node.js + MongoDB apps | Core, MongoDB, Node, PM2, Nginx, Security | 15 min |
| `docker-host` | Container hosting | Core, Docker, Security | 10 min |
| `fullstack` | Complete dev environment | All dev tools | 25 min |
| `vpn-server` | VPN access | Core, Security, OpenVPN, SSH | 20 min |

### Common Commands

```bash
# Check status
sudo ./status.sh

# Update components
sudo ./update.sh

# Update specific component
sudo ./update.sh --component docker

# Remove component
sudo ./cleanup.sh --component mongodb

# Test configuration
sudo ./test.sh --lint-only
```

### Post-Installation Checklist

- [ ] Save all displayed passwords
- [ ] Configure firewall rules for your services
- [ ] Setup SSH keys and disable password auth
- [ ] Configure backups
- [ ] Test all services
- [ ] Setup monitoring/alerts
- [ ] Document custom configurations
- [ ] Test disaster recovery

---

**More Examples:**
- See TROUBLESHOOTING.md for common issues
- See README.md for complete documentation
- Check installation summary: `cat /root/ubuntu-setup-summary.txt`
