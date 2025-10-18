#!/bin/bash

################################################################################
# Nginx Unified Management Module
# Description: Install Nginx with advanced configurations and Cloudflare integration
################################################################################

install_nginx() {
    log_step "Nginx Management..."

    # Check if already installed
    local nginx_installed=false
    if command_exists nginx; then
        nginx_installed=true
    fi

    # Interactive menu
    echo ""
    echo -e "${BOLD}Nginx Management:${NC}"
    echo ""

    if [[ "$nginx_installed" == false ]]; then
        echo "  1) Install Nginx"
        echo "  2) Cancel"
    else
        echo "  ${GREEN}Nginx: Installed${NC}"
        echo ""
        echo "  1) Configure Advanced Settings"
        echo "  2) Setup Cloudflare Real IP"
        echo "  3) Test Configuration"
        echo "  4) Reload Nginx"
        echo "  5) Cancel"
    fi

    echo ""
    read -p "Select option: " nginx_choice

    if [[ "$nginx_installed" == false ]]; then
        case $nginx_choice in
            1) install_nginx_server ;;
            *)
                log_info "Nginx installation cancelled"
                return 0
                ;;
        esac
    else
        case $nginx_choice in
            1) configure_nginx_advanced ;;
            2) configure_cloudflare_realip ;;
            3)
                nginx -t
                ;;
            4)
                systemctl reload nginx
                log_success "Nginx reloaded"
                ;;
            *)
                log_info "Nginx management cancelled"
                return 0
                ;;
        esac
    fi
}

install_nginx_server() {
    log_info "Installing Nginx..."

    apt-get update >> /var/log/ubuntu-setup.log 2>&1
    apt-get install -y nginx >> /var/log/ubuntu-setup.log 2>&1

    # Start and enable Nginx
    systemctl start nginx
    systemctl enable nginx >> /var/log/ubuntu-setup.log 2>&1

    if systemctl is-active --quiet nginx; then
        log_success "Nginx installed and running"
    else
        log_error "Nginx installation failed"
        return 1
    fi

    # Create default configuration
    backup_config "/etc/nginx/nginx.conf"

    log_success "Nginx installation complete"

    # Ask if user wants advanced configuration
    echo ""
    if ask_yes_no "Configure advanced settings now?" "y"; then
        configure_nginx_advanced
    fi
}

configure_nginx_advanced() {
    log_info "Configuring Nginx advanced settings..."

    echo ""
    echo -e "${BOLD}Select configuration mode:${NC}"
    echo ""
    echo "  1) Basic - Essential settings only"
    echo "  2) Performance - Optimized for high traffic"
    echo "  3) Reverse Proxy - For Node.js/Python apps"
    echo "  4) Static Server - For HTML/CSS/JS sites"
    echo "  5) Security - Enhanced security headers"
    echo "  6) All - Complete optimization"
    echo "  7) Skip"
    echo ""

    read -p "Choice [1]: " config_mode
    config_mode=${config_mode:-1}

    case $config_mode in
        1|2|3|4|5|6)
            apply_nginx_config "$config_mode"
            ;;
        *)
            log_info "Configuration skipped"
            return 0
            ;;
    esac
}

