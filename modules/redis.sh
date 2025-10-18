#!/bin/bash

################################################################################
# Redis Installation Module
# Description: Install and configure Redis server with security and cluster options
################################################################################

install_redis() {
    local REDIS_PASSWORD=""
    local REDIS_PORT=6379
    local SETUP_CLUSTER=false

    log_step "Installing Redis..."

    # Interactive menu
    echo ""
    echo -e "${BOLD}Redis Configuration:${NC}"
    echo ""
    echo "  1) Standalone Redis (default)"
    echo "  2) Redis Cluster (3 master + 3 replica minimum)"
    echo ""

    read -p "Select mode [1]: " mode_choice
    mode_choice=${mode_choice:-1}

    if [[ "$mode_choice" == "2" ]]; then
        SETUP_CLUSTER=true
    fi

    # Port configuration
    echo ""
    read -p "Redis port [6379]: " port_input
    REDIS_PORT=${port_input:-6379}

    # Validate port
    if [[ ! "$REDIS_PORT" =~ ^[0-9]+$ ]] || [[ "$REDIS_PORT" -lt 1024 ]] || [[ "$REDIS_PORT" -gt 65535 ]]; then
        log_warning "Invalid port, using default 6379"
        REDIS_PORT=6379
    fi

    # Install Redis
    apt-get update >> /var/log/ubuntu-setup.log 2>&1
    apt-get install -y redis-server redis-tools >> /var/log/ubuntu-setup.log 2>&1

    # Generate password
    REDIS_PASSWORD=$(generate_password)

    if [[ "$SETUP_CLUSTER" == true ]]; then
        setup_redis_cluster "$REDIS_PORT" "$REDIS_PASSWORD"
    else
        setup_redis_standalone "$REDIS_PORT" "$REDIS_PASSWORD"
    fi
}

