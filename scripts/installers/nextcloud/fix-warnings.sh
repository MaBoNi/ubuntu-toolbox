#!/bin/bash

# 🧱 Nextcloud Fix Warnings
# Fix common Nextcloud admin warnings: phone region and Imagick SVG support

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   🧱 Fix Admin Warnings            ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════╝${NC}"
echo ""

# Ensure script is running with sudo
if [ "$EUID" -ne 0 ]; then
  echo -e "${YELLOW}⚠️  This script needs to run with sudo. Re-running...${NC}"
  exec sudo "$0" "$@"
fi

# Detect Nextcloud installation
NC_DIR="/var/www/nextcloud"
NC_CONFIG="$NC_DIR/config/config.php"
NC_OCC="$NC_DIR/occ"

if [ ! -f "$NC_CONFIG" ]; then
    echo -e "${RED}❌ Nextcloud not found at $NC_DIR${NC}"
    echo -e "${YELLOW}Please run the Nextcloud installer first.${NC}"
    exit 1
fi

echo -e "${CYAN}This script will fix:${NC}"
echo "  📞 Default phone region warning"
echo "  🎨 Imagick SVG support warning"
echo ""

# Backup Nextcloud config
BACKUP_FILE="${NC_CONFIG}.backup.$(date +%Y%m%d_%H%M%S)"
cp "$NC_CONFIG" "$BACKUP_FILE"
echo -e "${GREEN}✅ Backup created: $BACKUP_FILE${NC}"
echo ""

echo -e "${BLUE}═══════════════════════════════════════${NC}"
echo -e "${BLUE}1️⃣  Setting Default Phone Region${NC}"
echo -e "${BLUE}═══════════════════════════════════════${NC}"
echo ""

echo -e "${CYAN}Enter your country code (ISO 3166-1):${NC}"
echo "  Common examples:"
echo "  • DK - Denmark"
echo "  • US - United States"
echo "  • GB - United Kingdom"
echo "  • DE - Germany"
echo "  • SE - Sweden"
echo "  • NO - Norway"
echo ""
read -p "Country code [DK]: " COUNTRY_CODE
COUNTRY_CODE=${COUNTRY_CODE:-DK}

# Convert to uppercase
COUNTRY_CODE=$(echo "$COUNTRY_CODE" | tr '[:lower:]' '[:upper:]')

sudo -u www-data php "$NC_OCC" config:system:set default_phone_region --value="$COUNTRY_CODE"
echo -e "${GREEN}✅ Default phone region set to: $COUNTRY_CODE${NC}"

echo ""
echo -e "${BLUE}═══════════════════════════════════════${NC}"
echo -e "${BLUE}2️⃣  Installing Imagick SVG Support${NC}"
echo -e "${BLUE}═══════════════════════════════════════${NC}"
echo ""

echo -e "${CYAN}Installing ImageMagick with SVG support...${NC}"
apt update
apt install -y imagemagick libmagickcore-6.q16-6-extra

# Restart Apache to load the new configuration
echo -e "${CYAN}Restarting Apache...${NC}"
systemctl restart apache2

if systemctl is-active --quiet apache2; then
    echo -e "${GREEN}✅ Imagick SVG support installed${NC}"
else
    echo -e "${RED}❌ Apache failed to restart${NC}"
    echo -e "${YELLOW}Restoring backup...${NC}"
    cp "$BACKUP_FILE" "$NC_CONFIG"
    systemctl restart apache2
    exit 1
fi

echo ""
echo -e "${GREEN}╔═══════════════════════════════════╗${NC}"
echo -e "${GREEN}║   ✅ Warnings Fixed!              ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════╝${NC}"
echo ""

echo -e "${CYAN}Summary:${NC}"
echo -e "  ✅ Default phone region set to: ${BLUE}$COUNTRY_CODE${NC}"
echo -e "  ✅ Imagick SVG support installed"
echo ""
echo -e "${CYAN}Configuration backup:${NC}"
echo -e "   ${BLUE}$BACKUP_FILE${NC}"
echo ""
echo -e "${BLUE}🧱 Warning fixes brick is complete!${NC}"
