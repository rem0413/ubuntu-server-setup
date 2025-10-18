#!/bin/bash

################################################################################
# Monitoring Stack Installation Module
# Description: Install Prometheus, Grafana, and various exporters
################################################################################

install_monitoring() {
    local GRAFANA_PASSWORD=""
    local PROM_VERSION="2.48.0"
    local NODE_EXPORTER_VERSION="1.7.0"
    local MYSQLD_EXPORTER_VERSION="0.15.1"
    local POSTGRES_EXPORTER_VERSION="0.15.0"
    local REDIS_EXPORTER_VERSION="1.55.0"
    local MONGODB_EXPORTER_VERSION="0.40.0"

    log_step "Installing Monitoring Stack..."

    # Interactive menu for component selection
    echo ""
    echo "Select monitoring components:"
    echo ""
    echo "  1) Prometheus (metrics database)"
    echo "  2) Grafana (visualization dashboard)"
    echo "  3) node_exporter (system metrics exporter)"
    echo "  4) mysqld_exporter (MySQL metrics exporter)"
    echo "  5) postgres_exporter (PostgreSQL metrics exporter)"
    echo "  6) redis_exporter (Redis metrics exporter)"
    echo "  7) mongodb_exporter (MongoDB metrics exporter)"
    echo ""
    echo "  0) Install all"
    echo "  q) Cancel"
    echo ""
    echo "Note: Exporters work standalone and can export to any monitoring system"
    echo ""

    printf "Enter selections (e.g., 1 2 3 or just 3 for exporter only): " >/dev/tty
    read -r selections </dev/tty

    case "$selections" in
        q|Q)
            log_info "Monitoring installation cancelled"
            return 0
            ;;
        0)
            INSTALL_PROMETHEUS=true
            INSTALL_GRAFANA=true
            INSTALL_NODE_EXPORTER=true
            INSTALL_MYSQLD_EXPORTER=true
            INSTALL_POSTGRES_EXPORTER=true
            INSTALL_REDIS_EXPORTER=true
            INSTALL_MONGODB_EXPORTER=true
            ;;
        *)
            INSTALL_PROMETHEUS=false
            INSTALL_GRAFANA=false
            INSTALL_NODE_EXPORTER=false
            INSTALL_MYSQLD_EXPORTER=false
            INSTALL_POSTGRES_EXPORTER=false
            INSTALL_REDIS_EXPORTER=false
            INSTALL_MONGODB_EXPORTER=false

            for selection in $selections; do
                case $selection in
                    1) INSTALL_PROMETHEUS=true ;;
                    2) INSTALL_GRAFANA=true ;;
                    3) INSTALL_NODE_EXPORTER=true ;;
                    4) INSTALL_MYSQLD_EXPORTER=true ;;
                    5) INSTALL_POSTGRES_EXPORTER=true ;;
                    6) INSTALL_REDIS_EXPORTER=true ;;
                    7) INSTALL_MONGODB_EXPORTER=true ;;
                esac
            done
            ;;
    esac

    # Exporters are standalone - no requirements

    # Create monitoring user
    if ! id -u prometheus &>/dev/null; then
        useradd --no-create-home --shell /bin/false prometheus
    fi

    # Install node_exporter
    if [[ "$INSTALL_NODE_EXPORTER" == true ]]; then
        log_info "Installing node_exporter..."

        cd /tmp
        wget -q "https://github.com/prometheus/node_exporter/releases/download/v${NODE_EXPORTER_VERSION}/node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz"
        tar xzf "node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz"
        cp "node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64/node_exporter" /usr/local/bin/
        chown prometheus:prometheus /usr/local/bin/node_exporter
        rm -rf node_exporter-*

        cat > /etc/systemd/system/node_exporter.service << EOF
[Unit]
Description=Node Exporter
After=network.target

