# Console Installation Guide (VN)

Hướng dẫn sử dụng script cài đặt qua console cho VPS Ubuntu.

## 🚀 Cài Đặt Nhanh (Không Cần Tương Tác)

### Cài Tất Cả
```bash
curl -fsSL https://raw.githubusercontent.com/rem0413/ubuntu-server-setup/master/remote-install.sh | sudo bash -s -- --all
```

### Sử Dụng Profile (Khuyến Nghị)

**Node.js App Stack:**
```bash
curl -fsSL https://raw.githubusercontent.com/rem0413/ubuntu-server-setup/master/remote-install.sh | sudo bash -s -- --profile nodejs-app
```
Cài: Core + MongoDB + Node.js + PM2 + Nginx + Security

**Docker Host:**
```bash
curl -fsSL https://raw.githubusercontent.com/rem0413/ubuntu-server-setup/master/remote-install.sh | sudo bash -s -- --profile docker-host
```
Cài: Core + Docker + Security

**Full Stack:**
```bash
curl -fsSL https://raw.githubusercontent.com/rem0413/ubuntu-server-setup/master/remote-install.sh | sudo bash -s -- --profile fullstack
```
Cài: Core + MongoDB + PostgreSQL + Node.js + PM2 + Docker + Nginx + Security

**VPN Server:**
```bash
curl -fsSL https://raw.githubusercontent.com/rem0413/ubuntu-server-setup/master/remote-install.sh | sudo bash -s -- --profile vpn-server
```
Cài: Core + Security + OpenVPN + SSH Hardening

## 📋 Cài Đặt Tương Tác (Console Menu)

### Chạy Menu
```bash
curl -fsSL https://raw.githubusercontent.com/rem0413/ubuntu-server-setup/master/remote-install.sh | sudo bash
```

### Cách Sử Dụng Menu

Khi menu hiện ra, bạn sẽ thấy danh sách 12 components:

```
╔══════════════════════════════════════════════════════════════╗
║           Select Components to Install                      ║
╚══════════════════════════════════════════════════════════════╝

═══ Core Installation ═══
  [1]  System Update & Essential Tools (Recommended)
  [2]  MongoDB Database
  [3]  PostgreSQL Database
  [4]  Node.js & npm
  [5]  PM2 Process Manager (Requires Node.js)
  [6]  Docker & Docker Compose

═══ Web & Security ═══
  [7]  Nginx Web Server (Cloudflare & Advanced Config)
  [8]  Security Tools (UFW, Fail2ban)
  [9]  OpenVPN Server & Client Management
  [10] SSH Security Hardening

═══ Additional Services ═══
  [11] Redis Cache Server
  [12] Monitoring Stack (Prometheus/Grafana)

═══ Quick Options ═══
  [0]  Install All Components
  [q]  Quit Installation

Enter your choice:
  - Single component: 1
  - Multiple components: 1 2 4 6 8
  - All components: 0
  - Cancel: q

>
```

**Nhập lựa chọn:**

1. **Cài 1 component:** Gõ số, ví dụ: `1`
2. **Cài nhiều components:** Gõ các số cách nhau bởi dấu cách, ví dụ: `1 2 4 6 8`
3. **Cài tất cả:** Gõ `0`
4. **Hủy:** Gõ `q`

**Ví dụ:**
```bash
> 1 4 5 7 8
# Cài: Core + Node.js + PM2 + Nginx + Security

> 1 6 8
# Cài: Core + Docker + Security

> 0
# Cài tất cả 12 components

> q
# Hủy cài đặt
```

### Xác Nhận

Sau khi chọn, script sẽ hiển thị danh sách components và yêu cầu xác nhận:

