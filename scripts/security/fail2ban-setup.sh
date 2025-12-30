#!/bin/bash

# 🧱 Fail2Ban Setup Brick
# Installs and configures Fail2Ban for intrusion prevention

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   🧱 Fail2Ban Setup Brick         ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════╝${NC}"
echo ""

# Ensure script is running with sudo
if [ "$EUID" -ne 0 ]; then
  echo -e "${YELLOW}⚠️  This script needs to run with sudo. Re-running...${NC}"
  exec sudo "$0" "$@"
fi

echo -e "${CYAN}Fail2Ban protects your server by:${NC}"
echo "  • Banning IPs after failed login attempts"
echo "  • Monitoring SSH, Apache, Nginx logs"
echo "  • Automatic IP unbanning after timeout"
echo "  • Email notifications (optional)"
echo ""

read -p "Continue with Fail2Ban installation? (Y/n): " confirm
confirm=${confirm:-Y}

if [[ ! $confirm =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Installation cancelled.${NC}"
    exit 0
fi

# Check if already installed
if systemctl is-active --quiet fail2ban; then
    echo ""
    echo -e "${YELLOW}⚠️  Fail2Ban is already installed and running.${NC}"
    read -p "Do you want to reconfigure it? (y/N): " reconfig
    
    if [[ ! $reconfig =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Setup cancelled.${NC}"
        exit 0
    fi
fi

echo ""
echo -e "${BLUE}📦 Installing Fail2Ban...${NC}"
apt update
apt install -y fail2ban

echo ""
echo -e "${BLUE}🔧 Configuring Fail2Ban...${NC}"

# Create local configuration
cat > /etc/fail2ban/jail.local <<EOF
# ============================================
# Fail2Ban Local Configuration
# Created by ubuntu-toolbox on $(date +%Y-%m-%d)
# ============================================

[DEFAULT]
# Ban settings
bantime  = 1h
findtime = 10m
maxretry = 5

# Backend
backend = systemd

# Email notifications (disabled by default)
# destemail = your-email@example.com
# sendername = Fail2Ban
# action = %(action_mwl)s

# Default action (just ban, no email)
action = %(action_)s

# ============================================
# SSH Protection (enabled by default)
# ============================================
[sshd]
enabled = true
port    = ssh
logpath = %(sshd_log)s
maxretry = 3
bantime = 1h

EOF

# Ask about additional services
echo ""
echo -e "${CYAN}Additional protections available:${NC}"
echo ""

# Apache protection
if systemctl is-active --quiet apache2 2>/dev/null; then
    read -p "Enable Apache protection? (Y/n): " apache_protect
    apache_protect=${apache_protect:-Y}
    
    if [[ $apache_protect =~ ^[Yy]$ ]]; then
        cat >> /etc/fail2ban/jail.local <<EOF

# ============================================
# Apache Protection
# ============================================
[apache-auth]
enabled = true
port    = http,https
logpath = %(apache_error_log)s
maxretry = 5

[apache-badbots]
enabled = true
port    = http,https
logpath = %(apache_access_log)s
maxretry = 2

[apache-noscript]
enabled = true
port    = http,https
logpath = %(apache_error_log)s
maxretry = 6

[apache-overflows]
enabled = true
port    = http,https
logpath = %(apache_error_log)s
maxretry = 2

EOF
        echo -e "${GREEN}✅ Apache protection enabled${NC}"
    fi
fi

# Nginx protection
if systemctl is-active --quiet nginx 2>/dev/null; then
    read -p "Enable Nginx protection? (Y/n): " nginx_protect
    nginx_protect=${nginx_protect:-Y}
    
    if [[ $nginx_protect =~ ^[Yy]$ ]]; then
        cat >> /etc/fail2ban/jail.local <<EOF

# ============================================
# Nginx Protection
# ============================================
[nginx-http-auth]
enabled = true
port    = http,https
logpath = %(nginx_error_log)s
maxretry = 5

[nginx-botsearch]
enabled = true
port    = http,https
logpath = %(nginx_access_log)s
maxretry = 2

EOF
        echo -e "${GREEN}✅ Nginx protection enabled${NC}"
    fi
fi

# Custom ban settings
echo ""
echo -e "${CYAN}Ban configuration:${NC}"
echo -e "  Current: Ban for ${GREEN}1 hour${NC} after ${GREEN}3-5${NC} failed attempts in ${GREEN}10 minutes${NC}"
echo ""
read -p "Use custom ban settings? (y/N): " custom_ban

if [[ $custom_ban =~ ^[Yy]$ ]]; then
    echo ""
    read -p "Ban time in hours [1]: " ban_hours
    ban_hours=${ban_hours:-1}
    
    read -p "Max retry attempts [5]: " max_retry
    max_retry=${max_retry:-5}
    
    read -p "Find time in minutes [10]: " find_mins
    find_mins=${find_mins:-10}
    
    # Update the DEFAULT section
    sed -i "s/^bantime  = .*/bantime  = ${ban_hours}h/" /etc/fail2ban/jail.local
    sed -i "s/^maxretry = .*/maxretry = ${max_retry}/" /etc/fail2ban/jail.local
    sed -i "s/^findtime = .*/findtime = ${find_mins}m/" /etc/fail2ban/jail.local
    
    echo -e "${GREEN}✅ Custom settings applied${NC}"
fi

echo ""
echo -e "${BLUE}🔧 Enabling and starting Fail2Ban...${NC}"
systemctl enable fail2ban
systemctl restart fail2ban

# Wait a moment for service to start
sleep 2

echo ""
echo -e "${GREEN}╔═══════════════════════════════════╗${NC}"
echo -e "${GREEN}║   ✅ Fail2Ban Configured!         ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════╝${NC}"
echo ""
echo -e "${CYAN}Configuration summary:${NC}"
fail2ban-client status | head -n 3
echo ""
echo -e "${CYAN}Active jails:${NC}"
fail2ban-client status | grep "Jail list:" | sed 's/.*://; s/,/\n  •/g' | sed 's/^/  •/'
echo ""
echo -e "${YELLOW}💡 Useful commands:${NC}"
echo "   View status:        ${BLUE}sudo fail2ban-client status${NC}"
echo "   View SSH jail:      ${BLUE}sudo fail2ban-client status sshd${NC}"
echo "   Unban an IP:        ${BLUE}sudo fail2ban-client set sshd unbanip <IP>${NC}"
echo "   View banned IPs:    ${BLUE}sudo fail2ban-client status sshd${NC}"
echo "   View logs:          ${BLUE}sudo tail -f /var/log/fail2ban.log${NC}"
echo ""
echo -e "${YELLOW}📄 Configuration files:${NC}"
echo "   Main config:        ${BLUE}/etc/fail2ban/jail.local${NC}"
echo "   Logs:               ${BLUE}/var/log/fail2ban.log${NC}"
echo ""
echo -e "${BLUE}🧱 Fail2Ban setup brick is complete!${NC}"
