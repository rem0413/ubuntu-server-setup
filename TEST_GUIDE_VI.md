# Hướng Dẫn Kiểm Tra - Ubuntu Server Setup v2.0.0

## Kiểm Tra Nhanh (Quick Validation)

Trước khi test trên server thật, chạy validation script:

```bash
# Kiểm tra syntax và cấu trúc
./validate.sh
```

Script này kiểm tra:
- ✅ Bash syntax của tất cả file
- ✅ 12 modules có đủ không
- ✅ File cũ đã xóa chưa (nginx.sh, nginx-advanced.sh, cloudflare.sh)
- ✅ VERSION file đúng (2.0.0)
- ✅ Functions quan trọng tồn tại
- ✅ Component references đúng (1-12, không có 13-15)

## Kiểm Tra Đầy Đủ (Full Test Suite)

```bash
# Chạy tất cả tests
./test.sh

# Chỉ kiểm tra shellcheck
./test.sh --lint-only

# Verbose mode
./test.sh --verbose
```

Test suite kiểm tra:
1. **Shellcheck Linting** - Code quality
2. **Syntax Validation** - bash -n trên tất cả file
3. **File Structure** - lib/, modules/ directories
4. **Module Files** - 12 modules tồn tại
5. **Deprecated Files** - File cũ đã xóa
6. **Core Functions** - Logging, utils functions
7. **Module Functions** - Install/configure functions
8. **File Permissions** - Executable scripts
9. **Security Checks** - Không có hardcoded passwords
10. **Version Info** - VERSION, CHANGELOG.md
11. **Component Count** - 12 components, không có 13/14/15
12. **Git Repository** - .git, .gitignore

## Kiểm Tra Dry-Run (Không Cài Đặt Thật)

```bash
# Test interactive mode
sudo ./install.sh --dry-run

# Test tất cả components
sudo ./install.sh --all --dry-run

# Test profile
sudo ./install.sh --profile nodejs-app --dry-run
```

## Kiểm Tra Trên VM Ubuntu

### 1. Chuẩn Bị VM

```bash
# Yêu cầu:
# - Ubuntu 24.04 LTS
# - 2GB RAM
# - 20GB disk
# - Internet connection

# Clone repository
git clone <your-repo-url>
cd ubuntu-server-setup

# Kiểm tra validation
./validate.sh

# Kiểm tra test suite
./test.sh
```

### 2. Test Từng Component

#### Component 1: System Update
```bash
sudo ./install.sh
# Chọn: 1
# Kiểm tra: git, curl, wget, vim đã cài
which git curl wget vim
```

#### Component 2: MongoDB
```bash
sudo ./install.sh
# Chọn: 2
# Chọn port: Enter (default 27017) hoặc custom
# LƯU PASSWORD được hiển thị!
# Test: mongosh -u admin -p 'SAVED_PASSWORD'
sudo systemctl status mongod
```

#### Component 3: PostgreSQL
```bash
sudo ./install.sh
# Chọn: 3
# Chọn port: Enter (default 5432) hoặc custom
# LƯU PASSWORD và connection string!
# Test: PGPASSWORD='PASSWORD' psql -h localhost -U dbuser -d dbname
sudo systemctl status postgresql
```

#### Component 4: Node.js
```bash
sudo ./install.sh
# Chọn: 4
# Chọn version: 20.x (recommended)
# Test: node --version && npm --version
```

#### Component 5: PM2
```bash
sudo ./install.sh
# Chọn: 5 (cần Node.js trước)
# Test: pm2 --version
pm2 list
```

#### Component 6: Docker
```bash
sudo ./install.sh
# Chọn: 6
# Test: docker --version && docker compose version
docker run hello-world
# Log out và login lại để dùng docker không cần sudo
```

