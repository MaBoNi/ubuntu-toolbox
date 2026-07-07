#!/bin/bash

# 🧱 Ubuntu Toolbox - System Update
# Performs a full system upgrade (update, upgrade, autoremove, autoclean)

set -e

# Colors for LEGO-themed output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Self-elevate to sudo if needed
if [ "$EUID" -ne 0 ]; then
    exec sudo "$0" "$@"
fi

echo -e "${BLUE}"
echo "╔════════════════════════════════════════╗"
echo "║   🔄 System Update 🔄                  ║"
echo "║  'Keep your bricks up to date!'        ║"
echo "╚════════════════════════════════════════╝"
echo -e "${NC}"

echo -e "${CYAN}This will perform a full system upgrade:${NC}"
echo "  • apt-get update        - Refresh package lists"
echo "  • apt-get upgrade       - Upgrade installed packages"
echo "  • apt-get dist-upgrade  - Handle dependency changes"
echo "  • apt-get autoremove    - Remove unused packages"
echo "  • apt-get autoclean     - Clean up downloaded packages"
echo ""

read -p "Proceed with full system update? [y/N] " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}⚠️  Update cancelled.${NC}"
    exit 0
fi

echo ""
echo -e "${YELLOW}📡 Updating package lists...${NC}"
apt-get update

echo ""
echo -e "${YELLOW}⬆️  Upgrading installed packages...${NC}"
apt-get upgrade -y

echo ""
echo -e "${YELLOW}🔀 Running dist-upgrade...${NC}"
apt-get dist-upgrade -y

echo ""
echo -e "${YELLOW}🧹 Removing unused packages...${NC}"
apt-get autoremove -y

echo ""
echo -e "${YELLOW}🗑️  Cleaning up downloaded package files...${NC}"
apt-get autoclean -y

echo ""
echo -e "${GREEN}✅ System update complete!${NC}"

# Check if a reboot is required
if [ -f /var/run/reboot-required ]; then
    echo ""
    echo -e "${YELLOW}⚠️  A system reboot is required to complete the update.${NC}"
    read -p "Reboot now? [y/N] " reboot_now
    if [[ "$reboot_now" =~ ^[Yy]$ ]]; then
        echo -e "${BLUE}🔁 Rebooting...${NC}"
        reboot
    else
        echo -e "${CYAN}ℹ️  Remember to reboot when convenient.${NC}"
    fi
fi
