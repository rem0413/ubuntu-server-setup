#!/bin/bash

################################################################################
# Ubuntu Server Setup - Deploy Script
# Description: Quick deployment helper for Node.js applications
# Usage: sudo ./deploy.sh [OPTIONS]
################################################################################

set -e

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load libraries
source "$SCRIPT_DIR/lib/colors.sh"
source "$SCRIPT_DIR/lib/utils.sh"
source "$SCRIPT_DIR/lib/ui.sh"

# Configuration
DEPLOY_ROOT="/var/www"
APP_NAME=""
REPO_URL=""
APP_PORT=""
DOMAIN=""
DB_TYPE=""
IS_STATIC=false
INSTALL_DEPS=true

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --repo)
            REPO_URL="$2"
            shift 2
            ;;
        --name)
            APP_NAME="$2"
            shift 2
            ;;
        --port)
            APP_PORT="$2"
            shift 2
            ;;
        --domain)
            DOMAIN="$2"
            shift 2
            ;;
        --db)
            DB_TYPE="$2"
            shift 2
            ;;
        --static)
            IS_STATIC=true
            shift
            ;;
        --no-deps)
            INSTALL_DEPS=false
            shift
            ;;
        --help|-h)
            cat << EOF
Deploy Script - Quick deployment helper for web applications

Usage: $0 [OPTIONS]

Options:
    --repo <url>         Git repository URL (required)
    --name <name>        Application name (default: repo name)
    --port <port>        Application port (default: 3000)
    --domain <domain>    Domain name for Nginx config
    --db <type>          Database type (mongodb/postgresql)
    --static             Deploy as static site (no PM2)
    --no-deps            Skip npm install
    --help, -h           Show this help message

Examples:
    # Deploy Node.js app
    sudo ./deploy.sh --repo https://github.com/user/app.git \\
                     --name myapp \\
                     --port 3000 \\
                     --domain myapp.com

    # Deploy with MongoDB
    sudo ./deploy.sh --repo URL --db mongodb

    # Deploy static site
    sudo ./deploy.sh --repo URL --static --domain site.com

What it does:
    1. Clone repository to /var/www/app-name
    2. Install dependencies (npm install)
    3. Setup .env file (interactive)
    4. Start with PM2 (for Node.js apps)
    5. Create Nginx config
    6. Setup firewall
    7. Test deployment

Requirements:
    - Git
    - Node.js & npm (for Node apps)
    - PM2 (for Node apps)
    - Nginx

EOF
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Check root
check_root || exit 1

# Banner
echo -e "${CYAN}"
cat << "EOF"
╔══════════════════════════════════════════════════════════════╗
║                  DEPLOY APPLICATION                          ║
╚══════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

# Validate input
if [[ -z "$REPO_URL" ]]; then
    log_error "Repository URL is required"
    log_info "Usage: sudo ./deploy.sh --repo <url>"
    exit 1
fi

# Extract app name from repo if not provided
if [[ -z "$APP_NAME" ]]; then
    APP_NAME=$(basename "$REPO_URL" .git)
    log_info "Using app name: $APP_NAME"
fi

# Set default port
if [[ -z "$APP_PORT" ]] && [[ "$IS_STATIC" == false ]]; then
    APP_PORT=3000
fi

# Check dependencies
log_info "Checking dependencies..."

if ! command -v git &>/dev/null; then
    log_error "Git is not installed"
    log_info "Run: sudo ./install.sh (select option 1)"
    exit 1
fi

if [[ "$IS_STATIC" == false ]]; then
    if ! command -v node &>/dev/null; then
        log_error "Node.js is not installed"
        log_info "Run: sudo ./install.sh (select option 4)"
        exit 1
    fi

    if ! command -v pm2 &>/dev/null; then
        log_error "PM2 is not installed"
        log_info "Run: sudo ./install.sh (select option 5)"
        exit 1
    fi
fi

if ! command -v nginx &>/dev/null; then
    log_warning "Nginx is not installed (required for domain setup)"
fi

log_success "All dependencies available"

# Deployment steps
APP_DIR="$DEPLOY_ROOT/$APP_NAME"

echo ""
log_info "Deployment plan:"
echo -e "  Repository: ${CYAN}$REPO_URL${NC}"
echo -e "  App name: ${CYAN}$APP_NAME${NC}"
echo -e "  Location: ${CYAN}$APP_DIR${NC}"
if [[ "$IS_STATIC" == false ]]; then
    echo -e "  Port: ${CYAN}$APP_PORT${NC}"