setup_redis_standalone() {
    local port=$1
    local password=$2

    log_info "Configuring Redis standalone on port $port..."

    # Backup original config
    backup_config "/etc/redis/redis.conf"

    # Configure Redis
    sed -i "s/^port 6379/port $port/" /etc/redis/redis.conf
    sed -i 's/^supervised no/supervised systemd/' /etc/redis/redis.conf
    sed -i 's/^bind 127.0.0.1 ::1/bind 127.0.0.1/' /etc/redis/redis.conf

    # Enable password authentication
    if grep -q "^# requirepass" /etc/redis/redis.conf; then
        sed -i "s/^# requirepass .*/requirepass $password/" /etc/redis/redis.conf
    else
        echo "requirepass $password" >> /etc/redis/redis.conf
    fi

    # Set maxmemory policy (LRU eviction)
    if ! grep -q "^maxmemory-policy" /etc/redis/redis.conf; then
        echo "maxmemory-policy allkeys-lru" >> /etc/redis/redis.conf
    fi

    # Set maxmemory to 256MB
    if ! grep -q "^maxmemory " /etc/redis/redis.conf; then
        echo "maxmemory 256mb" >> /etc/redis/redis.conf
    fi

    # Disable dangerous commands
    cat >> /etc/redis/redis.conf << EOF

# Disable dangerous commands
rename-command FLUSHDB ""
rename-command FLUSHALL ""
rename-command KEYS ""
rename-command CONFIG ""
EOF

    # Set appendonly for persistence
    sed -i 's/^appendonly no/appendonly yes/' /etc/redis/redis.conf

    # Restart Redis
    log_info "Starting Redis server..."
    systemctl restart redis-server >> /var/log/ubuntu-setup.log 2>&1

    if [[ $? -ne 0 ]]; then
        log_error "Failed to restart Redis"
        log_info "Checking Redis logs..."
        journalctl -u redis-server -n 50 --no-pager
        return 1
    fi

    systemctl enable redis-server >> /var/log/ubuntu-setup.log 2>&1

    # Wait for Redis to start
    sleep 2

    # Test Redis
    if systemctl is-active --quiet redis-server; then
        log_success "Redis installed and running"
    else
        log_error "Redis service not active"
        log_info "Service status:"
        systemctl status redis-server --no-pager
        log_info "Recent logs:"
        journalctl -u redis-server -n 20 --no-pager
        return 1
    fi

    # Test connection
    if redis-cli -p "$port" -a "$password" ping &>/dev/null; then
        log_success "Redis authentication working"
    else
        log_warning "Redis authentication test failed"
    fi

    # Display info
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo -e "${BOLD}Redis Standalone Installation Summary:${NC}"
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo -e "${BOLD}Status:${NC} Running"
    echo -e "${BOLD}Version:${NC} $(redis-server --version | awk '{print $3}')"
    echo -e "${BOLD}Mode:${NC} Standalone"
    echo -e "${BOLD}Bind Address:${NC} 127.0.0.1 (localhost only)"
    echo -e "${BOLD}Port:${NC} $port"
    echo ""
    echo -e "${YELLOW}${BOLD}IMPORTANT - Save Redis Password:${NC}"
    echo -e "${BOLD}Password:${NC} ${RED}$password${NC}"
    echo ""
    echo -e "${DIM}This password will not be displayed again!${NC}"
    echo -e "${DIM}Save it to a secure location now.${NC}"
    echo ""
    echo -e "${BOLD}Connection Examples:${NC}"
    echo -e "${DIM}# CLI:${NC}"
    echo -e "  redis-cli -p $port -a '$password'"
    echo ""
    echo -e "${DIM}# Node.js:${NC}"
    echo -e "  redis://default:$password@localhost:$port"
    echo ""
    echo -e "${DIM}# Python:${NC}"
    echo -e "  redis.Redis(host='localhost', port=$port, password='$password')"
    echo ""
    echo -e "${BOLD}Configuration:${NC}"
    echo -e "  Config file: /etc/redis/redis.conf"
    echo -e "  Persistence: Enabled (AOF)"
    echo -e "  Max memory: 256MB"
    echo -e "  Eviction: allkeys-lru"
    echo ""
    echo -e "${BOLD}Security:${NC}"
    echo -e "  ${GREEN}✓${NC} Password authentication enabled"
    echo -e "  ${GREEN}✓${NC} Bound to localhost only"
    echo -e "  ${GREEN}✓${NC} Dangerous commands disabled"
    echo ""
    echo -e "${BOLD}Useful Commands:${NC}"
    echo -e "  Status: ${CYAN}sudo systemctl status redis-server${NC}"
    echo -e "  Logs: ${CYAN}sudo journalctl -u redis-server -f${NC}"
    echo -e "  Connect: ${CYAN}redis-cli -p $port -a 'PASSWORD'${NC}"
    echo -e "  Monitor: ${CYAN}redis-cli -p $port -a 'PASSWORD' monitor${NC}"
    echo -e "  Info: ${CYAN}redis-cli -p $port -a 'PASSWORD' info${NC}"
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo ""

    # Save to summary
    cat >> /root/ubuntu-setup-summary.txt << EOF

Redis Standalone:
  Port: $port
  Password: $password
  Connection: redis://default:$password@localhost:$port
  Config: /etc/redis/redis.conf

EOF

    log_info "Redis credentials saved to: /root/ubuntu-setup-summary.txt"
}