#### Component 7: Nginx Unified (Quan Trọng!)
```bash
sudo ./install.sh
# Chọn: 7

# Lần 1: Install Nginx
# Menu hiện: 1) Install Nginx
# Chọn: 1

# Chạy lại để test các options khác
sudo ./install.sh
# Chọn: 7

# Menu hiện:
#   1) Configure Advanced Settings
#   2) Setup Cloudflare Real IP
#   3) Test Configuration
#   4) Reload Nginx

# Test Configure Advanced (6 modes):
# Chọn 1, sau đó chọn từng mode:
#   1) Basic
#   2) Performance
#   3) Reverse Proxy
#   4) Static Server
#   5) Security
#   6) All

# Test Cloudflare Real IP:
# Chọn 2
# Verify: cat /etc/nginx/conf.d/cloudflare-realip.conf

# Kiểm tra:
sudo nginx -t
sudo systemctl status nginx
ls /etc/nginx/sites-available/
```

#### Component 8: Security
```bash
sudo ./install.sh
# Chọn: 8
# Cấu hình UFW rules
# Test:
sudo ufw status verbose
sudo fail2ban-client status sshd
```

#### Component 9: OpenVPN (Unified - Quan Trọng!)
```bash
sudo ./install.sh
# Chọn: 9

# Lần 1: Setup Server
# Menu hiện: 1) Setup OpenVPN Server
# Chọn: 1
# Cấu hình port, protocol, DNS

# Chạy lại để test client management
sudo ./install.sh
# Chọn: 9

# Menu hiện:
#   1) Add VPN Client
#   2) List Clients
#   3) Revoke Client
#   4) Reinstall Server

# Test Add Client:
# Chọn 1, nhập tên: client1

# Test List Clients:
# Chọn 2

# Kiểm tra:
sudo systemctl status openvpn-server@server
ls /etc/openvpn/client-configs/files/
cat /etc/openvpn/client-configs/files/client1.ovpn
```

#### Component 10: SSH Hardening (Với User Creation!)
```bash
sudo ./install.sh
# Chọn: 10

# Menu hiện 6 options:
#   1) Quick hardening (recommended)
#   2) Create SSH user (disable root login)
#   3) Add/manage SSH keys
#   4) Change SSH port
#   5) Show current configuration
#   6) Cancel

# Test Quick Hardening:
# Chọn 1
# Nhập username hiện tại hoặc tạo mới

# Test Create SSH User:
# Chọn 2
# Nhập username: testuser
# Nhập password
# Chọn add sudo: y
# Paste SSH public key (nếu có)
# Disable password auth: y (nếu đã có key)

# Test SSH Key Management:
# Chọn 3
# Thử các sub-menu

# ⚠️ QUAN TRỌNG:
# Trước khi restart SSH, test connection trong terminal mới!
# Kiểm tra:
sudo sshd -t
sudo grep -E "^(Port|PermitRootLogin|PasswordAuthentication)" /etc/ssh/sshd_config
```

#### Component 11: Redis (Standalone + Cluster!)
```bash
sudo ./install.sh
# Chọn: 11

# Menu hiện:
#   1) Standalone Redis (default)
#   2) Redis Cluster (3 master + 3 replica)

# Test Standalone:
# Chọn 1
# Nhập port: Enter (6379) hoặc custom
# LƯU PASSWORD!

# Test:
redis-cli -p 6379 -a 'PASSWORD' ping
sudo systemctl status redis-server

# Test Cluster (VM riêng khuyến nghị):
# Chọn 2
# Nhập base port: 6379
# LƯU PASSWORD!

# Test:
redis-cli -c -p 6379 -a 'PASSWORD' cluster info
sudo systemctl status redis-cluster-*
```

#### Component 12: Monitoring (Selectable Exporters!)
```bash
sudo ./install.sh
# Chọn: 12

# Menu cho chọn exporters:
#   1) Prometheus (required)
#   2) Grafana (required)
#   3) node_exporter (system metrics)
#   4) mysqld_exporter (MySQL/MariaDB)
#   5) postgres_exporter (PostgreSQL)
#   6) redis_exporter (Redis)
#   7) mongodb_exporter (MongoDB)

# Ví dụ chọn: 1 2 3 4 (Prometheus + Grafana + node + mysql)

# Kiểm tra:
sudo systemctl status prometheus
sudo systemctl status grafana-server
sudo systemctl status node_exporter

# Test web interface:
curl http://localhost:9090  # Prometheus
curl http://localhost:3000  # Grafana (admin/admin)
curl http://localhost:9100/metrics  # node_exporter
```

