#!/bin/bash

# 🧱 System Update Brick
# Performs a full system update and upgrade

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════╗${NC}"
echo -e "${BLUE}║   🧱 System Update Brick       ║${NC}"
echo -e "${BLUE}╚════════════════════════════════╝${NC}"
echo ""

# Ensure script is running with sudo
if [ "$EUID" -ne 0 ]; then
  echo -e "${YELLOW}⚠️  This script needs to run with sudo. Re-running...${NC}"
  exec sudo "$0" "$@"
fi

echo -e "${CYAN}This will:${NC}"
echo "  • Update package lists"
echo "  • Upgrade all installed packages"
echo "  • Remove obsolete packages"
echo ""

read -p "Continue with system update? (Y/n): " confirm
confirm=${confirm:-Y}

if [[ ! $confirm =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Update cancelled.${NC}"
    exit 0
fi

echo ""
echo -e "${BLUE}📦 Updating package lists...${NC}"
apt update

echo ""
echo -e "${BLUE}⬆️  Upgrading packages...${NC}"
apt upgrade -y

echo ""
echo -e "${BLUE}🧹 Cleaning up...${NC}"
apt autoremove -y
apt autoclean

echo ""
echo -e "${GREEN}╔═══════════════════════════════╗${NC}"
echo -e "${GREEN}║   ✅ System Updated!          ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}🧱 System update brick is complete!${NC}"