setup_redis_cluster() {
    local base_port=$1
    local password=$2

    log_info "Configuring Redis Cluster..."

    # Cluster requires at least 3 master + 3 replicas (6 nodes)
    local nodes=6
    local cluster_ports=()

    for i in $(seq 0 $((nodes - 1))); do
        local port=$((base_port + i))
        cluster_ports+=($port)

        # Create node directory
        mkdir -p /var/lib/redis-cluster/$port
        chown redis:redis /var/lib/redis-cluster/$port

        # Create node config
        cat > /etc/redis/redis-cluster-$port.conf << EOF
port $port
cluster-enabled yes
cluster-config-file /var/lib/redis-cluster/$port/nodes.conf
cluster-node-timeout 5000
appendonly yes
appendfilename "appendonly-$port.aof"
dir /var/lib/redis-cluster/$port
bind 127.0.0.1
requirepass $password
masterauth $password
supervised systemd
maxmemory 256mb
maxmemory-policy allkeys-lru

# Disable dangerous commands
rename-command FLUSHDB ""
rename-command FLUSHALL ""
rename-command KEYS ""
rename-command CONFIG ""
EOF

        chown redis:redis /etc/redis/redis-cluster-$port.conf

        # Create systemd service for each node
        cat > /etc/systemd/system/redis-cluster-$port.service << EOF
[Unit]
Description=Redis Cluster Node $port
After=network.target

[Service]
Type=notify
User=redis
Group=redis
ExecStart=/usr/bin/redis-server /etc/redis/redis-cluster-$port.conf
ExecStop=/bin/kill -s TERM \$MAINPID
Restart=always

[Install]
WantedBy=multi-user.target
EOF

        # Start node
        systemctl daemon-reload
        systemctl start redis-cluster-$port
        systemctl enable redis-cluster-$port >> /var/log/ubuntu-setup.log 2>&1

        log_success "Redis node started on port $port"
    done

    # Wait for all nodes to start
    sleep 3

    # Create cluster
    log_info "Creating Redis cluster..."

    local cluster_create_cmd="redis-cli --cluster create"
    for port in "${cluster_ports[@]}"; do
        cluster_create_cmd+=" 127.0.0.1:$port"
    done
    cluster_create_cmd+=" --cluster-replicas 1 -a $password --cluster-yes"

    if eval $cluster_create_cmd >> /var/log/ubuntu-setup.log 2>&1; then
        log_success "Redis cluster created successfully"
    else
        log_error "Failed to create Redis cluster"
        return 1
    fi

    # Display summary
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo -e "${BOLD}Redis Cluster Installation Summary:${NC}"
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo -e "${BOLD}Mode:${NC} Cluster (3 masters + 3 replicas)"
    echo -e "${BOLD}Base Port:${NC} $base_port"
    echo -e "${BOLD}Nodes:${NC}"
    for port in "${cluster_ports[@]}"; do
        echo -e "  - localhost:$port"
    done
    echo ""
    echo -e "${YELLOW}${BOLD}IMPORTANT - Save Redis Password:${NC}"
    echo -e "${BOLD}Password:${NC} ${RED}$password${NC}"
    echo ""
    echo -e "${BOLD}Connection Examples:${NC}"
    echo -e "${DIM}# CLI (connect to any node):${NC}"
    echo -e "  redis-cli -c -p $base_port -a '$password'"
    echo ""
    echo -e "${DIM}# Node.js:${NC}"
    echo -e "  new Redis.Cluster(["
    for port in "${cluster_ports[@]}"; do
        echo -e "    { host: 'localhost', port: $port },"
    done
    echo -e "  ], { redisOptions: { password: '$password' } })"
    echo ""
    echo -e "${BOLD}Cluster Commands:${NC}"
    echo -e "  Cluster info: ${CYAN}redis-cli -c -p $base_port -a 'PASSWORD' cluster info${NC}"
    echo -e "  Cluster nodes: ${CYAN}redis-cli -c -p $base_port -a 'PASSWORD' cluster nodes${NC}"
    echo -e "  Cluster slots: ${CYAN}redis-cli -c -p $base_port -a 'PASSWORD' cluster slots${NC}"
    echo ""
    echo -e "${BOLD}Service Management:${NC}"
    for port in "${cluster_ports[@]}"; do
        echo -e "  Node $port: ${CYAN}sudo systemctl status redis-cluster-$port${NC}"
    done
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo ""

    # Save to summary
    cat >> /root/ubuntu-setup-summary.txt << EOF

Redis Cluster:
  Base Port: $base_port
  Nodes: ${cluster_ports[@]}
  Password: $password
  Connection: redis-cli -c -p $base_port -a '$password'

EOF

    log_info "Redis cluster credentials saved to: /root/ubuntu-setup-summary.txt"
}

cleanup_redis() {
    log_info "Removing Redis..."

    # Stop standalone service
    systemctl stop redis-server 2>/dev/null || true
    systemctl disable redis-server 2>/dev/null || true

    # Stop cluster nodes
    for service in /etc/systemd/system/redis-cluster-*.service; do
        if [[ -f "$service" ]]; then
            local service_name=$(basename "$service")
            systemctl stop "$service_name" 2>/dev/null || true
            systemctl disable "$service_name" 2>/dev/null || true
        fi
    done

    # Remove packages and files
    if [[ "$1" == "--purge" ]]; then
        apt-get remove --purge -y redis-server redis-tools >> /var/log/ubuntu-setup.log 2>&1
        rm -rf /etc/redis /var/lib/redis /var/log/redis /var/lib/redis-cluster
        rm -f /etc/redis/redis-cluster-*.conf
        rm -f /etc/systemd/system/redis-cluster-*.service
        systemctl daemon-reload
        log_success "Redis removed (including data)"
    else
        apt-get remove -y redis-server redis-tools >> /var/log/ubuntu-setup.log 2>&1
        rm -f /etc/redis/redis-cluster-*.conf
        rm -f /etc/systemd/system/redis-cluster-*.service
        systemctl daemon-reload
        log_success "Redis removed (data preserved)"
    fi
}
