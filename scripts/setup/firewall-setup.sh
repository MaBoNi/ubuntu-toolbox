#!/bin/bash

# 🧱 Firewall Setup Brick
# Configures UFW (Uncomplicated Firewall) with sensible defaults

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   🧱 Firewall Setup Brick         ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════╝${NC}"
echo ""

# Ensure script is running with sudo
if [ "$EUID" -ne 0 ]; then
  echo -e "${YELLOW}⚠️  This script needs to run with sudo. Re-running...${NC}"
  exec sudo "$0" "$@"
fi

echo -e "${CYAN}This script will configure UFW (Uncomplicated Firewall):${NC}"
echo "  • Set default policies (deny incoming, allow outgoing)"
echo "  • Allow SSH (CRITICAL - prevents lockout)"
echo "  • Configure rules for common services"
echo "  • Enable firewall"
echo ""
echo -e "${RED}⚠️  IMPORTANT: Make sure you're not connected via a non-standard SSH port!${NC}"
echo ""

read -p "Continue with firewall setup? (Y/n): " confirm
confirm=${confirm:-Y}

if [[ ! $confirm =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Setup cancelled.${NC}"
    exit 0
fi

# Install UFW if not present
if ! command -v ufw &> /dev/null; then
    echo ""
    echo -e "${BLUE}📦 Installing UFW...${NC}"
    apt update
    apt install -y ufw
    echo -e "${GREEN}✅ UFW installed${NC}"
fi

# Check if UFW is already active
UFW_STATUS=$(ufw status | head -n 1)
if [[ "$UFW_STATUS" == *"active"* ]]; then
    echo ""
    echo -e "${YELLOW}⚠️  UFW is already active${NC}"
    ufw status numbered
    echo ""
    read -p "Do you want to reconfigure the firewall? (y/N): " reconfig
    
    if [[ ! $reconfig =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Keeping existing configuration.${NC}"
        exit 0
    fi
    
    echo -e "${YELLOW}Resetting UFW to defaults...${NC}"
    ufw --force reset
fi

echo ""
echo -e "${BLUE}🔧 Configuring UFW...${NC}"

# Set default policies
echo -e "${CYAN}Setting default policies...${NC}"
ufw default deny incoming
ufw default allow outgoing
ufw default deny routed
echo -e "${GREEN}✅ Default policies set${NC}"

# Detect SSH port
SSH_PORT=$(grep "^Port " /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}')
SSH_PORT=${SSH_PORT:-22}

echo ""
echo -e "${YELLOW}🔑 Configuring SSH access...${NC}"
echo -e "${CYAN}Detected SSH port:${NC} ${GREEN}$SSH_PORT${NC}"
read -p "Is this correct? (Y/n): " ssh_correct
ssh_correct=${ssh_correct:-Y}

if [[ ! $ssh_correct =~ ^[Yy]$ ]]; then
    read -p "Enter SSH port: " SSH_PORT
fi

# Allow SSH (CRITICAL!)
echo -e "${BLUE}Allowing SSH on port $SSH_PORT...${NC}"
ufw allow "$SSH_PORT"/tcp comment 'SSH'
echo -e "${GREEN}✅ SSH allowed${NC}"

# Ask about rate limiting SSH
echo ""
read -p "Enable SSH rate limiting (prevents brute-force)? (Y/n): " rate_limit
rate_limit=${rate_limit:-Y}

if [[ $rate_limit =~ ^[Yy]$ ]]; then
    ufw limit "$SSH_PORT"/tcp
    echo -e "${GREEN}✅ SSH rate limiting enabled${NC}"
fi

# Common services
echo ""
echo -e "${CYAN}═══════════════════════════════════${NC}"
echo -e "${CYAN}    Common Services Configuration  ${NC}"
echo -e "${CYAN}═══════════════════════════════════${NC}"
echo ""

# HTTP/HTTPS
read -p "Allow HTTP (port 80)? (y/N): " allow_http
if [[ $allow_http =~ ^[Yy]$ ]]; then
    ufw allow 80/tcp comment 'HTTP'
    echo -e "${GREEN}✅ HTTP allowed${NC}"
fi

read -p "Allow HTTPS (port 443)? (y/N): " allow_https
if [[ $allow_https =~ ^[Yy]$ ]]; then
    ufw allow 443/tcp comment 'HTTPS'
    echo -e "${GREEN}✅ HTTPS allowed${NC}"
fi

# Database ports
read -p "Allow MySQL/MariaDB (port 3306)? (y/N): " allow_mysql
if [[ $allow_mysql =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}⚠️  Warning: Only allow if you need remote database access${NC}"
    read -p "Allow from specific IP only? (y/N): " specific_mysql
    
    if [[ $specific_mysql =~ ^[Yy]$ ]]; then
        read -p "Enter IP address or subnet (e.g., 192.168.1.0/24): " mysql_ip
        ufw allow from "$mysql_ip" to any port 3306 proto tcp comment 'MySQL/MariaDB'
        echo -e "${GREEN}✅ MySQL/MariaDB allowed from $mysql_ip${NC}"
    else
        ufw allow 3306/tcp comment 'MySQL/MariaDB'
        echo -e "${GREEN}✅ MySQL/MariaDB allowed${NC}"
    fi
fi

read -p "Allow PostgreSQL (port 5432)? (y/N): " allow_postgres
if [[ $allow_postgres =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}⚠️  Warning: Only allow if you need remote database access${NC}"
    read -p "Allow from specific IP only? (y/N): " specific_postgres
    
    if [[ $specific_postgres =~ ^[Yy]$ ]]; then
        read -p "Enter IP address or subnet (e.g., 192.168.1.0/24): " postgres_ip
        ufw allow from "$postgres_ip" to any port 5432 proto tcp comment 'PostgreSQL'
        echo -e "${GREEN}✅ PostgreSQL allowed from $postgres_ip${NC}"
    else
        ufw allow 5432/tcp comment 'PostgreSQL'
        echo -e "${GREEN}✅ PostgreSQL allowed${NC}"
    fi
fi

# Docker/Portainer
if command -v docker &> /dev/null; then
    echo ""
    read -p "Allow Portainer (port 9443)? (y/N): " allow_portainer
    if [[ $allow_portainer =~ ^[Yy]$ ]]; then
        ufw allow 9443/tcp comment 'Portainer'
        echo -e "${GREEN}✅ Portainer allowed${NC}"
    fi
    
    read -p "Allow Portainer Agent (port 9001)? (y/N): " allow_agent
    if [[ $allow_agent =~ ^[Yy]$ ]]; then
        ufw allow 9001/tcp comment 'Portainer Agent'
        echo -e "${GREEN}✅ Portainer Agent allowed${NC}"
    fi
fi

# Custom ports
echo ""
read -p "Do you want to add custom port rules? (y/N): " custom_ports

while [[ $custom_ports =~ ^[Yy]$ ]]; do
    echo ""
    read -p "Enter port number: " port_num
    read -p "Protocol (tcp/udp/both) [tcp]: " protocol
    protocol=${protocol:-tcp}
    read -p "Comment/description: " port_comment
    
    if [ "$protocol" = "both" ]; then
        ufw allow "$port_num" comment "$port_comment"
    else
        ufw allow "$port_num"/"$protocol" comment "$port_comment"
    fi
    
    echo -e "${GREEN}✅ Port $port_num/$protocol allowed${NC}"
    
    read -p "Add another custom port? (y/N): " custom_ports
done

# Show configuration before enabling
echo ""
echo -e "${CYAN}═══════════════════════════════════${NC}"
echo -e "${CYAN}    Firewall Rules Summary         ${NC}"
echo -e "${CYAN}═══════════════════════════════════${NC}"
echo ""
echo -e "${YELLOW}The following rules will be applied:${NC}"
ufw show added | grep -v "^Added" | sed 's/^/  /'

echo ""
read -p "Enable firewall with these rules? (Y/n): " enable_fw
enable_fw=${enable_fw:-Y}

if [[ ! $enable_fw =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Firewall not enabled. Rules saved but inactive.${NC}"
    exit 0
fi

# Enable UFW
echo ""
echo -e "${BLUE}🔥 Enabling firewall...${NC}"
ufw --force enable

echo ""
echo -e "${GREEN}╔═══════════════════════════════════╗${NC}"
echo -e "${GREEN}║   ✅ Firewall Configured!         ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════╝${NC}"
echo ""

# Show status
echo -e "${CYAN}Firewall Status:${NC}"
ufw status verbose

echo ""
echo -e "${YELLOW}💡 Useful UFW commands:${NC}"
echo -e "   View status:        ${BLUE}sudo ufw status verbose${NC}"
echo -e "   View numbered:      ${BLUE}sudo ufw status numbered${NC}"
echo -e "   Delete rule:        ${BLUE}sudo ufw delete <number>${NC}"
echo -e "   Allow port:         ${BLUE}sudo ufw allow <port>${NC}"
echo -e "   Deny port:          ${BLUE}sudo ufw deny <port>${NC}"
echo -e "   Disable firewall:   ${BLUE}sudo ufw disable${NC}"
echo -e "   Reset firewall:     ${BLUE}sudo ufw reset${NC}"
echo ""
echo -e "${YELLOW}📄 UFW logs:${NC}"
echo -e "   ${BLUE}/var/log/ufw.log${NC}"
echo ""
echo -e "${BLUE}🧱 Firewall setup brick is complete!${NC}"