apply_nginx_config() {
    local mode=$1

    backup_config "/etc/nginx/nginx.conf"

    # Base configuration
    cat > /etc/nginx/nginx.conf << 'EOF'
user www-data;
worker_processes auto;
pid /run/nginx.pid;
include /etc/nginx/modules-enabled/*.conf;

events {
    worker_connections 1024;
    use epoll;
    multi_accept on;
}

http {
    # Basic Settings
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    server_tokens off;

    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    # Logging
    access_log /var/log/nginx/access.log;
    error_log /var/log/nginx/error.log;

    # Gzip
    gzip on;
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types text/plain text/css text/xml text/javascript application/json application/javascript application/xml+rss application/rss+xml font/truetype font/opentype application/vnd.ms-fontobject image/svg+xml;
    gzip_disable "msie6";

    include /etc/nginx/conf.d/*.conf;
    include /etc/nginx/sites-enabled/*;
}
EOF

    # Apply mode-specific settings
    case $mode in
        2|6) # Performance
            sed -i 's/worker_connections 1024;/worker_connections 4096;/' /etc/nginx/nginx.conf
            sed -i 's/keepalive_timeout 65;/keepalive_timeout 30;/' /etc/nginx/nginx.conf

            cat >> /etc/nginx/nginx.conf << 'EOF'

# Performance optimizations
    client_body_buffer_size 128k;
    client_max_body_size 10m;
    client_header_buffer_size 1k;
    large_client_header_buffers 4 4k;
    output_buffers 1 32k;
    postpone_output 1460;
EOF
            ;;
    esac

    case $mode in
        5|6) # Security
            mkdir -p /etc/nginx/conf.d
            cat > /etc/nginx/conf.d/security.conf << 'EOF'
# Security headers
add_header X-Frame-Options "SAMEORIGIN" always;
add_header X-Content-Type-Options "nosniff" always;
add_header X-XSS-Protection "1; mode=block" always;
add_header Referrer-Policy "no-referrer-when-downgrade" always;
add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;
EOF
            ;;
    esac

    # Create sample site based on mode
    case $mode in
        3|6) # Reverse Proxy
            create_reverse_proxy_template
            ;;
        4|6) # Static Server
            create_static_server_template
            ;;
    esac

    # Test configuration
    if nginx -t >> /var/log/ubuntu-setup.log 2>&1; then
        systemctl reload nginx
        log_success "Nginx configuration applied"

        echo ""
        echo -e "${CYAN}Configuration Summary:${NC}"
        case $mode in
            1) echo -e "  ${GREEN}✓${NC} Basic settings applied" ;;
            2) echo -e "  ${GREEN}✓${NC} Performance optimizations applied" ;;
            3) echo -e "  ${GREEN}✓${NC} Reverse proxy template created" ;;
            4) echo -e "  ${GREEN}✓${NC} Static server template created" ;;
            5) echo -e "  ${GREEN}✓${NC} Security headers configured" ;;
            6)
                echo -e "  ${GREEN}✓${NC} Performance optimizations"
                echo -e "  ${GREEN}✓${NC} Security headers"
                echo -e "  ${GREEN}✓${NC} Reverse proxy template"
                echo -e "  ${GREEN}✓${NC} Static server template"
                ;;
        esac
        echo ""
    else
        log_error "Nginx configuration test failed"
        return 1
    fi
}

create_reverse_proxy_template() {
    cat > /etc/nginx/sites-available/reverse-proxy.example << 'EOF'
# Reverse Proxy Configuration Example
# Copy to sites-available/your-app and modify as needed
# Enable with: ln -s /etc/nginx/sites-available/your-app /etc/nginx/sites-enabled/

upstream backend {
    server 127.0.0.1:3000;
    keepalive 64;
}

server {
    listen 80;
    listen [::]:80;
    server_name example.com;

    location / {
        proxy_pass http://backend;
        proxy_http_version 1.1;

        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        proxy_cache_bypass $http_upgrade;
        proxy_read_timeout 300;
    }

    # Static files
    location ~* \.(jpg|jpeg|png|gif|ico|css|js|svg|woff|woff2)$ {
        expires 30d;
        add_header Cache-Control "public, immutable";
    }
}
EOF

    log_info "Reverse proxy template created: /etc/nginx/sites-available/reverse-proxy.example"
}

create_static_server_template() {
    cat > /etc/nginx/sites-available/static-site.example << 'EOF'
# Static Site Configuration Example
# Copy to sites-available/your-site and modify as needed
# Enable with: ln -s /etc/nginx/sites-available/your-site /etc/nginx/sites-enabled/

server {
    listen 80;
    listen [::]:80;
    server_name example.com;

    root /var/www/html;
    index index.html index.htm;

    # Deny access to hidden files
    location ~ /\. {
        deny all;
    }

    # Main location
    location / {
        try_files $uri $uri/ /index.html;
    }

    # Cache static assets
    location ~* \.(jpg|jpeg|png|gif|ico|css|js|svg|woff|woff2|ttf|eot)$ {
        expires 30d;
        add_header Cache-Control "public, immutable";
    }

    # Disable caching for HTML
    location ~* \.html$ {
        expires -1;
        add_header Cache-Control "no-cache, no-store, must-revalidate";
    }
}
EOF

    log_info "Static site template created: /etc/nginx/sites-available/static-site.example"
}

configure_cloudflare_realip() {
    log_info "Configuring Cloudflare Real IP..."

    # Check if Nginx is installed
    if ! command_exists nginx; then
        log_error "Nginx is not installed"
        return 1
    fi

    # Create cloudflare config directory
    mkdir -p /etc/nginx/conf.d

    # Fetch Cloudflare IPs
    log_info "Fetching Cloudflare IP ranges..."

    local cf_ipv4_url="https://www.cloudflare.com/ips-v4"
    local cf_ipv6_url="https://www.cloudflare.com/ips-v6"

    # Download IPv4 ranges
    if ! curl -s "$cf_ipv4_url" > /tmp/cf-ips-v4.txt; then
        log_error "Failed to fetch Cloudflare IPv4 ranges"
        return 1
    fi

    # Download IPv6 ranges
    if ! curl -s "$cf_ipv6_url" > /tmp/cf-ips-v6.txt; then
        log_warning "Failed to fetch Cloudflare IPv6 ranges"
    fi

    # Create Cloudflare Real IP configuration
    cat > /etc/nginx/conf.d/cloudflare-realip.conf << 'EOF'
# Cloudflare Real IP Configuration
# Automatically updated on: EOF
    echo "# $(date)" >> /etc/nginx/conf.d/cloudflare-realip.conf

    cat >> /etc/nginx/conf.d/cloudflare-realip.conf << 'EOF'

# CloudFlare IPv4 ranges
EOF

    # Add IPv4 ranges
    while IFS= read -r ip; do
        echo "set_real_ip_from $ip;" >> /etc/nginx/conf.d/cloudflare-realip.conf
    done < /tmp/cf-ips-v4.txt

    cat >> /etc/nginx/conf.d/cloudflare-realip.conf << 'EOF'

# CloudFlare IPv6 ranges
EOF

    # Add IPv6 ranges if available
    if [[ -f /tmp/cf-ips-v6.txt ]]; then
        while IFS= read -r ip; do
            echo "set_real_ip_from $ip;" >> /etc/nginx/conf.d/cloudflare-realip.conf
        done < /tmp/cf-ips-v6.txt
    fi

    cat >> /etc/nginx/conf.d/cloudflare-realip.conf << 'EOF'

# Use CF-Connecting-IP header
real_ip_header CF-Connecting-IP;
EOF

    # Clean up temp files
    rm -f /tmp/cf-ips-v4.txt /tmp/cf-ips-v6.txt

    # Test configuration
    if nginx -t >> /var/log/ubuntu-setup.log 2>&1; then
        systemctl reload nginx
        log_success "Cloudflare Real IP configured"

        echo ""
        echo -e "${CYAN}Cloudflare Configuration Summary:${NC}"
        echo -e "  ${GREEN}✓${NC} Cloudflare IP ranges fetched"
        echo -e "  ${GREEN}✓${NC} Real IP header configured (CF-Connecting-IP)"
        echo -e "  ${GREEN}✓${NC} Nginx reloaded"
        echo ""
        echo -e "${BOLD}Config file:${NC} /etc/nginx/conf.d/cloudflare-realip.conf"
        echo ""
        echo -e "${DIM}Note: Update IP ranges monthly with this command:${NC}"
        echo -e "  ${CYAN}sudo ./install.sh${NC} (select Nginx → Cloudflare Real IP)"
        echo ""
    else
        log_error "Nginx configuration test failed"
        rm -f /etc/nginx/conf.d/cloudflare-realip.conf
        return 1
    fi
}

cleanup_nginx() {
    log_info "Removing Nginx..."

    systemctl stop nginx 2>/dev/null || true
    systemctl disable nginx 2>/dev/null || true

    if [[ "$1" == "--purge" ]]; then
        apt-get remove --purge -y nginx nginx-common nginx-core >> /var/log/ubuntu-setup.log 2>&1
        rm -rf /etc/nginx /var/www/html /var/log/nginx
        log_success "Nginx removed (including all configs)"
    else
        apt-get remove -y nginx >> /var/log/ubuntu-setup.log 2>&1
        log_success "Nginx removed (configs preserved)"
    fi
}
