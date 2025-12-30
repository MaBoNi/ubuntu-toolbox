#!/bin/bash

# 🧱 Configure Timezone Brick
# Sets the system timezone

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════╗${NC}"
echo -e "${BLUE}║   🧱 Configure Timezone Brick  ║${NC}"
echo -e "${BLUE}╚════════════════════════════════╝${NC}"
echo ""

# Ensure script is running with sudo
if [ "$EUID" -ne 0 ]; then
  echo -e "${YELLOW}⚠️  This script needs to run with sudo. Re-running...${NC}"
  exec sudo "$0" "$@"
fi

# Show current timezone
CURRENT_TZ=$(timedatectl show -p Timezone --value)
CURRENT_TIME=$(date)

echo -e "${CYAN}Current timezone:${NC} ${YELLOW}${CURRENT_TZ}${NC}"
echo -e "${CYAN}Current time:${NC} ${YELLOW}${CURRENT_TIME}${NC}"
echo ""

# Ask if user wants to change
read -p "Do you want to change the timezone? (y/N): " change_tz

if [[ ! $change_tz =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Timezone unchanged.${NC}"
    exit 0
fi

echo ""
echo -e "${BLUE}Common timezones:${NC}"
echo "  1) America/New_York (EST/EDT)"
echo "  2) America/Chicago (CST/CDT)"
echo "  3) America/Denver (MST/MDT)"
echo "  4) America/Los_Angeles (PST/PDT)"
echo "  5) Europe/London (GMT/BST)"
echo "  6) Europe/Paris (CET/CEST)"
echo "  7) Europe/Copenhagen (CET/CEST)"
echo "  8) Asia/Tokyo (JST)"
echo "  9) Australia/Sydney (AEST/AEDT)"
echo "  10) UTC"
echo "  11) Other (manual entry)"
echo ""

read -p "Select timezone (1-11): " tz_choice

case $tz_choice in
    1) NEW_TZ="America/New_York" ;;
    2) NEW_TZ="America/Chicago" ;;
    3) NEW_TZ="America/Denver" ;;
    4) NEW_TZ="America/Los_Angeles" ;;
    5) NEW_TZ="Europe/London" ;;
    6) NEW_TZ="Europe/Paris" ;;
    7) NEW_TZ="Europe/Copenhagen" ;;
    8) NEW_TZ="Asia/Tokyo" ;;
    9) NEW_TZ="Australia/Sydney" ;;
    10) NEW_TZ="UTC" ;;
    11)
        echo ""
        echo -e "${YELLOW}💡 Tip: List available timezones with: timedatectl list-timezones${NC}"
        read -p "Enter timezone (e.g., Europe/Copenhagen): " NEW_TZ
        ;;
    *)
        echo -e "${RED}❌ Invalid selection${NC}"
        exit 1
        ;;
esac

if [ -z "$NEW_TZ" ]; then
    echo -e "${RED}❌ Timezone cannot be empty!${NC}"
    exit 1
fi

# Validate timezone
if ! timedatectl list-timezones | grep -q "^${NEW_TZ}$"; then
    echo -e "${RED}❌ Invalid timezone: ${NEW_TZ}${NC}"
    echo "Run 'timedatectl list-timezones' to see available options"
    exit 1
fi

echo ""
echo -e "${BLUE}🔧 Setting timezone to: ${GREEN}${NEW_TZ}${NC}"
timedatectl set-timezone "$NEW_TZ"

# Show new time
NEW_TIME=$(date)

echo ""
echo -e "${GREEN}╔═══════════════════════════════╗${NC}"
echo -e "${GREEN}║   ✅ Timezone Updated!        ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════╝${NC}"
echo ""
echo -e "${CYAN}New timezone:${NC} ${GREEN}${NEW_TZ}${NC}"
echo -e "${CYAN}New time:${NC} ${GREEN}${NEW_TIME}${NC}"
echo ""
echo -e "${BLUE}🧱 Timezone brick is complete!${NC}"
