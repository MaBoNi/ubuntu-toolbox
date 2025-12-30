#!/bin/bash

# 🧱 Enable Auto Updates Brick
# Enables automatic security updates

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   🧱 Enable Auto Updates Brick    ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════╝${NC}"
echo ""

# Ensure script is running with sudo
if [ "$EUID" -ne 0 ]; then
  echo -e "${YELLOW}⚠️  This script needs to run with sudo. Re-running...${NC}"
  exec sudo "$0" "$@"
fi

echo -e "${CYAN}This will enable automatic security updates.${NC}"
echo -e "${YELLOW}Security updates will be installed automatically.${NC}"
echo ""

read -p "Continue with enabling auto updates? (Y/n): " confirm
confirm=${confirm:-Y}

if [[ ! $confirm =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Cancelled.${NC}"
    exit 0
fi

echo ""
echo -e "${BLUE}📦 Installing unattended-upgrades...${NC}"
apt update
apt install -y unattended-upgrades apt-listchanges

echo ""
echo -e "${BLUE}🔧 Configuring automatic updates...${NC}"

# Enable automatic updates
cat > /etc/apt/apt.conf.d/20auto-upgrades <<EOF
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Unattended-Upgrade "1";
EOF

# Configure unattended-upgrades
cat > /etc/apt/apt.conf.d/50unattended-upgrades <<EOF
Unattended-Upgrade::Allowed-Origins {
    "\${distro_id}:\${distro_codename}";
    "\${distro_id}:\${distro_codename}-security";
    "\${distro_id}ESMApps:\${distro_codename}-apps-security";
    "\${distro_id}ESM:\${distro_codename}-infra-security";
};

Unattended-Upgrade::AutoFixInterruptedDpkg "true";
Unattended-Upgrade::MinimalSteps "true";
Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "false";
Unattended-Upgrade::Automatic-Reboot-Time "02:00";
EOF

echo -e "${GREEN}✅ Auto updates configured${NC}"

echo ""
echo -e "${BLUE}🔧 Enabling and starting service...${NC}"
systemctl enable unattended-upgrades
systemctl start unattended-upgrades

echo ""
echo -e "${GREEN}╔═══════════════════════════════════╗${NC}"
echo -e "${GREEN}║   ✅ Auto Updates Enabled!        ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════╝${NC}"
echo ""
echo -e "${CYAN}Configuration:${NC}"
echo "  • Daily package list updates"
echo "  • Automatic security updates"
echo "  • Automatic cleanup every 7 days"
echo "  • Unused packages will be removed"
echo "  • Automatic reboot: ${YELLOW}disabled${NC}"
echo ""
echo -e "${YELLOW}💡 Tip:${NC} Check update logs with: ${BLUE}cat /var/log/unattended-upgrades/unattended-upgrades.log${NC}"
echo ""
echo -e "${BLUE}🧱 Auto updates brick is complete!${NC}"
