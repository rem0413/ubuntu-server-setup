#!/bin/bash

################################################################################
# OpenVPN Management Module
# Description: Setup OpenVPN server and manage clients
################################################################################

install_openvpn() {
    log_step "OpenVPN Management..."

    # Check if already installed
    local server_exists=false
    if command_exists openvpn && [[ -d /etc/openvpn/server ]]; then
        server_exists=true
    fi

    # Interactive menu
    echo ""
    echo -e "${BOLD}OpenVPN Management:${NC}"
    echo ""

    if [[ "$server_exists" == false ]]; then
        echo "  1) Setup OpenVPN Server (first time)"
        echo "  2) Cancel"
    else
        echo "  ${GREEN}OpenVPN Server: Installed${NC}"
        echo ""
        echo "  1) Add VPN Client"
        echo "  2) List Clients"
        echo "  3) Revoke Client"
        echo "  4) Reinstall Server"
        echo "  5) Cancel"
    fi

    echo ""
    read_prompt "Select option: " openvpn_choice ""

    if [[ "$server_exists" == false ]]; then
        case $openvpn_choice in
            1) setup_openvpn_server ;;
            *)
                log_info "OpenVPN setup cancelled"
                return 0
                ;;
        esac
    else
        case $openvpn_choice in
            1) add_openvpn_client ;;
            2) list_openvpn_clients ;;
            3) revoke_openvpn_client ;;
            4)
                if ask_yes_no "Reinstall OpenVPN server? This will remove all clients" "n"; then
                    cleanup_openvpn "--purge"
                    setup_openvpn_server
                fi
                ;;
            *)
                log_info "OpenVPN management cancelled"
                return 0
                ;;
        esac
    fi
}