```
╔══════════════════════════════════════════════════════════════╗
║              Installation Confirmation                      ║
╚══════════════════════════════════════════════════════════════╝

The following components will be installed:

  ✓ System Update & Essential Tools
  ✓ Node.js & npm
  ✓ PM2 Process Manager
  ✓ Nginx Web Server (Cloudflare & Advanced)
  ✓ Security Tools (UFW, Fail2ban)

⚠️  This will modify your system configuration
   Installation may take 10-30 minutes depending on components

Do you want to continue?
Type 'yes' to proceed, or 'no' to cancel:
```

Gõ `yes` hoặc `y` để tiếp tục.

## 🛠️ Sửa Lỗi Thường Gặp

### Lỗi 1: Menu không nhận input từ bàn phím

**Hiện tượng:** Menu hiện ra nhưng không gõ được

**Nguyên nhân:** Chạy qua SSH không có terminal đầy đủ

**Giải pháp:** Dùng mode không tương tác
```bash
curl -fsSL https://raw.githubusercontent.com/rem0413/ubuntu-server-setup/master/remote-install.sh | sudo bash -s -- --profile nodejs-app
```

### Lỗi 2: Input timeout

**Hiện tượng:** `Error: Input timeout or not available`

**Nguyên nhân:** Shell không hỗ trợ tương tác

**Giải pháp:** Dùng flags
```bash
# Option 1: Profile
curl -fsSL URL | sudo bash -s -- --profile nodejs-app

# Option 2: Install all
curl -fsSL URL | sudo bash -s -- --all
```

### Lỗi 3: Invalid input format

**Hiện tượng:** `Error: Invalid input format`

**Nguyên nhân:** Nhập sai format

**Giải pháp:**
- Nhập số cách nhau bởi dấu cách: `1 2 4 6`
- Không dùng dấu phẩy: ~~`1,2,4,6`~~
- Không dùng gạch ngang: ~~`1-4`~~

### Lỗi 4: Permission denied

**Hiện tượng:** Script thoát với lỗi permission

**Giải pháp:** Phải chạy với sudo
```bash
curl -fsSL URL | sudo bash
```

## 📊 Components Chi Tiết

### Core Installation

**[1] System Update & Essential Tools**
- Update hệ thống
- Cài build tools, git, curl, wget, vim
- Thiết lập timezone, locale
- Tạo thư mục backup

**[2] MongoDB Database**
- MongoDB Community Edition (latest)
- Tự động start và enable service
- Tạo admin user (optional)
- Port: 27017

**[3] PostgreSQL Database**
- PostgreSQL (latest stable)
- Tự động start và enable service
- Tạo database và user (optional)
- Port: 5432

**[4] Node.js & npm**
- Node.js LTS via NVM
- npm latest
- Yarn package manager
- Global packages: pm2, nodemon

**[5] PM2 Process Manager**
- PM2 global installation
- PM2 startup script
- PM2 log rotation
- Yêu cầu: Node.js [4]

**[6] Docker & Docker Compose**
- Docker CE (latest)
- Docker Compose V2
- Thêm user vào docker group
- Cấu hình Docker daemon

### Web & Security

**[7] Nginx Web Server**
- Nginx (latest stable)
- Cloudflare real IP module
- Advanced configuration (caching, gzip, security headers)
- SSL/TLS setup templates
- Port: 80, 443

**[8] Security Tools**
- UFW Firewall (allow SSH, HTTP, HTTPS)
- Fail2ban (SSH protection)
- Unattended upgrades
- Basic security hardening

**[9] OpenVPN Server**
- OpenVPN server setup
- Easy-RSA PKI
- Client management scripts
- NAT và routing rules
- Port: 1194 UDP

**[10] SSH Security Hardening**
- Disable root login
- Change SSH port (optional)
- Key-only authentication
- Fail2ban SSH jail
- SSHD config optimization

### Additional Services

**[11] Redis Cache Server**
- Redis latest stable
- Bind to localhost
- Persistent storage config
- Password protection (optional)
- Port: 6379

