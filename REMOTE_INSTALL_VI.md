# Hướng Dẫn Cài Đặt Từ Xa (Remote Installation)

Cài đặt trực tiếp từ GitHub mà không cần clone repository về máy.

## Cài Đặt Nhanh - Một Dòng Lệnh

### Phương Pháp 1: Dùng remote-install.sh (Khuyên Dùng)

```bash
# Cài đặt interactive (chọn components)
curl -fsSL https://raw.githubusercontent.com/USERNAME/ubuntu-server-setup/main/remote-install.sh | sudo bash

# Cài đặt tất cả components
curl -fsSL https://raw.githubusercontent.com/USERNAME/ubuntu-server-setup/main/remote-install.sh | sudo bash -s -- --all

# Dùng profile có sẵn
curl -fsSL https://raw.githubusercontent.com/USERNAME/ubuntu-server-setup/main/remote-install.sh | sudo bash -s -- --profile nodejs-app

# Xem trước không cài (dry-run)
curl -fsSL https://raw.githubusercontent.com/USERNAME/ubuntu-server-setup/main/remote-install.sh | sudo bash -s -- --dry-run
```

### Phương Pháp 2: Trực tiếp install.sh

```bash
curl -fsSL https://raw.githubusercontent.com/USERNAME/ubuntu-server-setup/main/install.sh | sudo bash
```

⚠️ **Lưu ý**: Phương pháp 2 cần tất cả dependencies có sẵn, nên khuyên dùng Phương pháp 1.

## Tùy Chỉnh Repository/Branch

```bash
# Repository tùy chỉnh
export REPO_USER="yourusername"
export REPO_NAME="your-fork"
export REPO_BRANCH="development"

curl -fsSL https://raw.githubusercontent.com/${REPO_USER}/${REPO_NAME}/${REPO_BRANCH}/remote-install.sh | sudo bash
```

## Các Tùy Chọn Cài Đặt

Tất cả options của install.sh đều hoạt động với remote installation:

```bash
# Xem help
curl -fsSL https://raw.githubusercontent.com/USERNAME/ubuntu-server-setup/main/remote-install.sh | sudo bash -s -- --help

# Xem version
curl -fsSL https://raw.githubusercontent.com/USERNAME/ubuntu-server-setup/main/remote-install.sh | sudo bash -s -- --version

# Cài với profile
curl -fsSL https://raw.githubusercontent.com/USERNAME/ubuntu-server-setup/main/remote-install.sh | sudo bash -s -- --profile fullstack

# Xem trước (dry-run)
curl -fsSL https://raw.githubusercontent.com/USERNAME/ubuntu-server-setup/main/remote-install.sh | sudo bash -s -- --dry-run

# Cài tất cả
curl -fsSL https://raw.githubusercontent.com/USERNAME/ubuntu-server-setup/main/remote-install.sh | sudo bash -s -- --all
```

## Profiles Có Sẵn

```bash
# Máy chủ Node.js (Components: 1, 2, 4, 5, 7, 8)
curl -fsSL https://raw.githubusercontent.com/USERNAME/ubuntu-server-setup/main/remote-install.sh | sudo bash -s -- --profile nodejs-app

# Máy chủ Docker (Components: 1, 6, 8)
curl -fsSL https://raw.githubusercontent.com/USERNAME/ubuntu-server-setup/main/remote-install.sh | sudo bash -s -- --profile docker-host

# Full stack (Components: 1, 2, 3, 4, 5, 6, 7, 8)
curl -fsSL https://raw.githubusercontent.com/USERNAME/ubuntu-server-setup/main/remote-install.sh | sudo bash -s -- --profile fullstack

# VPN server (Components: 1, 8, 9, 10)
curl -fsSL https://raw.githubusercontent.com/USERNAME/ubuntu-server-setup/main/remote-install.sh | sudo bash -s -- --profile vpn-server
```

## Cách Hoạt Động

Remote installer thực hiện:

1. **Download** tất cả files từ GitHub:
   - `install.sh` - Main installer
   - `lib/*.sh` - Library files (colors, utils, ui)
   - `modules/*.sh` - Tất cả 12 modules
   - `VERSION` - Thông tin version

2. **Tạo** thư mục tạm (`/tmp/ubuntu-server-setup-$$`)

3. **Chạy** cài đặt với arguments được cung cấp

4. **Dọn dẹp** files tạm sau khi hoàn thành

## Bảo Mật

### Xem Script Trước Khi Chạy

Luôn xem script trước khi pipe vào bash:

```bash
# Download và xem trước
curl -fsSL https://raw.githubusercontent.com/USERNAME/ubuntu-server-setup/main/remote-install.sh > remote-install.sh
cat remote-install.sh
# Xem và kiểm tra script
sudo bash remote-install.sh
```

### Verify Repository

Chắc chắn URL repository đúng:

```bash
# Kiểm tra repository tồn tại
curl -I https://raw.githubusercontent.com/USERNAME/ubuntu-server-setup/main/remote-install.sh

# Phải trả về: HTTP/2 200
```

### Dùng HTTPS

Luôn dùng HTTPS để đảm bảo download được mã hóa.

## Xử Lý Lỗi

### Error: Failed to download install.sh

**Nguyên nhân**: URL repository hoặc branch name sai