setup_openvpn_server() {
    log_info "Setting up OpenVPN Server..."

    # Configuration variables
    local openvpn_dir="/etc/openvpn"
    local easy_rsa_dir="$openvpn_dir/easy-rsa"
    local server_dir="$openvpn_dir/server"
    local client_dir="$openvpn_dir/client-configs"
    local pki_dir="$easy_rsa_dir/pki"

    # Get server IP
    log_info "Detecting server IP..."
    local server_ip=$(ip -4 addr | grep inet | grep -vE '127(\.[0-9]{1,3}){3}' | cut -d '/' -f 1 | grep -oE '[0-9]{1,3}(\.[0-9]{1,3}){3}' | head -1)

    if [[ -z "$server_ip" ]]; then
        read_prompt "Server public IP: " server_ip ""
        if [[ -z "$server_ip" ]]; then
            log_error "Server IP is required"
            return 1
        fi
    fi

    log_success "Server IP: $server_ip"

    # Get configuration details
    read_prompt "OpenVPN port [1194]: " vpn_port "1194"

    read_prompt "Protocol (udp/tcp) [udp]: " vpn_protocol "udp"

    echo ""
    echo "DNS server:"
    echo "  1) Current system DNS"
    echo "  2) Google DNS (8.8.8.8)"
    echo "  3) Cloudflare DNS (1.1.1.1)"
    read_prompt "Choice [1]: " dns_choice "1"

    local dns1 dns2
    case $dns_choice in
        2)
            dns1="8.8.8.8"
            dns2="8.8.4.4"
            ;;
        3)
            dns1="1.1.1.1"
            dns2="1.0.0.1"
            ;;
        *)
            dns1=$(grep nameserver /etc/resolv.conf | head -1 | awk '{print $2}')
            dns2=$(grep nameserver /etc/resolv.conf | sed -n '2p' | awk '{print $2}')
            ;;
    esac

    # Install packages
    log_info "Installing OpenVPN and Easy-RSA..."
    apt-get update >> /var/log/ubuntu-setup.log 2>&1
    apt-get install -y openvpn easy-rsa >> /var/log/ubuntu-setup.log 2>&1

    # Setup Easy-RSA
    log_info "Setting up PKI..."
    mkdir -p "$easy_rsa_dir"
    cp -r /usr/share/easy-rsa/* "$easy_rsa_dir/"

    cd "$easy_rsa_dir"

    # Create PKI
    ./easyrsa init-pki >> /var/log/ubuntu-setup.log 2>&1

    # Build CA
    log_info "Creating Certificate Authority..."
    EASYRSA_BATCH=1 ./easyrsa build-ca nopass >> /var/log/ubuntu-setup.log 2>&1
    log_success "CA created"

    # Generate server certificate
    log_info "Generating server certificate..."
    EASYRSA_BATCH=1 ./easyrsa build-server-full server nopass >> /var/log/ubuntu-setup.log 2>&1
    log_success "Server certificate created"

    # Generate DH parameters
    log_info "Generating DH parameters (this may take several minutes)..."
    ./easyrsa gen-dh >> /var/log/ubuntu-setup.log 2>&1
    log_success "DH parameters generated"

    # Generate TLS auth key
    openvpn --genkey secret "$pki_dir/ta.key"
    log_success "TLS auth key created"

    # Copy files to server directory
    mkdir -p "$server_dir"
    cp "$pki_dir/ca.crt" "$server_dir/"
    cp "$pki_dir/issued/server.crt" "$server_dir/"
    cp "$pki_dir/private/server.key" "$server_dir/"
    cp "$pki_dir/dh.pem" "$server_dir/"
    cp "$pki_dir/ta.key" "$server_dir/"

    # Create server config
    cat > "$server_dir/server.conf" << EOF
port $vpn_port
proto $vpn_protocol
dev tun

ca ca.crt
cert server.crt
key server.key
dh dh.pem

tls-auth ta.key 0
cipher AES-256-GCM
auth SHA256

server 10.8.0.0 255.255.255.0
ifconfig-pool-persist /var/log/openvpn/ipp.txt

push "redirect-gateway def1 bypass-dhcp"
push "dhcp-option DNS $dns1"
EOF

    if [[ -n "$dns2" ]]; then
        echo "push \"dhcp-option DNS $dns2\"" >> "$server_dir/server.conf"
    fi

    cat >> "$server_dir/server.conf" << EOF

keepalive 10 120

compress lz4-v2
push "compress lz4-v2"

user nobody
group nogroup

persist-key
persist-tun

status /var/log/openvpn/openvpn-status.log
log-append /var/log/openvpn/openvpn.log

verb 3
mute 20

explicit-exit-notify 1
EOF

    # Create log directory
    mkdir -p /var/log/openvpn

    # Enable IP forwarding
    log_info "Enabling IP forwarding..."
    echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
    sysctl -p >> /var/log/ubuntu-setup.log 2>&1

    # Configure firewall
    if command -v ufw &>/dev/null; then
        log_info "Configuring firewall for OpenVPN..."

        # Get default network interface
        local iface=$(ip route | grep default | awk '{print $5}' | head -1)

        # Add UFW before rules for NAT
        cat > /etc/ufw/before.rules.openvpn << EOF
# NAT table rules for OpenVPN
*nat
:POSTROUTING ACCEPT [0:0]
-A POSTROUTING -s 10.8.0.0/24 -o $iface -j MASQUERADE
COMMIT
EOF

        # Backup and update before.rules
        if [[ ! -f /etc/ufw/before.rules.backup ]]; then
            cp /etc/ufw/before.rules /etc/ufw/before.rules.backup
        fi

        # Insert NAT rules at the beginning
        cat /etc/ufw/before.rules.openvpn /etc/ufw/before.rules.backup > /etc/ufw/before.rules

        # Enable routing/forwarding in UFW
        log_info "Enabling UFW routing..."
        ufw default allow routed >> /var/log/ubuntu-setup.log 2>&1
        log_success "UFW routing enabled"

        # Allow OpenVPN port
        log_info "Opening OpenVPN port $vpn_port/$vpn_protocol..."
        ufw allow "$vpn_port/$vpn_protocol" comment 'OpenVPN' >> /var/log/ubuntu-setup.log 2>&1

        # Allow VPN clients full access (trusted network)
        log_info "Allowing VPN subnet 10.8.0.0/24 (trusted)..."
        ufw allow from 10.8.0.0/24 comment 'Trusted: VPN Clients' >> /var/log/ubuntu-setup.log 2>&1
        log_success "VPN clients can route traffic through server"

        # Reload firewall
        ufw --force reload >> /var/log/ubuntu-setup.log 2>&1

        log_success "UFW configured for OpenVPN routing"
    fi

    # Enable and start OpenVPN
    log_info "Starting OpenVPN service..."
    systemctl enable openvpn-server@server >> /var/log/ubuntu-setup.log 2>&1
    systemctl start openvpn-server@server >> /var/log/ubuntu-setup.log 2>&1

    if systemctl is-active --quiet openvpn-server@server; then
        log_success "OpenVPN server started"
    else
        log_error "Failed to start OpenVPN server"
        log_info "Check logs: journalctl -u openvpn-server@server"
        return 1
    fi

    # Create client config directory
    mkdir -p "$client_dir/keys" "$client_dir/files"
    chmod 700 "$client_dir"

    # Create base client config
    cat > "$client_dir/base.conf" << EOF
client
dev tun
proto $vpn_protocol

remote $server_ip $vpn_port

resolv-retry infinite
nobind

persist-key
persist-tun

remote-cert-tls server
cipher AES-256-GCM
auth SHA256

compress lz4-v2

verb 3
mute 20
EOF

    # Display summary
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo -e "${BOLD}OpenVPN Server Installation Summary:${NC}"
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo -e "${BOLD}Server IP:${NC} $server_ip"
    echo -e "${BOLD}Port:${NC} $vpn_port"
    echo -e "${BOLD}Protocol:${NC} $vpn_protocol"
    echo -e "${BOLD}VPN Network:${NC} 10.8.0.0/24"
    echo -e "${BOLD}DNS:${NC} $dns1 $dns2"
    echo ""
    echo -e "${BOLD}Firewall Configuration:${NC}"
    echo -e "  ${GREEN}✓${NC} UFW routing enabled (default allow routed)"
    echo -e "  ${GREEN}✓${NC} OpenVPN port $vpn_port/$vpn_protocol allowed"
    echo -e "  ${GREEN}✓${NC} VPN subnet 10.8.0.0/24 trusted (full access)"
    echo -e "  ${GREEN}✓${NC} NAT/Masquerade configured for Internet routing"
    echo ""
    echo -e "${BOLD}Next Steps:${NC}"
    echo -e "  1. Add VPN clients: Re-run installer and select OpenVPN option"
    echo -e "  2. Download .ovpn files from: ${CYAN}$client_dir/files/${NC}"
    echo -e "  3. Import .ovpn file into OpenVPN client app"
    echo ""
    echo -e "${BOLD}Useful Commands:${NC}"
    echo -e "  Status: ${CYAN}sudo systemctl status openvpn-server@server${NC}"
    echo -e "  Logs: ${CYAN}sudo journalctl -u openvpn-server@server -f${NC}"
    echo -e "  Connected clients: ${CYAN}sudo cat /var/log/openvpn/openvpn-status.log${NC}"
    echo -e "  UFW status: ${CYAN}sudo ufw status verbose${NC}"
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo ""

    # Save to summary
    cat >> /root/ubuntu-setup-summary.txt << EOF

OpenVPN Server:
  Server IP: $server_ip
  Port: $vpn_port
  Protocol: $vpn_protocol
  VPN Network: 10.8.0.0/24
  Client configs: $client_dir/files/

  Firewall:
    - UFW routing: enabled (default allow routed)
    - OpenVPN port: $vpn_port/$vpn_protocol allowed
    - VPN subnet: 10.8.0.0/24 trusted (full access)
    - NAT/Masquerade: configured

EOF

    log_success "OpenVPN server installation complete"
}

add_openvpn_client() {
    log_info "Adding OpenVPN client..."

    # Check if OpenVPN is installed
    if [[ ! -d /etc/openvpn/easy-rsa ]]; then
        log_error "OpenVPN server not found"
        log_info "Install OpenVPN server first"
        return 1
    fi

    read_prompt "Client name (e.g., laptop, phone, john-laptop): " client_name ""

    if [[ -z "$client_name" ]]; then
        log_error "Client name is required"
        return 1
    fi

    # Validate client name
    if [[ ! "$client_name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        log_error "Invalid client name. Use only letters, numbers, hyphens, and underscores"
        return 1
    fi

    local easy_rsa_dir="/etc/openvpn/easy-rsa"
    local client_dir="/etc/openvpn/client-configs"
    local output_dir="$client_dir/files"

    # Check if client already exists
    if [[ -f "$easy_rsa_dir/pki/issued/$client_name.crt" ]]; then
        log_warning "Client '$client_name' already exists"
        if ask_yes_no "Regenerate?" "n"; then
            cd "$easy_rsa_dir"
            EASYRSA_BATCH=1 ./easyrsa revoke "$client_name" >> /var/log/ubuntu-setup.log 2>&1
            EASYRSA_BATCH=1 ./easyrsa gen-crl >> /var/log/ubuntu-setup.log 2>&1
            log_info "Old certificate revoked"
        else
            return 0
        fi
    fi

    cd "$easy_rsa_dir"

    # Generate client certificate
    log_info "Generating certificate for $client_name..."
    EASYRSA_BATCH=1 ./easyrsa build-client-full "$client_name" nopass >> /var/log/ubuntu-setup.log 2>&1

    if [[ $? -ne 0 ]]; then
        log_error "Failed to generate certificate"
        return 1
    fi

    log_success "Certificate generated"

    # Create .ovpn file
    log_info "Creating .ovpn config file..."

    local ca_cert=$(cat "$easy_rsa_dir/pki/ca.crt")
    local client_cert=$(openssl x509 -in "$easy_rsa_dir/pki/issued/$client_name.crt")
    local client_key=$(cat "$easy_rsa_dir/pki/private/$client_name.key")
    local ta_key=$(cat "$easy_rsa_dir/pki/ta.key")

    cat "$client_dir/base.conf" > "$output_dir/$client_name.ovpn"

    cat >> "$output_dir/$client_name.ovpn" << EOF

<ca>
$ca_cert
</ca>

<cert>
$client_cert
</cert>

<key>
$client_key
</key>

<tls-auth>
$ta_key
</tls-auth>

key-direction 1
EOF

    chmod 600 "$output_dir/$client_name.ovpn"

    log_success "Client configuration created: $output_dir/$client_name.ovpn"

    echo ""
    echo -e "${GREEN}Client '$client_name' added successfully!${NC}"
    echo ""
    echo -e "${BOLD}Config file:${NC} $output_dir/$client_name.ovpn"
    echo ""
    echo -e "${BOLD}Next steps:${NC}"
    echo -e "  1. Download the .ovpn file to client device"
    echo -e "  2. Import into OpenVPN client (OpenVPN Connect, Tunnelblick, etc.)"
    echo -e "  3. Connect to VPN"
    echo ""

    return 0
}

list_openvpn_clients() {
    log_info "Listing OpenVPN clients..."

    local easy_rsa_dir="/etc/openvpn/easy-rsa"

    if [[ ! -d "$easy_rsa_dir/pki/issued" ]]; then
        log_warning "No clients found"
        return 0
    fi

    echo ""
    echo -e "${BOLD}Active VPN Clients:${NC}"
    echo ""

    local count=0
    for cert in "$easy_rsa_dir/pki/issued"/*.crt; do
        if [[ -f "$cert" ]]; then
            local client=$(basename "$cert" .crt)
            if [[ "$client" != "server" ]]; then
                local expiry=$(openssl x509 -enddate -noout -in "$cert" | cut -d= -f2)
                echo -e "  ${GREEN}✓${NC} $client (expires: $expiry)"
                ((count++))
            fi
        fi
    done

    if [[ $count -eq 0 ]]; then
        echo -e "  ${DIM}No clients configured yet${NC}"
    fi

    echo ""
    echo -e "${BOLD}Total clients:${NC} $count"
    echo ""
}

revoke_openvpn_client() {
    log_info "Revoking OpenVPN client..."

    local easy_rsa_dir="/etc/openvpn/easy-rsa"

    read_prompt "Client name to revoke: " client_name ""

    if [[ -z "$client_name" ]]; then
        log_error "Client name is required"
        return 1
    fi

    if [[ ! -f "$easy_rsa_dir/pki/issued/$client_name.crt" ]]; then
        log_error "Client '$client_name' not found"
        return 1
    fi

    if ask_yes_no "Revoke client '$client_name'?" "n"; then
        cd "$easy_rsa_dir"
        EASYRSA_BATCH=1 ./easyrsa revoke "$client_name" >> /var/log/ubuntu-setup.log 2>&1
        EASYRSA_BATCH=1 ./easyrsa gen-crl >> /var/log/ubuntu-setup.log 2>&1

        # Copy CRL to server directory
        cp "$easy_rsa_dir/pki/crl.pem" /etc/openvpn/server/

        log_success "Client '$client_name' revoked"
        log_info "Restarting OpenVPN to apply changes..."
        systemctl restart openvpn-server@server
    fi
}

cleanup_openvpn() {
    log_info "Removing OpenVPN..."

    systemctl stop openvpn-server@server 2>/dev/null || true
    systemctl disable openvpn-server@server 2>/dev/null || true

    if [[ "$1" == "--purge" ]]; then
        apt-get remove --purge -y openvpn easy-rsa >> /var/log/ubuntu-setup.log 2>&1
        rm -rf /etc/openvpn /var/log/openvpn

        # Restore UFW rules
        if [[ -f /etc/ufw/before.rules.backup ]]; then
            mv /etc/ufw/before.rules.backup /etc/ufw/before.rules
            ufw --force reload >> /var/log/ubuntu-setup.log 2>&1
        fi

        log_success "OpenVPN removed (including all clients)"
    else
        apt-get remove -y openvpn easy-rsa >> /var/log/ubuntu-setup.log 2>&1
        log_success "OpenVPN removed (data preserved)"
    fi
}
