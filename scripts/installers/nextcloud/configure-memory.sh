#!/bin/bash

# 🧱 Nextcloud Memory Configuration
# Configure PHP and Apache memory limits for optimal Nextcloud performance

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   🧱 Memory Configuration          ║${NC}"
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

if [ ! -f "$NC_CONFIG" ]; then
    echo -e "${RED}❌ Nextcloud not found at $NC_DIR${NC}"
    echo -e "${YELLOW}Please run the Nextcloud installer first.${NC}"
    exit 1
fi

# Find PHP version
PHP_VERSION=$(php -r "echo PHP_MAJOR_VERSION.'.'.PHP_MINOR_VERSION;")
PHP_INI="/etc/php/$PHP_VERSION/apache2/php.ini"

if [ ! -f "$PHP_INI" ]; then
    echo -e "${RED}❌ PHP configuration file not found: $PHP_INI${NC}"
    exit 1
fi

echo -e "${CYAN}System Memory Information:${NC}"
echo ""

# Get total memory in MB
TOTAL_MEM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
TOTAL_MEM_MB=$((TOTAL_MEM_KB / 1024))
TOTAL_MEM_GB=$(echo "scale=1; $TOTAL_MEM_MB / 1024" | bc)

# Get available memory in MB
AVAILABLE_MEM_KB=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
AVAILABLE_MEM_MB=$((AVAILABLE_MEM_KB / 1024))

# Get current PHP memory limit
CURRENT_PHP_MEMORY=$(php -r "echo ini_get('memory_limit');")

echo -e "  💾 Total RAM:        ${BLUE}${TOTAL_MEM_GB}G (${TOTAL_MEM_MB}M)${NC}"
echo -e "  ✅ Available RAM:    ${GREEN}${AVAILABLE_MEM_MB}M${NC}"
echo -e "  ⚙️  Current PHP Limit: ${YELLOW}${CURRENT_PHP_MEMORY}${NC}"
echo ""

echo -e "${CYAN}════════════════════════════════════════${NC}"
echo -e "${CYAN}Recommended Memory Allocations:${NC}"
echo -e "${CYAN}════════════════════════════════════════${NC}"
echo ""

# Calculate recommendations based on total memory
if [ $TOTAL_MEM_MB -ge 15000 ]; then
    # 16GB+ systems
    echo -e "${GREEN}For your ${TOTAL_MEM_GB}G system:${NC}"
    echo "  • Conservative:  2G (good for multi-service servers)"
    echo "  • Balanced:      4G (recommended for most setups)"
    echo "  • Performance:   8G (for large files and many users)"
elif [ $TOTAL_MEM_MB -ge 7000 ]; then
    # 8GB systems
    echo -e "${GREEN}For your ${TOTAL_MEM_GB}G system:${NC}"
    echo "  • Conservative:  1G (good for multi-service servers)"
    echo "  • Balanced:      2G (recommended for most setups)"
    echo "  • Performance:   4G (for large files)"
elif [ $TOTAL_MEM_MB -ge 3500 ]; then
    # 4GB systems
    echo -e "${GREEN}For your ${TOTAL_MEM_GB}G system:${NC}"
    echo "  • Conservative:  512M (good for multi-service servers)"
    echo "  • Balanced:      1G (recommended for most setups)"
    echo "  • Performance:   2G (for larger files)"
else
    # <4GB systems
    echo -e "${YELLOW}For your ${TOTAL_MEM_GB}G system:${NC}"
    echo "  • Conservative:  256M (basic operation)"
    echo "  • Balanced:      512M (recommended minimum)"
fi

echo ""
echo -e "${YELLOW}💡 Note: Leave some memory for the OS and other services${NC}"
echo ""

# Ask user for desired memory limit
echo -e "${CYAN}════════════════════════════════════════${NC}"
echo -e "${CYAN}Set Memory Limit:${NC}"
echo -e "${CYAN}════════════════════════════════════════${NC}"
echo ""
echo "Enter desired memory limit (e.g., 512M, 1G, 2G, 4G, 8G)"
echo -e "${YELLOW}or press Enter to keep current setting${NC}"
echo ""
read -p "Memory limit: " MEMORY_INPUT

# If user pressed enter, exit
if [ -z "$MEMORY_INPUT" ]; then
    echo -e "${YELLOW}No changes made. Keeping current setting: $CURRENT_PHP_MEMORY${NC}"
    exit 0
fi

# Validate input format
if ! [[ "$MEMORY_INPUT" =~ ^[0-9]+[MG]$ ]]; then
    echo -e "${RED}❌ Invalid format. Please use format like: 512M, 1G, 2G${NC}"
    exit 1
fi

# Convert to MB for validation
if [[ "$MEMORY_INPUT" =~ ^([0-9]+)G$ ]]; then
    INPUT_MB=$((${BASH_REMATCH[1]} * 1024))
elif [[ "$MEMORY_INPUT" =~ ^([0-9]+)M$ ]]; then
    INPUT_MB=${BASH_REMATCH[1]}
fi