**Giải pháp**:
```bash
# Kiểm tra URL
# Thay USERNAME bằng GitHub username của bạn
# Thay main bằng branch name nếu khác
curl -I https://raw.githubusercontent.com/USERNAME/ubuntu-server-setup/main/install.sh
```

### Error: This script must be run as root

**Nguyên nhân**: Không dùng sudo

**Giải pháp**:
```bash
# Dùng sudo
curl -fsSL URL | sudo bash
```

### Error: Module download failed

**Nguyên nhân**: Thiếu module file trong repository

**Giải pháp**:
```bash
# Verify tất cả modules tồn tại
# Phải có 12 modules: core, mongodb, postgresql, nodejs, pm2, docker,
#                    nginx-unified, security, openvpn, ssh-hardening,
#                    redis, monitoring
```

### Connection timeout

**Nguyên nhân**: Network issues hoặc GitHub rate limiting

**Giải pháp**:
```bash
# Đợi vài phút và thử lại
# Hoặc clone local:
git clone https://github.com/USERNAME/ubuntu-server-setup.git
cd ubuntu-server-setup
sudo ./install.sh
```

## Sử Dụng Nâng Cao

### Lưu Để Dùng Offline

Download một lần, dùng nhiều lần:

```bash
# Download remote installer
curl -fsSL https://raw.githubusercontent.com/USERNAME/ubuntu-server-setup/main/remote-install.sh -o remote-install.sh
chmod +x remote-install.sh

# Dùng sau (vẫn download từ GitHub)
sudo ./remote-install.sh --profile nodejs-app
```

## So Sánh: Remote vs Local

| Tính Năng | Remote Install | Local Install |
|-----------|---------------|---------------|
| **Setup Time** | Ngay lập tức | Cần git clone |
| **Disk Usage** | Tạm thời (tự dọn) | Vĩnh viễn (~5MB) |
| **Network** | Cần mỗi lần chạy | Chỉ lần đầu |
| **Tùy Chỉnh** | Giới hạn | Toàn quyền |
| **Updates** | Luôn mới nhất | Phải git pull |
| **Offline Use** | Không | Có (sau clone) |

## Best Practices

1. **Dùng branch/tag cụ thể** cho production:
   ```bash
   export REPO_BRANCH="v2.0.0"
   curl -fsSL https://raw.githubusercontent.com/USERNAME/ubuntu-server-setup/v2.0.0/remote-install.sh | sudo bash
   ```

2. **Test với dry-run** trước:
   ```bash
   curl -fsSL URL | sudo bash -s -- --dry-run
   ```

3. **Lưu credentials** ngay:
   ```bash
   # Sau khi cài đặt
   sudo cat /root/ubuntu-setup-summary.txt > ~/credentials.txt
   chmod 600 ~/credentials.txt
   ```

4. **Kiểm tra logs**:
   ```bash
   sudo tail -100 /var/log/ubuntu-setup.log
   ```

## Ví Dụ Thực Tế

### Setup VPS Ubuntu Mới

```bash
# Update system trước
sudo apt update && sudo apt upgrade -y

# Cài full stack
curl -fsSL https://raw.githubusercontent.com/USERNAME/ubuntu-server-setup/main/remote-install.sh | sudo bash -s -- --profile fullstack

# Lưu credentials
sudo cat /root/ubuntu-setup-summary.txt
```

### Production Web Server

```bash
# Cài web server stack
curl -fsSL https://raw.githubusercontent.com/USERNAME/ubuntu-server-setup/main/remote-install.sh | sudo bash -s -- --profile nodejs-app

# Cấu hình Nginx cho domain
# Setup SSL certificates
# Deploy application
```

### VPN Server Setup

```bash
# Cài VPN server
curl -fsSL https://raw.githubusercontent.com/USERNAME/ubuntu-server-setup/main/remote-install.sh | sudo bash -s -- --profile vpn-server

# Thêm VPN clients qua menu
sudo ./install.sh
# Chọn: 9 (OpenVPN) → Add Client
```

## Setup GitHub Repository

Để bật remote installation:

1. **Push lên GitHub**:
   ```bash
   git add .
   git commit -m "Add remote installation support"
   git push origin main
   ```

2. **Update URLs** trong documentation:
   - Thay `USERNAME` bằng GitHub username của bạn
   - Thay `ubuntu-server-setup` bằng tên repository
   - Thay `main` bằng branch name nếu khác

3. **Test remote installation**:
   ```bash
   curl -fsSL https://raw.githubusercontent.com/YOUR_USERNAME/ubuntu-server-setup/main/remote-install.sh | sudo bash -s -- --dry-run
   ```

## Tóm Tắt

✅ **Ưu điểm Remote Install:**
- Cài ngay không cần clone
- Luôn dùng version mới nhất
- Tự động dọn dẹp sau khi cài
- Hoàn hảo cho VPS/cloud servers mới

✅ **Khi nào dùng Local Install:**
- Cần customize scripts
- Không có internet ổn định
- Development/testing
- Cần version control

📝 **Lưu ý quan trọng:**
- Thay `USERNAME` trong URLs bằng GitHub username thật
- Repository phải public hoặc có access token
- Test với `--dry-run` trước khi cài thật
- Lưu passwords ngay sau khi cài!

## Support

**Repository**: https://github.com/USERNAME/ubuntu-server-setup
**Issues**: https://github.com/USERNAME/ubuntu-server-setup/issues
**Docs**: Xem README.md và TESTING.md