**[12] Monitoring Stack**
- Prometheus
- Grafana
- Node Exporter
- Alert Manager
- Ports: 9090, 3000, 9100

## ⏱️ Thời Gian Cài Đặt

Ước tính thời gian (trên VPS 2GB RAM, 2 CPU):

| Profile | Components | Thời gian |
|---------|-----------|-----------|
| nodejs-app | 6 components | ~10 phút |
| docker-host | 3 components | ~5 phút |
| fullstack | 8 components | ~15 phút |
| vpn-server | 4 components | ~8 phút |
| All (12) | 12 components | ~25 phút |

## 📝 Sau Khi Cài Đặt

### 1. Xem Tóm Tắt
```bash
cat /root/ubuntu-setup-summary.txt
```

### 2. Kiểm Tra Services
```bash
# MongoDB
sudo systemctl status mongod

# Nginx
sudo systemctl status nginx

# Docker
sudo systemctl status docker

# PM2
pm2 status
```

### 3. Kiểm Tra Firewall
```bash
sudo ufw status verbose
```

### 4. Reload PATH
```bash
source ~/.bashrc
```

### 5. Test Cài Đặt
```bash
# Node.js
node --version
npm --version

# Docker
docker --version
docker compose version

# MongoDB
mongosh --eval "db.version()"

# Nginx
sudo nginx -t
```

## 🎯 Ví Dụ Thực Tế

### VPS Mới - Node.js App

```bash
# 1. SSH vào VPS
ssh root@your-vps-ip

# 2. Cài đặt Node.js stack
curl -fsSL https://raw.githubusercontent.com/rem0413/ubuntu-server-setup/master/remote-install.sh | sudo bash -s -- --profile nodejs-app

# 3. Deploy app
cd /var/www
git clone https://github.com/user/app.git
cd app
npm install
pm2 start server.js --name myapp
pm2 save

# 4. Setup Nginx
sudo nano /etc/nginx/sites-available/myapp
sudo ln -s /etc/nginx/sites-available/myapp /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx
```

### Docker Host Setup

```bash
# 1. Cài Docker
curl -fsSL https://raw.githubusercontent.com/rem0413/ubuntu-server-setup/master/remote-install.sh | sudo bash -s -- --profile docker-host

# 2. Logout và login lại (để apply docker group)
exit
ssh root@your-vps-ip

# 3. Test Docker
docker run hello-world
docker compose version

# 4. Deploy với Docker Compose
cd /opt
mkdir myapp && cd myapp
nano docker-compose.yml
docker compose up -d
```

### Custom Selection

```bash
# Chạy interactive
curl -fsSL https://raw.githubusercontent.com/rem0413/ubuntu-server-setup/master/remote-install.sh | sudo bash

# Khi menu hiện:
> 1 2 4 5 7 8
# (Core + MongoDB + Node.js + PM2 + Nginx + Security)

# Xác nhận:
Type 'yes' to proceed, or 'no' to cancel: yes
```

## 🔍 Xem Logs

```bash
# Installation log
sudo cat /var/log/ubuntu-setup.log

# Service logs
sudo journalctl -u mongod -f
sudo journalctl -u nginx -f
sudo journalctl -u docker -f

# Firewall logs
sudo tail -f /var/log/ufw.log
```

## 💡 Tips

1. **Luôn dùng profile** cho production để tránh cài thừa
2. **Test với --dry-run** trước khi cài thật
3. **Backup summary file** ngay sau khi cài
4. **Đổi default passwords** cho MongoDB, Redis
5. **Setup SSL** cho Nginx sau khi cài
6. **Enable automatic updates** cho security

## 🆘 Hỗ Trợ

- **GitHub Issues:** https://github.com/rem0413/ubuntu-server-setup/issues
- **Documentation:** https://github.com/rem0413/ubuntu-server-setup
- **Installation Log:** `/var/log/ubuntu-setup.log`
- **Summary:** `/root/ubuntu-setup-summary.txt`
