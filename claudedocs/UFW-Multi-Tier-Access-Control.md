# UFW Multi-Tier Access Control

## Overview

Enhanced UFW firewall configuration that supports granular IP-based access control with two tiers:

1. **Trusted IPs** - Full access to all ports (VPN-like access)
2. **Restricted IPs** - Access to specific ports/services only

Default policy: **DENY all incoming** traffic, with explicit whitelist rules.

## Features

- Multi-tier IP whitelisting
- Per-IP access level configuration
- Service-specific port restrictions
- Auto-detection of current SSH IP
- CIDR network range support
- Safety warnings and lockout prevention
- Interactive configuration with validation

## Usage

### Access the Feature

1. Run the installer:
   ```bash
   sudo ./install.sh
   ```

2. Select **Security** component (option 8)

3. When UFW is already installed, choose:
   ```
   2) Setup IP whitelist (restrict access to specific IPs)
   ```

### Configuration Flow

#### Step 1: Safety Warning
The system will display warnings about potential lockout risks:
- Keep SSH session open
- Test before closing
- Have console/VNC backup access

#### Step 2: Current IP Detection
If connected via SSH, the system will detect and offer to auto-add your current IP.

**Choose access level for current IP:**
- **Option 1 (Trusted)**: Full access to all ports
- **Option 2 (Restricted)**: Specify ports (e.g., `22,80,443`)

#### Step 3: Add Additional IPs
For each IP/network you want to whitelist:

1. Enter IP or CIDR range:
   - Single IP: `192.168.1.100`
   - Network: `192.168.1.0/24`

2. Add a comment/label (optional)

3. Choose access level:
   - **Trusted (1)**: Full access
   - **Restricted (2)**: Specific ports only

4. If restricted, specify ports:
   - Comma-separated: `22,80,443`
   - With protocol: `22/tcp,1194/udp`
   - Common services shown as reference

#### Step 4: Review Summary
Before applying, review:
- All trusted IPs (full access)
- All restricted IPs with their port lists
- Final warning

#### Step 5: Apply Configuration
Confirm to apply UFW rules:
- Trusted IPs → `ufw allow from <IP>`
- Restricted IPs → `ufw allow from <IP> to any port <PORT> proto <PROTO>`
- Set default deny incoming
- Reload UFW

## Configuration Examples

### Example 1: VPN + Web Server Access

**Scenario:**
- VPN users need full access
- Public needs HTTP/HTTPS only

**Configuration:**
```
Trusted IPs:
  10.8.0.0/24 (VPN Network) → Full access

Restricted IPs:
  0.0.0.0/0 (Internet) → ports: 80,443
```

**UFW Rules:**
```bash
ufw allow from 10.8.0.0/24 comment "Trusted: VPN Network"
ufw allow from 0.0.0.0/0 to any port 80 proto tcp comment "Restricted: Internet"
ufw allow from 0.0.0.0/0 to any port 443 proto tcp comment "Restricted: Internet"
ufw default deny incoming
```

### Example 2: Office + Remote Developer

**Scenario:**
- Office network needs full access
- Remote developer needs SSH and MongoDB only

**Configuration:**
```
Trusted IPs:
  192.168.1.0/24 (Office Network) → Full access

Restricted IPs:
  203.0.113.50 (Remote Dev) → ports: 22,27017
```

**UFW Rules:**
```bash
ufw allow from 192.168.1.0/24 comment "Trusted: Office Network"
ufw allow from 203.0.113.50 to any port 22 proto tcp comment "Restricted: Remote Dev"
ufw allow from 203.0.113.50 to any port 27017 proto tcp comment "Restricted: Remote Dev"
ufw default deny incoming
```

### Example 3: Multiple Service Teams

**Scenario:**
- DevOps team needs full access
- Backend team needs database ports only
- Frontend team needs web services only

**Configuration:**
```
Trusted IPs:
  10.0.1.0/24 (DevOps Team) → Full access

Restricted IPs:
  10.0.2.0/24 (Backend Team) → ports: 22,27017,5432,6379
  10.0.3.0/24 (Frontend Team) → ports: 22,80,443,3000
```

## UFW Command Reference

### View Rules
```bash
sudo ufw status numbered
```

### Add Trusted IP
```bash
sudo ufw allow from 192.168.1.100 comment "Trusted: Description"
```

### Add Restricted IP (specific port)
```bash
sudo ufw allow from 192.168.1.100 to any port 22 proto tcp comment "Restricted: SSH Only"
```

### Delete Rule
```bash
sudo ufw delete <rule_number>
```

### Disable Firewall (emergency)
```bash
sudo ufw disable
```

### Reset All Rules
```bash
sudo ufw reset
```

## Common Port Numbers

| Service | Port | Protocol |
|---------|------|----------|
| SSH | 22 | tcp |
| HTTP | 80 | tcp |
| HTTPS | 443 | tcp |
| MongoDB | 27017 | tcp |
| PostgreSQL | 5432 | tcp |
| Redis | 6379 | tcp |
| MySQL | 3306 | tcp |
| OpenVPN | 1194 | udp |
| Grafana | 3000 | tcp |
| Prometheus | 9090 | tcp |

## Safety Tips

1. **Always keep current SSH session open** while configuring
2. **Test new SSH connection** before closing current one
3. **Have console/VNC access** as backup
4. **Start with current IP as trusted** for safety
5. **Use CIDR ranges** for network-wide access
6. **Document your rules** with clear comments

## Troubleshooting

### Locked Out of Server

If you lose SSH access:

1. Access via console/VNC
2. Disable UFW:
   ```bash
   sudo ufw disable
   ```
3. Fix rules or reset:
   ```bash
   sudo ufw reset
   ```
4. Reconfigure properly

### Check Which IP Can Access

View current rules:
```bash
sudo ufw status numbered
```

### Test Connection Before Closing

From another terminal:
```bash
ssh user@server-ip
```

If successful, your IP is whitelisted correctly.

## Implementation Details

### File Location
`modules/security.sh` - Function `setup_ufw_whitelist()`

### Entry Format
Internal format: `IP:TYPE:COMMENT:PORTS`
- `IP`: IP address or CIDR range
- `TYPE`: `trusted` or `restricted`
- `COMMENT`: User description
- `PORTS`: Comma-separated port list (restricted only)

### UFW Rule Generation
- **Trusted**: `ufw allow from <IP> comment "Trusted: <COMMENT>"`
- **Restricted**: `ufw allow from <IP> to any port <PORT> proto <PROTO> comment "Restricted: <COMMENT>"`

### Default Policy
Always set to `deny incoming`, `allow outgoing` for security.

## Version History

- **v1.1.0** - Added multi-tier access control (trusted/restricted)
- **v1.0.0** - Initial UFW whitelist (full access only)