[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart=/usr/local/bin/node_exporter

[Install]
WantedBy=multi-user.target
EOF

        systemctl daemon-reload
        systemctl start node_exporter
        systemctl enable node_exporter >> /var/log/ubuntu-setup.log 2>&1

        if systemctl is-active --quiet node_exporter; then
            log_success "node_exporter installed (port 9100)"
        fi
    fi

    # Install mysqld_exporter
    if [[ "$INSTALL_MYSQLD_EXPORTER" == true ]]; then
        log_info "Installing mysqld_exporter..."

        cd /tmp
        wget -q "https://github.com/prometheus/mysqld_exporter/releases/download/v${MYSQLD_EXPORTER_VERSION}/mysqld_exporter-${MYSQLD_EXPORTER_VERSION}.linux-amd64.tar.gz"
        tar xzf "mysqld_exporter-${MYSQLD_EXPORTER_VERSION}.linux-amd64.tar.gz"
        cp "mysqld_exporter-${MYSQLD_EXPORTER_VERSION}.linux-amd64/mysqld_exporter" /usr/local/bin/
        chown prometheus:prometheus /usr/local/bin/mysqld_exporter
        rm -rf mysqld_exporter-*

        # Create .my.cnf for exporter
        mkdir -p /etc/mysqld_exporter
        cat > /etc/mysqld_exporter/.my.cnf << EOF
[client]
user=exporter
password=CHANGE_ME
EOF
        chown prometheus:prometheus /etc/mysqld_exporter/.my.cnf
        chmod 600 /etc/mysqld_exporter/.my.cnf

        cat > /etc/systemd/system/mysqld_exporter.service << EOF
[Unit]
Description=MySQL Exporter
After=network.target

[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart=/usr/local/bin/mysqld_exporter --config.my-cnf=/etc/mysqld_exporter/.my.cnf

[Install]
WantedBy=multi-user.target
EOF

        systemctl daemon-reload

        log_success "mysqld_exporter installed (port 9104)"
        log_warning "Configure MySQL credentials in /etc/mysqld_exporter/.my.cnf"
    fi

    # Install postgres_exporter
    if [[ "$INSTALL_POSTGRES_EXPORTER" == true ]]; then
        log_info "Installing postgres_exporter..."

        cd /tmp
        wget -q "https://github.com/prometheus-community/postgres_exporter/releases/download/v${POSTGRES_EXPORTER_VERSION}/postgres_exporter-${POSTGRES_EXPORTER_VERSION}.linux-amd64.tar.gz"
        tar xzf "postgres_exporter-${POSTGRES_EXPORTER_VERSION}.linux-amd64.tar.gz"
        cp "postgres_exporter-${POSTGRES_EXPORTER_VERSION}.linux-amd64/postgres_exporter" /usr/local/bin/
        chown prometheus:prometheus /usr/local/bin/postgres_exporter
        rm -rf postgres_exporter-*

        cat > /etc/systemd/system/postgres_exporter.service << EOF
[Unit]
Description=PostgreSQL Exporter
After=network.target

[Service]
User=prometheus
Group=prometheus
Type=simple
Environment="DATA_SOURCE_NAME=postgresql://postgres:CHANGE_ME@localhost:5432/postgres?sslmode=disable"
ExecStart=/usr/local/bin/postgres_exporter

[Install]
WantedBy=multi-user.target
EOF

        systemctl daemon-reload

        log_success "postgres_exporter installed (port 9187)"
        log_warning "Configure PostgreSQL connection in /etc/systemd/system/postgres_exporter.service"
    fi

    # Install redis_exporter
    if [[ "$INSTALL_REDIS_EXPORTER" == true ]]; then
        log_info "Installing redis_exporter..."

        cd /tmp
        wget -q "https://github.com/oliver006/redis_exporter/releases/download/v${REDIS_EXPORTER_VERSION}/redis_exporter-v${REDIS_EXPORTER_VERSION}.linux-amd64.tar.gz"
        tar xzf "redis_exporter-v${REDIS_EXPORTER_VERSION}.linux-amd64.tar.gz"
        cp "redis_exporter-v${REDIS_EXPORTER_VERSION}.linux-amd64/redis_exporter" /usr/local/bin/
        chown prometheus:prometheus /usr/local/bin/redis_exporter
        rm -rf redis_exporter-*

        cat > /etc/systemd/system/redis_exporter.service << EOF
[Unit]
Description=Redis Exporter
After=network.target

[Service]
User=prometheus
Group=prometheus
Type=simple
Environment="REDIS_ADDR=localhost:6379"
Environment="REDIS_PASSWORD=CHANGE_ME"
ExecStart=/usr/local/bin/redis_exporter

[Install]
WantedBy=multi-user.target
EOF

        systemctl daemon-reload

        log_success "redis_exporter installed (port 9121)"
        log_warning "Configure Redis password in /etc/systemd/system/redis_exporter.service"
    fi

    # Install mongodb_exporter
    if [[ "$INSTALL_MONGODB_EXPORTER" == true ]]; then
        log_info "Installing mongodb_exporter..."

        cd /tmp
        wget -q "https://github.com/percona/mongodb_exporter/releases/download/v${MONGODB_EXPORTER_VERSION}/mongodb_exporter-${MONGODB_EXPORTER_VERSION}.linux-amd64.tar.gz"
        tar xzf "mongodb_exporter-${MONGODB_EXPORTER_VERSION}.linux-amd64.tar.gz"
        cp "mongodb_exporter-${MONGODB_EXPORTER_VERSION}.linux-amd64/mongodb_exporter" /usr/local/bin/
        chown prometheus:prometheus /usr/local/bin/mongodb_exporter
        rm -rf mongodb_exporter-*

        cat > /etc/systemd/system/mongodb_exporter.service << EOF
[Unit]
Description=MongoDB Exporter
After=network.target

[Service]
User=prometheus
Group=prometheus
Type=simple
Environment="MONGODB_URI=mongodb://localhost:27017"
ExecStart=/usr/local/bin/mongodb_exporter

[Install]
WantedBy=multi-user.target
EOF

        systemctl daemon-reload

        log_success "mongodb_exporter installed (port 9216)"
        log_warning "Configure MongoDB URI in /etc/systemd/system/mongodb_exporter.service"
    fi

    # Install Prometheus
    if [[ "$INSTALL_PROMETHEUS" == true ]]; then
        log_info "Installing Prometheus..."

        cd /tmp
        wget -q "https://github.com/prometheus/prometheus/releases/download/v${PROM_VERSION}/prometheus-${PROM_VERSION}.linux-amd64.tar.gz"
        tar xzf "prometheus-${PROM_VERSION}.linux-amd64.tar.gz"

    mkdir -p /etc/prometheus /var/lib/prometheus

    cp "prometheus-${PROM_VERSION}.linux-amd64/prometheus" /usr/local/bin/
    cp "prometheus-${PROM_VERSION}.linux-amd64/promtool" /usr/local/bin/
    chown prometheus:prometheus /usr/local/bin/prometheus /usr/local/bin/promtool

    cp -r "prometheus-${PROM_VERSION}.linux-amd64/consoles" /etc/prometheus/
    cp -r "prometheus-${PROM_VERSION}.linux-amd64/console_libraries" /etc/prometheus/
    rm -rf prometheus-*

    # Create Prometheus config with enabled exporters
    cat > /etc/prometheus/prometheus.yml << EOF
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
EOF

    if [[ "$INSTALL_NODE_EXPORTER" == true ]]; then
        cat >> /etc/prometheus/prometheus.yml << EOF

  - job_name: 'node_exporter'
    static_configs:
      - targets: ['localhost:9100']
EOF
    fi

    if [[ "$INSTALL_MYSQLD_EXPORTER" == true ]]; then
        cat >> /etc/prometheus/prometheus.yml << EOF

  - job_name: 'mysqld_exporter'
    static_configs:
      - targets: ['localhost:9104']
EOF
    fi

    if [[ "$INSTALL_POSTGRES_EXPORTER" == true ]]; then
        cat >> /etc/prometheus/prometheus.yml << EOF

  - job_name: 'postgres_exporter'
    static_configs:
      - targets: ['localhost:9187']
EOF
    fi

    if [[ "$INSTALL_REDIS_EXPORTER" == true ]]; then
        cat >> /etc/prometheus/prometheus.yml << EOF

  - job_name: 'redis_exporter'
    static_configs:
      - targets: ['localhost:9121']
EOF
    fi

    if [[ "$INSTALL_MONGODB_EXPORTER" == true ]]; then
        cat >> /etc/prometheus/prometheus.yml << EOF

  - job_name: 'mongodb_exporter'
    static_configs:
      - targets: ['localhost:9216']
EOF
    fi

    chown -R prometheus:prometheus /etc/prometheus /var/lib/prometheus

    cat > /etc/systemd/system/prometheus.service << EOF
[Unit]
Description=Prometheus
Wants=network-online.target
After=network-online.target

[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart=/usr/local/bin/prometheus \\
    --config.file=/etc/prometheus/prometheus.yml \\
    --storage.tsdb.path=/var/lib/prometheus/ \\
    --web.console.templates=/etc/prometheus/consoles \\
    --web.console.libraries=/etc/prometheus/console_libraries

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl start prometheus
    systemctl enable prometheus >> /var/log/ubuntu-setup.log 2>&1

        if systemctl is-active --quiet prometheus; then
            log_success "Prometheus installed (port 9090)"
        fi
    fi

    # Install Grafana
    if [[ "$INSTALL_GRAFANA" == true ]]; then
        log_info "Installing Grafana..."

    apt-get install -y software-properties-common >> /var/log/ubuntu-setup.log 2>&1

    # Use modern apt keyring method (not deprecated apt-key)
    wget -q -O - https://packages.grafana.com/gpg.key | \
        gpg --dearmor -o /usr/share/keyrings/grafana.gpg >> /var/log/ubuntu-setup.log 2>&1

    echo "deb [signed-by=/usr/share/keyrings/grafana.gpg] https://packages.grafana.com/oss/deb stable main" | \
        tee /etc/apt/sources.list.d/grafana.list >> /var/log/ubuntu-setup.log

    apt-get update >> /var/log/ubuntu-setup.log 2>&1
    apt-get install -y grafana >> /var/log/ubuntu-setup.log 2>&1

    GRAFANA_PASSWORD=$(generate_password)

    sed -i "s/;admin_password = .*/admin_password = $GRAFANA_PASSWORD/" /etc/grafana/grafana.ini
    sed -i "s/;admin_user = .*/admin_user = admin/" /etc/grafana/grafana.ini

    systemctl start grafana-server
    systemctl enable grafana-server >> /var/log/ubuntu-setup.log 2>&1

        if systemctl is-active --quiet grafana-server; then
            log_success "Grafana installed (port 3000)"
        fi

        # Add Prometheus data source (only if Prometheus is also installed)
        if [[ "$INSTALL_PROMETHEUS" == true ]]; then
            sleep 5

            log_info "Configuring Grafana data source..."

            cat > /tmp/grafana-datasource.json << EOF
{
  "name": "Prometheus",
  "type": "prometheus",
  "url": "http://localhost:9090",
  "access": "proxy",
  "isDefault": true
}
EOF

            curl -s -X POST \
                -H "Content-Type: application/json" \
                -d @/tmp/grafana-datasource.json \
                http://admin:${GRAFANA_PASSWORD}@localhost:3000/api/datasources \
                >> /var/log/ubuntu-setup.log 2>&1

            rm /tmp/grafana-datasource.json
        fi
    fi

    # Display summary
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo -e "${BOLD}Monitoring Installation Summary:${NC}"
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo ""
    echo -e "${BOLD}Installed Components:${NC}"

    [[ "$INSTALL_PROMETHEUS" == true ]] && echo -e "  ${GREEN}✓${NC} Prometheus v${PROM_VERSION} (http://localhost:9090)"
    [[ "$INSTALL_GRAFANA" == true ]] && echo -e "  ${GREEN}✓${NC} Grafana (http://localhost:3000)"
    [[ "$INSTALL_NODE_EXPORTER" == true ]] && echo -e "  ${GREEN}✓${NC} node_exporter v${NODE_EXPORTER_VERSION} (port 9100)"
    [[ "$INSTALL_MYSQLD_EXPORTER" == true ]] && echo -e "  ${GREEN}✓${NC} mysqld_exporter v${MYSQLD_EXPORTER_VERSION} (port 9104)"
    [[ "$INSTALL_POSTGRES_EXPORTER" == true ]] && echo -e "  ${GREEN}✓${NC} postgres_exporter v${POSTGRES_EXPORTER_VERSION} (port 9187)"
    [[ "$INSTALL_REDIS_EXPORTER" == true ]] && echo -e "  ${GREEN}✓${NC} redis_exporter v${REDIS_EXPORTER_VERSION} (port 9121)"
    [[ "$INSTALL_MONGODB_EXPORTER" == true ]] && echo -e "  ${GREEN}✓${NC} mongodb_exporter v${MONGODB_EXPORTER_VERSION} (port 9216)"

    echo ""

    # Show Grafana credentials only if Grafana was installed
    if [[ "$INSTALL_GRAFANA" == true ]]; then
        echo -e "${YELLOW}${BOLD}IMPORTANT - Save Grafana Credentials:${NC}"
        echo -e "${BOLD}Username:${NC} admin"
        echo -e "${BOLD}Password:${NC} ${RED}$GRAFANA_PASSWORD${NC}"
        echo ""
    fi

    # Configuration warnings
    if [[ "$INSTALL_MYSQLD_EXPORTER" == true ]] || [[ "$INSTALL_POSTGRES_EXPORTER" == true ]] || [[ "$INSTALL_REDIS_EXPORTER" == true ]] || [[ "$INSTALL_MONGODB_EXPORTER" == true ]]; then
        echo -e "${YELLOW}${BOLD}Configuration Required:${NC}"

        [[ "$INSTALL_MYSQLD_EXPORTER" == true ]] && echo -e "  ${YELLOW}⚠${NC} mysqld_exporter: Edit /etc/mysqld_exporter/.my.cnf"
        [[ "$INSTALL_POSTGRES_EXPORTER" == true ]] && echo -e "  ${YELLOW}⚠${NC} postgres_exporter: Edit /etc/systemd/system/postgres_exporter.service"
        [[ "$INSTALL_REDIS_EXPORTER" == true ]] && echo -e "  ${YELLOW}⚠${NC} redis_exporter: Edit /etc/systemd/system/redis_exporter.service"
        [[ "$INSTALL_MONGODB_EXPORTER" == true ]] && echo -e "  ${YELLOW}⚠${NC} mongodb_exporter: Edit /etc/systemd/system/mongodb_exporter.service"

        echo ""
        echo -e "${DIM}After configuration, restart services:${NC}"
        [[ "$INSTALL_MYSQLD_EXPORTER" == true ]] && echo -e "  ${CYAN}sudo systemctl restart mysqld_exporter${NC}"
        [[ "$INSTALL_POSTGRES_EXPORTER" == true ]] && echo -e "  ${CYAN}sudo systemctl restart postgres_exporter${NC}"
        [[ "$INSTALL_REDIS_EXPORTER" == true ]] && echo -e "  ${CYAN}sudo systemctl restart redis_exporter${NC}"
        [[ "$INSTALL_MONGODB_EXPORTER" == true ]] && echo -e "  ${CYAN}sudo systemctl restart mongodb_exporter${NC}"
        echo ""
    fi

    # Show dashboard recommendations only if Grafana was installed
    if [[ "$INSTALL_GRAFANA" == true ]]; then
        echo -e "${BOLD}Recommended Grafana Dashboards:${NC}"
        [[ "$INSTALL_NODE_EXPORTER" == true ]] && echo -e "  - Node Exporter Full: Dashboard ID ${CYAN}1860${NC}"
        [[ "$INSTALL_MYSQLD_EXPORTER" == true ]] && echo -e "  - MySQL Overview: Dashboard ID ${CYAN}7362${NC}"
        [[ "$INSTALL_POSTGRES_EXPORTER" == true ]] && echo -e "  - PostgreSQL Database: Dashboard ID ${CYAN}9628${NC}"
        [[ "$INSTALL_REDIS_EXPORTER" == true ]] && echo -e "  - Redis Dashboard: Dashboard ID ${CYAN}11835${NC}"
        [[ "$INSTALL_MONGODB_EXPORTER" == true ]] && echo -e "  - MongoDB Overview: Dashboard ID ${CYAN}2583${NC}"
        [[ "$INSTALL_PROMETHEUS" == true ]] && echo -e "  - Prometheus Stats: Dashboard ID ${CYAN}3662${NC}"
    fi

    echo ""
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo ""

    # Save to summary
    echo "" >> /root/ubuntu-setup-summary.txt
    echo "Monitoring Components:" >> /root/ubuntu-setup-summary.txt

    if [[ "$INSTALL_GRAFANA" == true ]]; then
        cat >> /root/ubuntu-setup-summary.txt << EOF
  Grafana:
    URL: http://localhost:3000
    Username: admin
    Password: $GRAFANA_PASSWORD

EOF
    fi

    if [[ "$INSTALL_PROMETHEUS" == true ]]; then
        cat >> /root/ubuntu-setup-summary.txt << EOF
  Prometheus:
    URL: http://localhost:9090
    Config: /etc/prometheus/prometheus.yml

EOF
    fi

    [[ "$INSTALL_NODE_EXPORTER" == true ]] && echo "  node_exporter: http://localhost:9100/metrics" >> /root/ubuntu-setup-summary.txt
    [[ "$INSTALL_MYSQLD_EXPORTER" == true ]] && echo "  mysqld_exporter: http://localhost:9104/metrics" >> /root/ubuntu-setup-summary.txt
    [[ "$INSTALL_POSTGRES_EXPORTER" == true ]] && echo "  postgres_exporter: http://localhost:9187/metrics" >> /root/ubuntu-setup-summary.txt
    [[ "$INSTALL_REDIS_EXPORTER" == true ]] && echo "  redis_exporter: http://localhost:9121/metrics" >> /root/ubuntu-setup-summary.txt
    [[ "$INSTALL_MONGODB_EXPORTER" == true ]] && echo "  mongodb_exporter: http://localhost:9216/metrics" >> /root/ubuntu-setup-summary.txt
}

cleanup_monitoring() {
    log_info "Removing Monitoring Stack..."

    systemctl stop grafana-server prometheus node_exporter mysqld_exporter postgres_exporter redis_exporter mongodb_exporter 2>/dev/null || true
    systemctl disable grafana-server prometheus node_exporter mysqld_exporter postgres_exporter redis_exporter mongodb_exporter 2>/dev/null || true

    if [[ "$1" == "--purge" ]]; then
        apt-get remove --purge -y grafana >> /var/log/ubuntu-setup.log 2>&1
        rm -rf /etc/grafana /var/lib/grafana /var/log/grafana
        rm -rf /etc/prometheus /var/lib/prometheus
        rm -rf /etc/mysqld_exporter
        rm -f /usr/local/bin/{prometheus,promtool,node_exporter,mysqld_exporter,postgres_exporter,redis_exporter,mongodb_exporter}
        rm -f /etc/systemd/system/{prometheus,node_exporter,mysqld_exporter,postgres_exporter,redis_exporter,mongodb_exporter}.service
        userdel prometheus 2>/dev/null || true
        systemctl daemon-reload
        log_success "Monitoring stack removed (including data)"
    else
        apt-get remove -y grafana >> /var/log/ubuntu-setup.log 2>&1
        rm -f /usr/local/bin/{prometheus,promtool,node_exporter,mysqld_exporter,postgres_exporter,redis_exporter,mongodb_exporter}
        rm -f /etc/systemd/system/{prometheus,node_exporter,mysqld_exporter,postgres_exporter,redis_exporter,mongodb_exporter}.service
        systemctl daemon-reload
        log_success "Monitoring stack removed (data preserved)"
    fi
}
