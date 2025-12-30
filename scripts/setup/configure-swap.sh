#!/bin/bash

# 🧱 Configure Swap Brick
# Creates and configures swap space

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════╗${NC}"
echo -e "${BLUE}║   🧱 Configure Swap Brick      ║${NC}"
echo -e "${BLUE}╚════════════════════════════════╝${NC}"
echo ""

# Ensure script is running with sudo
if [ "$EUID" -ne 0 ]; then
  echo -e "${YELLOW}⚠️  This script needs to run with sudo. Re-running...${NC}"
  exec sudo "$0" "$@"
fi

# Check current swap
CURRENT_SWAP=$(free -h | grep Swap | awk '{print $2}')
echo -e "${CYAN}Current swap:${NC} ${YELLOW}${CURRENT_SWAP}${NC}"
echo ""

if [ "$CURRENT_SWAP" != "0B" ] && [ "$CURRENT_SWAP" != "0" ]; then
    echo -e "${YELLOW}Swap is already configured.${NC}"
    read -p "Do you want to reconfigure it? (y/N): " reconfigure
    
    if [[ ! $reconfigure =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Cancelled.${NC}"
        exit 0
    fi
fi

# Get total RAM
TOTAL_RAM_MB=$(free -m | grep Mem | awk '{print $2}')
TOTAL_RAM_GB=$((TOTAL_RAM_MB / 1024))

echo -e "${CYAN}Total RAM:${NC} ${GREEN}${TOTAL_RAM_GB}GB${NC}"
echo ""
echo -e "${YELLOW}Recommended swap sizes:${NC}"
echo "  • For ${TOTAL_RAM_GB}GB RAM: ${GREEN}$((TOTAL_RAM_GB * 2))GB${NC} (2x RAM, recommended for systems with <8GB RAM)"
echo "  • Equal to RAM: ${GREEN}${TOTAL_RAM_GB}GB${NC}"
echo "  • Minimal: ${GREEN}2GB${NC}"
echo ""

read -p "Enter swap size in GB [$(if [ $TOTAL_RAM_GB -lt 8 ]; then echo $((TOTAL_RAM_GB * 2)); else echo $TOTAL_RAM_GB; fi)]: " SWAP_SIZE_GB

if [ -z "$SWAP_SIZE_GB" ]; then
    if [ $TOTAL_RAM_GB -lt 8 ]; then
        SWAP_SIZE_GB=$((TOTAL_RAM_GB * 2))
    else
        SWAP_SIZE_GB=$TOTAL_RAM_GB
    fi
fi

# Validate input
if ! [[ "$SWAP_SIZE_GB" =~ ^[0-9]+$ ]] || [ "$SWAP_SIZE_GB" -lt 1 ]; then
    echo -e "${RED}❌ Invalid swap size!${NC}"
    exit 1
fi

SWAPFILE="/swapfile"

echo ""
echo -e "${BLUE}🔧 Creating ${SWAP_SIZE_GB}GB swap file...${NC}"
echo -e "${YELLOW}⏳ This may take a few minutes...${NC}"

# Remove existing swap if present
if [ -f "$SWAPFILE" ]; then
    echo -e "${YELLOW}Removing existing swap file...${NC}"
    swapoff "$SWAPFILE" 2>/dev/null || true
    rm -f "$SWAPFILE"
fi

# Create swap file
dd if=/dev/zero of="$SWAPFILE" bs=1G count="$SWAP_SIZE_GB" status=progress

echo ""
echo -e "${BLUE}🔧 Setting permissions...${NC}"
chmod 600 "$SWAPFILE"

echo ""
echo -e "${BLUE}🔧 Setting up swap area...${NC}"
mkswap "$SWAPFILE"

echo ""
echo -e "${BLUE}🔧 Enabling swap...${NC}"
swapon "$SWAPFILE"

# Make swap permanent
echo ""
echo -e "${BLUE}🔧 Making swap permanent...${NC}"
if ! grep -q "$SWAPFILE" /etc/fstab; then
    echo "$SWAPFILE none swap sw 0 0" >> /etc/fstab
    echo -e "${GREEN}✅ Added to /etc/fstab${NC}"
else
    echo -e "${YELLOW}Already in /etc/fstab${NC}"
fi

# Configure swappiness (how aggressively to use swap)
echo ""
echo -e "${BLUE}🔧 Configuring swappiness...${NC}"
echo "vm.swappiness=10" > /etc/sysctl.d/99-swappiness.conf
sysctl -p /etc/sysctl.d/99-swappiness.conf

# Show current state
NEW_SWAP=$(free -h | grep Swap | awk '{print $2}')

echo ""
echo -e "${GREEN}╔═══════════════════════════════╗${NC}"
echo -e "${GREEN}║   ✅ Swap Configured!         ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════╝${NC}"
echo ""
echo -e "${CYAN}Swap information:${NC}"
echo "  • Swap file: ${GREEN}$SWAPFILE${NC}"
echo "  • Swap size: ${GREEN}$NEW_SWAP${NC}"
echo "  • Swappiness: ${GREEN}10${NC} (conservative)"
echo ""
free -h
echo ""
echo -e "${YELLOW}💡 What is swappiness?${NC}"
echo "   Swappiness=10 means the system will avoid using swap unless necessary."
echo "   This keeps your system responsive while having emergency memory available."
echo ""
echo -e "${BLUE}🧱 Swap configuration brick is complete!${NC}"
