# Troubleshooting Guide

Common issues and solutions for Ubuntu Server Setup automation script.

## Table of Contents

1. [Installation Issues](#installation-issues)
2. [Service Problems](#service-problems)
3. [Network & Connectivity](#network--connectivity)
4. [Permission Issues](#permission-issues)
5. [Database Problems](#database-problems)
6. [Docker Issues](#docker-issues)
7. [Security & Firewall](#security--firewall)
8. [Performance Issues](#performance-issues)

---

## Installation Issues

### Script Fails with "Permission Denied"

**Symptom:** `bash: ./install.sh: Permission denied`

**Solution:**
```bash
chmod +x install.sh
sudo ./install.sh
```

### Script Exits with "Not running as root"

**Symptom:** `ERROR: This script must be run as root or with sudo`

**Solution:**
```bash
sudo ./install.sh
```

### APT Update Fails

**Symptom:** `E: Could not get lock /var/lib/apt/lists/lock`

**Solutions:**
```bash
# Wait for other apt processes to finish
ps aux | grep apt

# If hung, force kill
sudo killall apt apt-get
sudo rm /var/lib/apt/lists/lock
sudo rm /var/cache/apt/archives/lock
sudo rm /var/lib/dpkg/lock*

# Reconfigure dpkg
sudo dpkg --configure -a
sudo apt update
```

### Package Installation Timeout

**Symptom:** Package downloads hang or timeout

**Solutions:**
```bash
# Change APT mirror
sudo sed -i 's/archive.ubuntu.com/mirror.example.com/g' /etc/apt/sources.list

# Or use main mirror
sudo sed -i 's/[a-z][a-z].archive.ubuntu.com/archive.ubuntu.com/g' /etc/apt/sources.list

# Update and retry
sudo apt update
```

### Dry-Run Shows Wrong Components

**Symptom:** `--dry-run` shows unexpected components

**Solution:**
```bash
# Interactive selection
sudo ./install.sh --dry-run

# With profile
sudo ./install.sh --profile nodejs-app --dry-run

# Check available profiles
./install.sh --help
```

---

## Service Problems

### Service Won't Start

**Symptom:** `systemctl start service` fails

**Diagnosis:**
```bash
# Check service status
sudo systemctl status service-name

# Check journal logs
sudo journalctl -xe -u service-name

# Check service file
systemctl cat service-name

# Test configuration
sudo service-name -t  # For nginx
sudo mongod --config /etc/mongod.conf --test  # For mongodb
```

**Common Solutions:**
```bash
# Port already in use
sudo lsof -i :PORT_NUMBER
sudo kill -9 PID

# Fix permissions
sudo chown -R service-user:service-group /var/lib/service

# Reload systemd
sudo systemctl daemon-reload
sudo systemctl restart service-name
```

### Service Starts But Immediately Stops

**Diagnosis:**
```bash
# Check last 50 lines of logs
sudo journalctl -u service-name -n 50

# Check service dependencies
systemctl list-dependencies service-name

# Run in foreground to see errors
sudo service-command --foreground
```

### Check All Services

```bash
# Use status script
sudo ./status.sh

# Or manually
systemctl list-units --type=service --state=running | grep -E 'mongo|postgres|nginx|docker'
```

---

## Network & Connectivity

### Cannot Connect to Database from Remote

**Symptom:** Connection refused from remote IP

**Solutions:**

**MongoDB:**
```bash
# Edit mongod.conf
sudo nano /etc/mongod.conf

# Change bindIp
net:
  bindIp: 0.0.0.0  # Or specific IP
  port: 27017

# Restart
sudo systemctl restart mongod

# Check firewall
sudo ufw allow 27017/tcp
```

**PostgreSQL:**
```bash
# Edit postgresql.conf
sudo nano /etc/postgresql/*/main/postgresql.conf

# Change listen_addresses
listen_addresses = '*'

# Edit pg_hba.conf
sudo nano /etc/postgresql/*/main/pg_hba.conf

# Add line
host    all    all    0.0.0.0/0    md5

# Restart
sudo systemctl restart postgresql

# Check firewall
sudo ufw allow 5432/tcp
```

### DNS Resolution Fails

**Symptom:** `Could not resolve host`

**Solutions:**
```bash
# Test DNS
nslookup google.com
dig google.com

# Check resolv.conf
cat /etc/resolv.conf

# Set Google DNS
sudo bash -c 'echo "nameserver 8.8.8.8" > /etc/resolv.conf'
sudo bash -c 'echo "nameserver 8.8.4.4" >> /etc/resolv.conf'

# Or use systemd-resolved
sudo systemd-resolve --set-dns=8.8.8.8 --interface=eth0
```

### Slow Network Performance

**Diagnosis:**
```bash
# Test speed
speedtest-cli

# Check MTU
ip link show

# Check packet loss
ping -c 100 8.8.8.8 | grep loss

# Network stats
netstat -s | grep -i error
```

---

## Permission Issues

### Docker "Permission Denied" Error

**Symptom:** `Got permission denied while trying to connect to the Docker daemon socket`

**Solution:**
```bash
# Add user to docker group
sudo usermod -aG docker $USER

# Log out and back in, or
newgrp docker

# Test
docker ps
```

### Cannot Write to Log File

**Symptom:** `Permission denied: /var/log/ubuntu-setup.log`

**Solution:**
```bash
# Fix log file permissions
sudo touch /var/log/ubuntu-setup.log
sudo chmod 644 /var/log/ubuntu-setup.log

# Fix log directory
sudo chmod 755 /var/log
```

### npm Global Install Fails

**Symptom:** `EACCES: permission denied`

**Solution:**
```bash
# Fix npm permissions (done by script)
mkdir -p ~/.npm-global
npm config set prefix '~/.npm-global'
echo 'export PATH=~/.npm-global/bin:$PATH' >> ~/.bashrc
source ~/.bashrc

# Or use sudo (not recommended)
sudo npm install -g package-name
```

---

## Database Problems

### MongoDB Authentication Failed

**Symptom:** `Authentication failed`

**Solutions:**
```bash
# Connect without auth
mongo --authenticationDatabase admin

# Reset admin password
use admin
db.changeUserPassword("admin", "newpassword")

# Check user exists
db.getUsers()

# Recreate user if needed
db.createUser({
  user: "admin",
  pwd: "password",
  roles: ["root"]
})
```

### PostgreSQL Password Lost

**Symptom:** Lost database password

**Solution:**
```bash
# Switch to postgres user
sudo -u postgres psql

# Change password
ALTER USER username WITH PASSWORD 'newpassword';

# Exit
\q
```

### Database Won't Start After Reboot

**Diagnosis:**
```bash
# Check disk space
df -h

# Check if data directory exists
ls -la /var/lib/mongodb  # MongoDB
ls -la /var/lib/postgresql  # PostgreSQL

# Check permissions
sudo ls -la /var/lib/mongodb
sudo chown -R mongodb:mongodb /var/lib/mongodb

# Check logs
sudo tail -50 /var/log/mongodb/mongod.log
sudo tail -50 /var/log/postgresql/postgresql-*-main.log
```

### Out of Disk Space

**Symptom:** `No space left on device`

**Solutions:**
```bash
# Check disk usage
df -h
du -sh /* | sort -h

# Clean up
sudo apt-get autoremove
sudo apt-get autoclean
sudo journalctl --vacuum-time=3d

# Clean Docker
docker system prune -a

# Clean logs
sudo ./cleanup.sh --component logs
```

---

## Docker Issues

### Docker Daemon Not Starting

**Symptom:** `Cannot connect to the Docker daemon`

**Solutions:**
```bash
# Check status
sudo systemctl status docker

# Check logs
sudo journalctl -xe -u docker

# Restart daemon
sudo systemctl restart docker

# If fails, check config
sudo dockerd --debug

# Reset Docker
sudo systemctl stop docker
sudo rm -rf /var/lib/docker
sudo systemctl start docker
```

### Container Exits Immediately

**Diagnosis:**
```bash
# Check container logs
docker logs container-name

# Check container exit code
docker inspect container-name | grep ExitCode

# Run interactively
docker run -it image-name /bin/bash
```

### Port Already in Use

**Symptom:** `port is already allocated`

**Solution:**
```bash
# Find process using port
sudo lsof -i :PORT
sudo netstat -tulpn | grep :PORT

# Kill process
sudo kill -9 PID

# Or use different port
docker run -p 8080:80 image-name
```

---

## Security & Firewall

### SSH Connection Refused After Hardening

**Symptom:** Cannot SSH after running SSH hardening

**Emergency Access:**
```bash
# Use console/VNC access from hosting provider

# Check SSH status
sudo systemctl status sshd

# Check SSH config
sudo sshd -t

# Restore backup
sudo cp /etc/ssh/sshd_config.bak.* /etc/ssh/sshd_config
sudo systemctl restart sshd
```

### UFW Blocking Legitimate Traffic

**Symptom:** Services not accessible after enabling firewall

**Solutions:**
```bash
# Check UFW status
sudo ufw status numbered

# Allow specific port
sudo ufw allow PORT/tcp

# Allow specific service
sudo ufw allow 'Nginx Full'
sudo ufw allow OpenSSH

# Delete rule by number
sudo ufw delete NUMBER

# Disable temporarily
sudo ufw disable
```

### Fail2ban Banned Own IP

**Symptom:** Cannot connect, IP banned by fail2ban

**Solution:**
```bash
# Check banned IPs
sudo fail2ban-client status sshd

# Unban IP
sudo fail2ban-client set sshd unbanip YOUR_IP

# Whitelist IP permanently
sudo nano /etc/fail2ban/jail.local

# Add under [DEFAULT]
ignoreip = 127.0.0.1/8 YOUR_IP

# Restart fail2ban
sudo systemctl restart fail2ban
```

---

## Performance Issues

### High CPU Usage

**Diagnosis:**
```bash
# Check processes
top
htop

# Find CPU hogs
ps aux --sort=-%cpu | head -10

# Check system load
uptime
```

### High Memory Usage

**Diagnosis:**
```bash
# Check memory
free -h

# Find memory hogs
ps aux --sort=-%mem | head -10

# Check swap
swapon --show

# Add swap if needed
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
```

### Slow Disk I/O

**Diagnosis:**
```bash
# Check disk I/O
iostat -x 1 5

# Check disk health
sudo smartctl -a /dev/sda

# Test disk speed
sudo hdparm -t /dev/sda
```

---

## Getting Help

### Collect Diagnostic Information

```bash
# Run status check
sudo ./status.sh > status-report.txt

# Check logs
sudo tail -100 /var/log/ubuntu-setup.log > install-log.txt

# System info
uname -a > system-info.txt
lsb_release -a >> system-info.txt
df -h >> system-info.txt
free -h >> system-info.txt
```

### Check Installation Summary

```bash
# View summary file
cat /root/ubuntu-setup-summary.txt

# Check component versions
node --version
npm --version
docker --version
mongosh --version
psql --version
```

### Report Issues

When reporting issues, include:
1. Ubuntu version: `lsb_release -a`
2. Installation summary: `cat /root/ubuntu-setup-summary.txt`
3. Error logs: `sudo tail -100 /var/log/ubuntu-setup.log`
4. Service status: `sudo ./status.sh`
5. Steps to reproduce

---

## Prevention Tips

1. **Always use dry-run first:**
   ```bash
   sudo ./install.sh --dry-run
   ```

2. **Check system resources before installation:**
   ```bash
   df -h  # Disk space
   free -h  # Memory
   ```

3. **Keep backups:**
   ```bash
   # Backups are in
   ls -la /var/backups/ubuntu-setup/
   ```

4. **Test in staging environment first**

5. **Read logs regularly:**
   ```bash
   sudo tail -f /var/log/ubuntu-setup.log
   ```

6. **Update regularly:**
   ```bash
   sudo ./update.sh
   ```

7. **Monitor services:**
   ```bash
   sudo ./status.sh
   ```

---

**Need more help?**
- GitHub Issues: https://github.com/username/ubuntu-setup/issues
- Check README.md for documentation
- Run `./install.sh --help` for usage information