# Validate against available memory (leave at least 512M for system)
MAX_SAFE_MB=$((TOTAL_MEM_MB - 512))
if [ $INPUT_MB -gt $MAX_SAFE_MB ]; then
    echo -e "${RED}❌ Warning: Requested ${MEMORY_INPUT} exceeds safe limit${NC}"
    echo -e "${YELLOW}Maximum recommended: ${MAX_SAFE_MB}M (leaving 512M for system)${NC}"
    echo ""
    read -p "Continue anyway? (y/N): " FORCE_CONTINUE
    if [[ ! $FORCE_CONTINUE =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Cancelled. No changes made.${NC}"
        exit 0
    fi
fi

echo ""
echo -e "${BLUE}🔧 Configuring PHP memory limit to ${MEMORY_INPUT}...${NC}"
echo ""

# Backup PHP configuration
BACKUP_FILE="${PHP_INI}.backup.$(date +%Y%m%d_%H%M%S)"
cp "$PHP_INI" "$BACKUP_FILE"
echo -e "${GREEN}✅ Backup created: $BACKUP_FILE${NC}"

# Update memory_limit in php.ini
# Remove any existing memory_limit lines (commented or not)
sed -i '/^[; ]*memory_limit/d' "$PHP_INI"

# Add new memory_limit at the end with a marker
echo "" >> "$PHP_INI"
echo "; Modified by Nextcloud Memory Configuration Script - $(date)" >> "$PHP_INI"
echo "memory_limit = $MEMORY_INPUT" >> "$PHP_INI"

echo -e "${GREEN}✅ PHP configuration updated${NC}"
echo ""

# Also update related PHP settings for better performance
echo -e "${BLUE}🔧 Updating related PHP settings...${NC}"

# upload_max_filesize (set to memory_limit)
sed -i '/^[; ]*upload_max_filesize/d' "$PHP_INI"
echo "upload_max_filesize = $MEMORY_INPUT" >> "$PHP_INI"

# post_max_size (set to memory_limit)
sed -i '/^[; ]*post_max_size/d' "$PHP_INI"
echo "post_max_size = $MEMORY_INPUT" >> "$PHP_INI"

# max_execution_time (5 minutes)
sed -i '/^[; ]*max_execution_time/d' "$PHP_INI"
echo "max_execution_time = 300" >> "$PHP_INI"

# max_input_time (5 minutes)
sed -i '/^[; ]*max_input_time/d' "$PHP_INI"
echo "max_input_time = 300" >> "$PHP_INI"

echo -e "${GREEN}✅ Related settings updated${NC}"
echo ""

# Restart Apache to apply changes
echo -e "${BLUE}🔄 Restarting Apache to apply changes...${NC}"
systemctl restart apache2

if systemctl is-active --quiet apache2; then
    echo -e "${GREEN}✅ Apache restarted successfully${NC}"
else
    echo -e "${RED}❌ Apache failed to restart${NC}"
    echo -e "${YELLOW}Restoring backup...${NC}"
    cp "$BACKUP_FILE" "$PHP_INI"
    systemctl restart apache2
    echo -e "${RED}Changes reverted. Please check your configuration.${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}╔═══════════════════════════════════╗${NC}"
echo -e "${GREEN}║   ✅ Configuration Complete!      ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════╝${NC}"
echo ""

# Verify new settings
NEW_PHP_MEMORY=$(php -r "echo ini_get('memory_limit');")
NEW_UPLOAD_MAX=$(php -r "echo ini_get('upload_max_filesize');")
NEW_POST_MAX=$(php -r "echo ini_get('post_max_size');")

echo -e "${CYAN}New Configuration:${NC}"
echo -e "  ⚙️  PHP Memory Limit:      ${GREEN}${NEW_PHP_MEMORY}${NC}"
echo -e "  ⬆️  Max Upload Size:       ${GREEN}${NEW_UPLOAD_MAX}${NC}"
echo -e "  📤 Max POST Size:          ${GREEN}${NEW_POST_MAX}${NC}"
echo -e "  ⏱️  Max Execution Time:    ${GREEN}300s${NC}"
echo -e "  ⏱️  Max Input Time:        ${GREEN}300s${NC}"
echo ""
echo -e "${CYAN}PHP Configuration:${NC}"
echo -e "  📄 PHP Version:           ${BLUE}${PHP_VERSION}${NC}"
echo -e "  📄 Configuration File:    ${BLUE}${PHP_INI}${NC}"
echo -e "  💾 Backup File:           ${BLUE}${BACKUP_FILE}${NC}"
echo ""
echo -e "${YELLOW}💡 Useful commands:${NC}"
echo -e "   Check PHP info:       ${BLUE}php -i | grep memory${NC}"
echo -e "   View PHP config:      ${BLUE}cat $PHP_INI | grep memory_limit${NC}"
echo -e "   Restore backup:       ${BLUE}sudo cp $BACKUP_FILE $PHP_INI && sudo systemctl restart apache2${NC}"
echo ""
echo -e "${BLUE}🧱 Memory configuration brick is complete!${NC}"