### 3. Test Profiles

```bash
# Profile nodejs-app (1, 2, 4, 5, 7, 8)
sudo ./install.sh --profile nodejs-app

# Profile docker-host (1, 6, 8)
sudo ./install.sh --profile docker-host

# Profile fullstack (1, 2, 3, 4, 5, 6, 7, 8)
sudo ./install.sh --profile fullstack

# Profile vpn-server (1, 8, 9, 10)
sudo ./install.sh --profile vpn-server
```

### 4. Kiểm Tra Kết Quả

```bash
# Installation summary
cat /root/ubuntu-setup-summary.txt

# Logs
sudo tail -100 /var/log/ubuntu-setup.log

# Config backups
ls -la /var/backups/ubuntu-setup/

# Services status
sudo systemctl status mongod
sudo systemctl status postgresql
sudo systemctl status nginx
sudo systemctl status redis-server
sudo systemctl status prometheus
sudo systemctl status grafana-server
```

## Các Lỗi Thường Gặp

### 1. Shellcheck Chưa Cài
```bash
sudo apt update
sudo apt install shellcheck
```

### 2. Permission Denied
```bash
chmod +x *.sh
```

### 3. Test Fail Do Component References
```bash
# Kiểm tra install.sh có reference components 13, 14, 15 không
grep -n "13)" install.sh
grep -n "14)" install.sh
grep -n "15)" install.sh
```

### 4. Module Không Tìm Thấy
```bash
# Kiểm tra 12 modules
ls -la modules/
# Phải có: core, mongodb, postgresql, nodejs, pm2, docker,
#          nginx-unified, security, openvpn, ssh-hardening,
#          redis, monitoring

# Không được có: nginx.sh, nginx-advanced.sh, cloudflare.sh
```

## Checklist Kiểm Tra Hoàn Chỉnh

- [ ] `./validate.sh` - TẤT CẢ PASS
- [ ] `./test.sh` - TẤT CẢ PASS
- [ ] `./test.sh --lint-only` - Không có shellcheck errors
- [ ] 12 modules có đầy đủ
- [ ] File cũ đã xóa (nginx.sh, nginx-advanced.sh, cloudflare.sh)
- [ ] VERSION file = 2.0.0
- [ ] Dry-run mode hoạt động
- [ ] Interactive installation hoạt động
- [ ] 4 profiles install thành công
- [ ] Mỗi component cài đặt riêng lẻ OK
- [ ] Services khởi động và chạy đúng
- [ ] Passwords được generate và hiển thị
- [ ] SSH hardening không lock user ra ngoài
- [ ] Config backups được tạo
- [ ] Installation summary được tạo
- [ ] Logs không có errors
- [ ] Re-installation là idempotent

## Tóm Tắt Testing

1. **Local Validation**: `./validate.sh` (30 giây)
2. **Test Suite**: `./test.sh` (2 phút)
3. **Dry-Run**: `sudo ./install.sh --dry-run` (1 phút)
4. **VM Testing**: Test từng component trên Ubuntu 24.04 VM (2-3 giờ)
5. **Profile Testing**: Test 4 profiles (1 giờ)
6. **Integration Testing**: Test full stack deployment (30 phút)

## Kết Quả Mong Đợi

✅ Tất cả automated tests PASS
✅ Không có syntax errors
✅ 12 modules hoạt động đúng
✅ Nginx unified = nginx + cloudflare + advanced
✅ OpenVPN unified = server + client management
✅ SSH hardening có user creation
✅ Redis có standalone + cluster
✅ Monitoring có selectable exporters
✅ Passwords secure (random 20 chars)
✅ Services auto-start
✅ Logs chi tiết
✅ Backups tự động

## Support

Nếu có vấn đề:
1. Check `./validate.sh` output
2. Check `./test.sh` output
3. Check `/var/log/ubuntu-setup.log`
4. Xem TESTING.md để hướng dẫn chi tiết hơn
