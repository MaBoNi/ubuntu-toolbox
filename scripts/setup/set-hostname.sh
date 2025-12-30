#!/bin/bash

# 🧱 Set Hostname Brick
# Sets system hostname and displays network information

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════╗${NC}"
echo -e "${BLUE}║   🧱 Set Hostname Brick        ║${NC}"
echo -e "${BLUE}╚════════════════════════════════╝${NC}"
echo ""

# Ensure script is running with sudo
if [ "$EUID" -ne 0 ]; then
  echo -e "${YELLOW}⚠️  This script needs to run with sudo. Re-running...${NC}"
  exec sudo "$0" "$@"
fi

# Show current hostname
CURRENT_HOSTNAME=$(hostname)
echo -e "${CYAN}Current hostname:${NC} ${YELLOW}${CURRENT_HOSTNAME}${NC}"
echo ""

# Show IP addresses
echo -e "${CYAN}Network Information:${NC}"
echo -e "${GREEN}───────────────────────────────${NC}"

# Get primary IP address
PRIMARY_IP=$(hostname -I | awk '{print $1}')
echo -e "${BLUE}Primary IP:${NC} ${GREEN}${PRIMARY_IP}${NC}"

# Get all network interfaces with IPs
echo ""
echo -e "${BLUE}All interfaces:${NC}"
ip -4 -o addr show | awk '{print "  • " $2 ": " $4}' | sed 's/\// (/'  | sed 's/$/)/'

echo ""
echo -e "${GREEN}───────────────────────────────${NC}"
echo ""

# Ask if user wants to change hostname
read -p "Do you want to change the hostname? (y/N): " change_hostname

if [[ $change_hostname =~ ^[Yy]$ ]]; then
    echo ""
    read -p "Enter new hostname: " NEW_HOSTNAME
    
    if [ -z "$NEW_HOSTNAME" ]; then
        echo -e "${RED}❌ Hostname cannot be empty!${NC}"
        exit 1
    fi
    
    # Validate hostname format (RFC 1123)
    if [[ ! $NEW_HOSTNAME =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?$ ]]; then
        echo -e "${RED}❌ Invalid hostname format!${NC}"
        echo "Hostname must:"
        echo "  • Start and end with alphanumeric characters"
        echo "  • Contain only letters, numbers, and hyphens"
        echo "  • Be 1-63 characters long"
        exit 1
    fi
    
    echo ""
    echo -e "${BLUE}🔧 Setting hostname to: ${GREEN}${NEW_HOSTNAME}${NC}"
    
    # Set hostname
    hostnamectl set-hostname "$NEW_HOSTNAME"
    
    # Update /etc/hosts
    sed -i "s/127.0.1.1.*/127.0.1.1\t${NEW_HOSTNAME}/" /etc/hosts
    
    # Add entry if it doesn't exist
    if ! grep -q "127.0.1.1" /etc/hosts; then
        echo "127.0.1.1	${NEW_HOSTNAME}" >> /etc/hosts
    fi
    
    echo -e "${GREEN}✅ Hostname changed successfully!${NC}"
    echo ""
    
    # Show new hostname
    NEW_HOST=$(hostname)
    echo -e "${CYAN}New hostname:${NC} ${GREEN}${NEW_HOST}${NC}"
    
    NEEDS_REBOOT=true
else
    echo -e "${YELLOW}Hostname unchanged.${NC}"
    NEEDS_REBOOT=false
fi

# Summary
echo ""
echo -e "${GREEN}╔═══════════════════════════════╗${NC}"
echo -e "${GREEN}║   ✅ Configuration Complete!  ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════╝${NC}"
echo ""
echo -e "${CYAN}Quick Reference:${NC}"
echo -e "  Hostname: ${GREEN}$(hostname)${NC}"
echo -e "  Primary IP: ${GREEN}${PRIMARY_IP}${NC}"

# Ask about reboot
if [ "$NEEDS_REBOOT" = true ]; then
    echo ""
    echo -e "${YELLOW}⚠️  A reboot is recommended for hostname changes to fully take effect.${NC}"
    read -p "Do you want to reboot now? (y/N): " do_reboot
    
    if [[ $do_reboot =~ ^[Yy]$ ]]; then
        echo ""
        echo -e "${BLUE}🔄 Rebooting in 5 seconds...${NC}"
        echo -e "${YELLOW}Press Ctrl+C to cancel${NC}"
        sleep 5
        reboot
    else
        echo ""
        echo -e "${YELLOW}💡 Remember to reboot later: ${GREEN}sudo reboot${NC}"
    fi
else
    echo ""
    read -p "Do you want to reboot anyway? (y/N): " do_reboot
    
    if [[ $do_reboot =~ ^[Yy]$ ]]; then
        echo ""
        echo -e "${BLUE}🔄 Rebooting in 5 seconds...${NC}"
        echo -e "${YELLOW}Press Ctrl+C to cancel${NC}"
        sleep 5
        reboot
    fi
fi

echo ""
echo -e "${BLUE}🧱 Hostname brick is complete!${NC}"