fi
if [[ -n "$DOMAIN" ]]; then
    echo -e "  Domain: ${CYAN}$DOMAIN${NC}"
fi
if [[ -n "$DB_TYPE" ]]; then
    echo -e "  Database: ${CYAN}$DB_TYPE${NC}"
fi
echo ""

if ! ask_yes_no "Continue with deployment?" "y"; then
    log_info "Deployment cancelled"
    exit 0
fi

# Create deploy directory
mkdir -p "$DEPLOY_ROOT"

# Clone repository
echo ""
log_info "Cloning repository..."

if [[ -d "$APP_DIR" ]]; then
    log_warning "Directory already exists"
    if ask_yes_no "Remove existing directory?" "n"; then
        rm -rf "$APP_DIR"
    else
        log_error "Deployment cancelled"
        exit 1
    fi
fi

git clone "$REPO_URL" "$APP_DIR" >> /var/log/ubuntu-setup.log 2>&1

if [[ ! -d "$APP_DIR" ]]; then
    log_error "Failed to clone repository"
    exit 1
fi

log_success "Repository cloned"
cd "$APP_DIR"

# Install dependencies
if [[ "$IS_STATIC" == false ]] && [[ "$INSTALL_DEPS" == true ]]; then
    if [[ -f package.json ]]; then
        log_info "Installing dependencies..."
        npm install >> /var/log/ubuntu-setup.log 2>&1
        log_success "Dependencies installed"
    fi
fi

