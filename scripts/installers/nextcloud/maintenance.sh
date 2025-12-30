#!/bin/bash

# 🧱 Nextcloud Maintenance Setup Brick
# Sets up automated maintenance tasks (cron jobs, background jobs)

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   🧱 Nextcloud Maintenance Setup      ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
echo ""

# Ensure script is running with sudo
if [ "$EUID" -ne 0 ]; then
  echo -e "${YELLOW}⚠️  This script needs to run with sudo. Re-running...${NC}"
  exec sudo "$0" "$@"
fi

# Find Nextcloud installation
NEXTCLOUD_DIR="/var/www/nextcloud"
OCC_CMD="$NEXTCLOUD_DIR/occ"

if [ ! -f "$OCC_CMD" ]; then
    echo -e "${RED}❌ Nextcloud not found at $NEXTCLOUD_DIR${NC}"
    echo "Is Nextcloud installed?"
    exit 1
fi

echo -e "${CYAN}This script sets up automated maintenance tasks:${NC}"
echo "  • Background jobs via cron (recommended)"
echo "  • Database optimization"
echo "  • File scanning"
echo "  • Cleanup tasks"
echo ""

read -p "Continue with maintenance setup? (Y/n): " confirm
confirm=${confirm:-Y}

if [[ ! $confirm =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Setup cancelled.${NC}"
    exit 0
fi

# Check current background jobs setting
echo ""
echo -e "${BLUE}🔍 Checking current configuration...${NC}"
CURRENT_MODE=$(sudo -u www-data php "$OCC_CMD" config:app:get core backgroundjobs_mode || echo "ajax")
echo -e "${CYAN}Current background jobs mode:${NC} ${YELLOW}$CURRENT_MODE${NC}"

# Set to cron mode
echo ""
echo -e "${BLUE}🔧 Setting background jobs to cron mode...${NC}"
sudo -u www-data php "$OCC_CMD" background:cron
echo -e "${GREEN}✅ Background jobs mode set to cron${NC}"

# Set up cron job
echo ""
echo -e "${BLUE}🔧 Setting up cron job for www-data user...${NC}"

# Check if cron job already exists
if crontab -u www-data -l 2>/dev/null | grep -q "php.*$NEXTCLOUD_DIR/cron.php"; then
    echo -e "${YELLOW}⚠️  Cron job already exists${NC}"
    read -p "Overwrite existing cron job? (y/N): " overwrite
    
    if [[ ! $overwrite =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Keeping existing cron job${NC}"
    else
        # Remove old cron job
        (crontab -u www-data -l 2>/dev/null | grep -v "php.*$NEXTCLOUD_DIR/cron.php") | crontab -u www-data -
        echo -e "${YELLOW}Removed old cron job${NC}"
        
        # Add new cron job
        (crontab -u www-data -l 2>/dev/null; echo "*/5 * * * * php -f $NEXTCLOUD_DIR/cron.php") | crontab -u www-data -
        echo -e "${GREEN}✅ New cron job added${NC}"
    fi
else
    # Add cron job (runs every 5 minutes)
    (crontab -u www-data -l 2>/dev/null; echo "*/5 * * * * php -f $NEXTCLOUD_DIR/cron.php") | crontab -u www-data -
    echo -e "${GREEN}✅ Cron job added${NC}"
fi

# Run maintenance tasks
echo ""
echo -e "${YELLOW}Would you like to run maintenance tasks now?${NC}"
echo "  • Update database indices"
echo "  • Convert file cache to BigInt (for large installations)"
echo "  • Clean up file cache"
echo ""
read -p "Run maintenance now? (Y/n): " run_maintenance
run_maintenance=${run_maintenance:-Y}

if [[ $run_maintenance =~ ^[Yy]$ ]]; then
    echo ""
    echo -e "${BLUE}🔧 Running maintenance tasks...${NC}"
    echo ""
    
    echo -e "${CYAN}[1/4] Updating database indices...${NC}"
    sudo -u www-data php "$OCC_CMD" db:add-missing-indices
    
    echo ""
    echo -e "${CYAN}[2/4] Converting filecache to BigInt...${NC}"
    sudo -u www-data php "$OCC_CMD" db:convert-filecache-bigint --no-interaction || echo -e "${YELLOW}Already converted or not needed${NC}"
    
    echo ""
    echo -e "${CYAN}[3/4] Running file scan...${NC}"
    sudo -u www-data php "$OCC_CMD" files:scan --all
    
    echo ""
    echo -e "${CYAN}[4/4] Cleaning up file cache...${NC}"
    sudo -u www-data php "$OCC_CMD" files:cleanup
    
    echo -e "${GREEN}✅ Maintenance tasks completed${NC}"
fi

# Set up preview generation (optional)
echo ""
read -p "Enable preview generation for better performance? (Y/n): " enable_preview
enable_preview=${enable_preview:-Y}

if [[ $enable_preview =~ ^[Yy]$ ]]; then
    echo -e "${BLUE}🔧 Configuring preview generation...${NC}"
    
    sudo -u www-data php "$OCC_CMD" config:app:set previewgenerator squareSizes --value="32 256"
    sudo -u www-data php "$OCC_CMD" config:app:set previewgenerator widthSizes --value="256 384"
    sudo -u www-data php "$OCC_CMD" config:app:set previewgenerator heightSizes --value="256"
    
    echo -e "${GREEN}✅ Preview generation configured${NC}"
    
    # Initial preview generation
    read -p "Generate previews for existing files now? (may take a while) (y/N): " generate_now
    
    if [[ $generate_now =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}⏳ Generating previews... This may take several minutes...${NC}"
        sudo -u www-data php "$OCC_CMD" preview:generate -vvv || echo -e "${YELLOW}Preview generation app might not be installed${NC}"
    fi
fi

echo ""
echo -e "${GREEN}╔═══════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   ✅ Maintenance Setup Complete!      ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════╝${NC}"
echo ""
echo -e "${CYAN}Configuration summary:${NC}"
echo -e "  • Background jobs: ${GREEN}Cron (every 5 minutes)${NC}"
echo -e "  • Cron user: ${GREEN}www-data${NC}"
echo -e "  • Maintenance tasks: ${GREEN}Completed${NC}"
echo ""
echo -e "${YELLOW}💡 Useful maintenance commands:${NC}"
echo -e "   Check cron status:  ${BLUE}sudo -u www-data php $OCC_CMD status${NC}"
echo -e "   Manual cron run:    ${BLUE}sudo -u www-data php $NEXTCLOUD_DIR/cron.php${NC}"
echo -e "   File scan:          ${BLUE}sudo -u www-data php $OCC_CMD files:scan --all${NC}"
echo -e "   Database optimize:  ${BLUE}sudo -u www-data php $OCC_CMD db:add-missing-indices${NC}"
echo -e "   View cron log:      ${BLUE}tail -f $NEXTCLOUD_DIR/data/nextcloud.log${NC}"
echo ""
echo -e "${YELLOW}📄 Cron job installed for www-data:${NC}"
crontab -u www-data -l 2>/dev/null | grep "cron.php" | sed 's/^/   /'
echo ""
echo -e "${BLUE}🧱 Maintenance setup brick is complete!${NC}"
