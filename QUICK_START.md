# Quick Start - Cài Đặt Nhanh

## Cách Dùng Inline Đơn Giản Nhất

### Quick Install (Menu 1-5)

```bash
curl -fsSL https://raw.githubusercontent.com/rem0413/ubuntu-server-setup/master/quick-install.sh | bash
```

Script sẽ hiện menu cho bạn chọn:
- 1 = Node.js App Stack
- 2 = Docker Host
- 3 = Full Stack
- 4 = VPN Server
- 5 = Install All

**Chỉ cần gõ số và Enter!** Script tự động chạy lệnh đúng.

### Direct Install (Không Menu)

**Node.js App:**
```bash
curl -fsSL https://raw.githubusercontent.com/rem0413/ubuntu-server-setup/master/remote-install.sh | sudo bash -s -- --profile nodejs-app
```

**Docker Host:**
```bash
curl -fsSL https://raw.githubusercontent.com/rem0413/ubuntu-server-setup/master/remote-install.sh | sudo bash -s -- --profile docker-host
```

**Full Stack:**
```bash
curl -fsSL https://raw.githubusercontent.com/rem0413/ubuntu-server-setup/master/remote-install.sh | sudo bash -s -- --profile fullstack
```

**Install All:**
```bash
curl -fsSL https://raw.githubusercontent.com/rem0413/ubuntu-server-setup/master/remote-install.sh | sudo bash -s -- --all
```

## Profiles Chi Tiết

### nodejs-app
- System Update & Essential Tools
- MongoDB Database
- Node.js & npm
- PM2 Process Manager
- Nginx Web Server
- Security Tools (UFW, Fail2ban)

**Dùng cho:** Web apps, APIs, Node.js servers

### docker-host
- System Update & Essential Tools
- Docker & Docker Compose
- Security Tools (UFW, Fail2ban)

**Dùng cho:** Container hosting, microservices

### fullstack
- System Update & Essential Tools
- MongoDB Database
- PostgreSQL Database
- Node.js & npm
- PM2 Process Manager
- Docker & Docker Compose
- Nginx Web Server
- Security Tools (UFW, Fail2ban)

**Dùng cho:** Development environments, complete stacks

### vpn-server
- System Update & Essential Tools
- Security Tools (UFW, Fail2ban)
- OpenVPN Server
- SSH Security Hardening

**Dùng cho:** VPN servers, secure access

## Chọn Components Tùy Chỉnh

Nếu muốn chọn từng component riêng lẻ:

```bash
git clone https://github.com/rem0413/ubuntu-server-setup.git
cd ubuntu-server-setup
sudo ./install.sh
```

Menu sẽ cho bạn chọn từ 12 components.

## Tóm Tắt

| Cách | Lệnh | Ưu điểm |
|------|------|---------|
| **Quick Menu** | `curl URL/quick-install.sh \| bash` | Menu đơn giản 1-5 |
| **Direct Profile** | `curl URL \| bash -s -- --profile nodejs-app` | Nhanh nhất, 1 lệnh |
| **Clone Repo** | `git clone && sudo ./install.sh` | Tùy chỉnh components |

**Khuyến nghị:** Dùng Quick Menu cho lần đầu, Direct Profile khi đã quen.