# Setup environment variables
if [[ "$IS_STATIC" == false ]] && [[ -f .env.example ]]; then
    log_info "Setting up environment variables..."

    if [[ ! -f .env ]]; then
        cp .env.example .env

        # Auto-fill database credentials if available
        if [[ -n "$DB_TYPE" ]] && [[ -f /root/ubuntu-setup-summary.txt ]]; then
            log_info "Would you like to configure database connection?"

            if [[ "$DB_TYPE" == "mongodb" ]]; then
                echo ""
                echo -e "${YELLOW}Enter MongoDB credentials (from installation summary):${NC}"
                read -p "MongoDB URI [mongodb://localhost:27017/dbname]: " mongo_uri
                mongo_uri=${mongo_uri:-mongodb://localhost:27017/$APP_NAME}

                # Update .env
                if grep -q "MONGO" .env; then
                    sed -i "s|MONGO.*=.*|MONGODB_URI=$mongo_uri|" .env
                else
                    echo "MONGODB_URI=$mongo_uri" >> .env
                fi
            elif [[ "$DB_TYPE" == "postgresql" ]]; then
                echo ""
                echo -e "${YELLOW}Enter PostgreSQL credentials (from installation summary):${NC}"
                read -p "Database host [localhost]: " db_host
                read -p "Database name [$APP_NAME]: " db_name
                read -p "Database user: " db_user
                read -s -p "Database password: " db_pass
                echo ""

                db_host=${db_host:-localhost}
                db_name=${db_name:-$APP_NAME}

                DATABASE_URL="postgresql://$db_user:$db_pass@$db_host:5432/$db_name"

                if grep -q "DATABASE" .env; then
                    sed -i "s|DATABASE.*=.*|DATABASE_URL=$DATABASE_URL|" .env
                else
                    echo "DATABASE_URL=$DATABASE_URL" >> .env
                fi
            fi
        fi

        # Set PORT
        if grep -q "PORT" .env; then
            sed -i "s/PORT=.*/PORT=$APP_PORT/" .env
        else
            echo "PORT=$APP_PORT" >> .env
        fi

        log_success "Environment configured"
        log_warning "Review .env file: nano $APP_DIR/.env"
    else
        log_info ".env file already exists"
    fi
fi

# Build if needed
if [[ "$IS_STATIC" == false ]] && [[ -f package.json ]]; then
    if grep -q '"build"' package.json; then
        log_info "Building application..."
        npm run build >> /var/log/ubuntu-setup.log 2>&1 || log_warning "Build failed or not configured"
    fi
fi

# Start with PM2 (for Node.js apps)
if [[ "$IS_STATIC" == false ]]; then
    log_info "Starting application with PM2..."

    # Determine start script
    START_SCRIPT="index.js"
    if [[ -f package.json ]]; then
        if grep -q '"start"' package.json; then
            START_SCRIPT="npm"
        elif [[ -f server.js ]]; then
            START_SCRIPT="server.js"
        elif [[ -f app.js ]]; then
            START_SCRIPT="app.js"
        elif [[ -f src/index.js ]]; then
            START_SCRIPT="src/index.js"
        fi
    fi

    # Stop existing process
    pm2 delete "$APP_NAME" 2>/dev/null || true

    # Start with PM2
    if [[ "$START_SCRIPT" == "npm" ]]; then
        pm2 start npm --name "$APP_NAME" -- start
    else
        pm2 start "$START_SCRIPT" --name "$APP_NAME"
    fi

    pm2 save

    log_success "Application started with PM2"

    # Show PM2 info
    echo ""
    pm2 info "$APP_NAME"
fi

# Setup Nginx
if command -v nginx &>/dev/null && [[ -n "$DOMAIN" ]]; then
    log_info "Configuring Nginx..."

    NGINX_CONF="/etc/nginx/sites-available/$APP_NAME"

    if [[ "$IS_STATIC" == true ]]; then
        # Static site config
        cat > "$NGINX_CONF" << EOF
server {
    listen 80;
    listen [::]:80;
    server_name $DOMAIN;

    root $APP_DIR;
    index index.html index.htm;

    location / {
        try_files \$uri \$uri/ /index.html;
    }

    # Cache static assets
    location ~* \\.(jpg|jpeg|png|gif|ico|css|js|svg|woff|woff2|ttf|eot)$ {
        expires 30d;
        add_header Cache-Control "public, immutable";
    }

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
}
EOF
    else
        # Reverse proxy config
        cat > "$NGINX_CONF" << EOF
upstream ${APP_NAME}_backend {
    server 127.0.0.1:$APP_PORT;
    keepalive 64;
}

server {
    listen 80;
    listen [::]:80;
    server_name $DOMAIN;

    location / {
        proxy_pass http://${APP_NAME}_backend;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
    }

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
}
EOF
    fi

    # Enable site
    ln -sf "$NGINX_CONF" /etc/nginx/sites-enabled/

    # Test config
    if nginx -t >> /var/log/ubuntu-setup.log 2>&1; then
        systemctl reload nginx
        log_success "Nginx configured"
    else
        log_error "Nginx configuration failed"
        rm -f "/etc/nginx/sites-enabled/$APP_NAME"
    fi
fi

# Setup firewall
if command -v ufw &>/dev/null && ufw status | grep -q "Status: active"; then
    log_info "Configuring firewall..."

    ufw allow 'Nginx Full' >> /var/log/ubuntu-setup.log 2>&1 || true

    log_success "Firewall configured"
fi

# Final summary
echo ""
echo -e "${CYAN}═══════════════════════════════════════${NC}"
echo -e "${BOLD}${GREEN}Deployment completed!${NC}"
echo -e "${CYAN}═══════════════════════════════════════${NC}"
echo ""
echo -e "${BOLD}Application:${NC} $APP_NAME"
echo -e "${BOLD}Location:${NC} $APP_DIR"

if [[ "$IS_STATIC" == false ]]; then
    echo -e "${BOLD}Port:${NC} $APP_PORT"
    echo -e "${BOLD}PM2 status:${NC} pm2 list"
    echo -e "${BOLD}Logs:${NC} pm2 logs $APP_NAME"
fi

if [[ -n "$DOMAIN" ]]; then
    echo -e "${BOLD}Domain:${NC} http://$DOMAIN"
    echo ""
    echo -e "${YELLOW}Setup SSL:${NC} sudo ./ssl.sh --domain $DOMAIN"
fi

echo ""
echo -e "${BOLD}Next steps:${NC}"
echo -e "  1. Test application: ${CYAN}curl http://localhost:${APP_PORT:-80}${NC}"
if [[ -n "$DOMAIN" ]]; then
    echo -e "  2. Setup DNS: Point $DOMAIN to this server"
    echo -e "  3. Setup SSL: ${CYAN}sudo ./ssl.sh --domain $DOMAIN${NC}"
fi
if [[ "$IS_STATIC" == false ]]; then
    echo -e "  4. Monitor logs: ${CYAN}pm2 logs $APP_NAME${NC}"
fi
echo ""
