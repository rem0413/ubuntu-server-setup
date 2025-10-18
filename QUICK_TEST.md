# Quick Test Guide - VN

## Test Nhanh Trên Local

### 1. Test Input Script
```bash
# Test đọc input từ terminal
./test-input.sh

# Test đọc input khi bị pipe
cat test-input.sh | bash
```

**Kết quả mong đợi:** Cả 2 trường hợp đều có thể nhập từ bàn phím.

### 2. Test Remote Install (Giả Lập)
```bash
# Giả lập như chạy curl | bash
cat remote-install.sh | sudo bash
```

**Kết quả mong đợi:**
- Menu hiển thị
- Có thể gõ số từ bàn phím
- Confirmation prompt hoạt động

### 3. Test Non-Interactive Mode
```bash
# Test install all
cat remote-install.sh | sudo bash -s -- --all

# Test với profile
cat remote-install.sh | sudo bash -s -- --profile nodejs-app

# Test dry-run
cat remote-install.sh | sudo bash -s -- --dry-run
```

## Test Trên VPS Thật

### Cách 1: Interactive (Khuyến Nghị Test Ngay)

```bash
curl -fsSL https://raw.githubusercontent.com/rem0413/ubuntu-server-setup/master/remote-install.sh | sudo bash
```

**Kỳ vọng:**
1. Banner hiển thị
2. Download files thành công
3. Menu hiện ra với 12 options
4. **Có thể gõ số từ bàn phím** ← ĐÂY LÀ ĐIỂM QUAN TRỌNG
5. Ví dụ gõ: `1 4 7 8`
6. Confirmation prompt hiện ra
7. Gõ `yes` để confirm

### Cách 2: Non-Interactive (Backup Plan)

Nếu cách 1 vẫn lỗi, dùng:

```bash
# Install tất cả
curl -fsSL https://raw.githubusercontent.com/rem0413/ubuntu-server-setup/master/remote-install.sh | sudo bash -s -- --all

# Hoặc dùng profile
curl -fsSL https://raw.githubusercontent.com/rem0413/ubuntu-server-setup/master/remote-install.sh | sudo bash -s -- --profile nodejs-app
```

## Debug Nếu Vẫn Lỗi

### Kiểm Tra /dev/tty

```bash
# Check xem /dev/tty có tồn tại không
ls -l /dev/tty

# Thử đọc từ /dev/tty
read -r test < /dev/tty
echo "Got: $test"
```

### Kiểm Tra Terminal

```bash
# Check xem có terminal không
tty

# Check stdin
[ -t 0 ] && echo "stdin is terminal" || echo "stdin is NOT terminal"
```

### Test Minimal Script

Tạo file test đơn giản:

```bash
cat > test.sh << 'EOF'
#!/bin/bash
echo "Testing stdin..."

if [ -t 0 ]; then
    echo "stdin IS terminal"
    read -r input
else
    echo "stdin NOT terminal, reading from /dev/tty"
    read -r input < /dev/tty
fi

echo "You entered: $input"
EOF

chmod +x test.sh

# Test với pipe
echo "test" | ./test.sh
```

## Checklist

- [ ] Local test: `./test-input.sh` hoạt động
- [ ] Local pipe test: `cat test-input.sh | bash` hoạt động
- [ ] Local install test: `cat remote-install.sh | sudo bash` hiện menu
- [ ] Remote test: `curl | bash` cho phép nhập từ bàn phím
- [ ] Non-interactive: `curl | bash -s -- --all` hoạt động

## Nếu Tất Cả Đều Fail

**Fallback:** Dùng chế độ không tương tác

```bash
# Chọn profile phù hợp:
curl -fsSL https://raw.githubusercontent.com/rem0413/ubuntu-server-setup/master/remote-install.sh | sudo bash -s -- --profile nodejs-app
```

Hoặc clone repo về local:

```bash
git clone https://github.com/rem0413/ubuntu-server-setup.git
cd ubuntu-server-setup
sudo ./install.sh
```

## Giải Thích Kỹ Thuật

### Tại Sao Cần /dev/tty?

Khi chạy `curl URL | bash`:
- `stdin` của bash được nối với output của curl (pipe)
- `read` command không thể đọc từ keyboard
- `/dev/tty` là direct connection đến terminal
- Đọc từ `/dev/tty` = đọc từ keyboard thật

### Cách Hoạt Động

```bash
# Check stdin type
if [ -t 0 ]; then
    # stdin là terminal → đọc bình thường
    read -r input
else
    # stdin bị pipe → đọc từ /dev/tty
    read -r input < /dev/tty
fi
```

### Hạn Chế

Môi trường không có terminal (Docker container, cron jobs, CI/CD) không có `/dev/tty`.

**Giải pháp:** Luôn dùng flags cho automation:
```bash
curl URL | bash -s -- --profile nodejs-app
```

## Support

Nếu vẫn gặp lỗi, tạo issue với thông tin:

```bash
# Chạy các lệnh này và paste kết quả
uname -a
tty
ls -l /dev/tty
[ -t 0 ] && echo "stdin OK" || echo "stdin PIPED"
```
