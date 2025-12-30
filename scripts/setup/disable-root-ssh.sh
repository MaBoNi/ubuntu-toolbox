#!/bin/bash

# 🧱 Disable Root SSH Brick
# Disables root login via SSH for security

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════╗${NC}"
echo -e "${BLUE}║   🧱 Disable Root SSH Brick    ║${NC}"
echo -e "${BLUE}╚════════════════════════════════╝${NC}"
echo ""

# Ensure script is running with sudo
if [ "$EUID" -ne 0 ]; then
  echo -e "${YELLOW}⚠️  This script needs to run with sudo. Re-running...${NC}"
  exec sudo "$0" "$@"
fi

echo -e "${CYAN}This will disable root login via SSH for security.${NC}"
echo -e "${YELLOW}⚠️  Make sure you have another way to access the server!${NC}"
echo ""

# Check if already disabled
SSHD_CONFIG="/etc/ssh/sshd_config"
CURRENT_SETTING=$(grep "^PermitRootLogin" "$SSHD_CONFIG" 2>/dev/null || echo "not set")

echo -e "${CYAN}Current setting:${NC} ${YELLOW}${CURRENT_SETTING}${NC}"
echo ""

if [[ "$CURRENT_SETTING" == *"no"* ]]; then
    echo -e "${GREEN}✅ Root SSH login is already disabled!${NC}"
    exit 0
fi

read -p "Continue and disable root SSH login? (y/N): " confirm

if [[ ! $confirm =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Cancelled.${NC}"
    exit 0
fi

echo ""
echo -e "${BLUE}🔧 Backing up SSH config...${NC}"
cp "$SSHD_CONFIG" "${SSHD_CONFIG}.backup.$(date +%Y%m%d_%H%M%S)"
echo -e "${GREEN}✅ Backup created${NC}"

echo ""
echo -e "${BLUE}🔧 Disabling root SSH login...${NC}"

# Remove any existing PermitRootLogin lines
sed -i '/^PermitRootLogin/d' "$SSHD_CONFIG"
sed -i '/^#PermitRootLogin/d' "$SSHD_CONFIG"

# Add the new setting at the end
echo "" >> "$SSHD_CONFIG"
echo "# Disable root login via SSH (configured by ubuntu-toolbox)" >> "$SSHD_CONFIG"
echo "PermitRootLogin no" >> "$SSHD_CONFIG"

echo -e "${GREEN}✅ Configuration updated${NC}"

echo ""
echo -e "${BLUE}🔧 Testing SSH configuration...${NC}"
if sshd -t; then
    echo -e "${GREEN}✅ SSH configuration is valid${NC}"
else
    echo -e "${RED}❌ SSH configuration has errors! Restoring backup...${NC}"
    mv "${SSHD_CONFIG}.backup."* "$SSHD_CONFIG"
    echo -e "${YELLOW}Backup restored. No changes made.${NC}"
    exit 1
fi

echo ""
echo -e "${BLUE}🔄 Restarting SSH service...${NC}"
systemctl restart sshd || systemctl restart ssh

echo ""
echo -e "${GREEN}╔═══════════════════════════════╗${NC}"
echo -e "${GREEN}║   ✅ Root SSH Disabled!       ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}⚠️  Important:${NC}"
echo "  • Root can no longer login via SSH"
echo "  • Make sure you have a non-root user with sudo access"
echo "  • Your current SSH session will remain active"
echo ""
echo -e "${BLUE}🧱 Root SSH disable brick is complete!${NC}"
