#!/bin/bash

# 🧱 Nextcloud Video Preview Setup
# Enables video thumbnail generation including MOV files

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   🧱 Video Preview Setup          ║${NC}"
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
NC_DATA_DIR="$NC_DIR/data"

if [ ! -f "$NC_CONFIG" ]; then
    echo -e "${RED}❌ Nextcloud not found at $NC_DIR${NC}"
    echo -e "${YELLOW}Please run the Nextcloud installer first.${NC}"
    exit 1
fi

echo -e "${CYAN}Setting up video preview generation:${NC}"
echo "  • Install FFmpeg for video processing"
echo "  • Configure Nextcloud for video thumbnails"
echo "  • Support for MP4, MOV, AVI, MKV formats"
echo ""

# Step 1: Install FFmpeg
echo -e "${BLUE}📦 Installing FFmpeg...${NC}"
apt update
apt install -y ffmpeg

# Verify installation
if ! command -v ffmpeg &> /dev/null; then
    echo -e "${RED}❌ FFmpeg installation failed${NC}"
    exit 1
fi

FFMPEG_PATH=$(which ffmpeg)
echo -e "${GREEN}✅ FFmpeg installed at: $FFMPEG_PATH${NC}"
echo ""

# Step 2: Backup config.php
echo -e "${BLUE}🔧 Backing up config.php...${NC}"
BACKUP_FILE="${NC_CONFIG}.backup.$(date +%Y%m%d_%H%M%S)"
cp "$NC_CONFIG" "$BACKUP_FILE"
echo -e "${GREEN}✅ Backup created: $BACKUP_FILE${NC}"
echo ""

# Step 3: Configure Nextcloud
echo -e "${BLUE}🔧 Configuring Nextcloud for video previews...${NC}"

# Enable previews
sudo -u www-data php "$NC_OCC" config:system:set enable_previews --value=true --type=boolean

# Set FFmpeg path
sudo -u www-data php "$NC_OCC" config:system:set preview_ffmpeg_path --value="$FFMPEG_PATH"

# Set preview providers
sudo -u www-data php "$NC_OCC" config:system:set enabledPreviewProviders 0 --value='OC\\Preview\\Movie'
sudo -u www-data php "$NC_OCC" config:system:set enabledPreviewProviders 1 --value='OC\\Preview\\MP4'
sudo -u www-data php "$NC_OCC" config:system:set enabledPreviewProviders 2 --value='OC\\Preview\\AVI'
sudo -u www-data php "$NC_OCC" config:system:set enabledPreviewProviders 3 --value='OC\\Preview\\MKV'
sudo -u www-data php "$NC_OCC" config:system:set enabledPreviewProviders 4 --value='OC\\Preview\\PNG'
sudo -u www-data php "$NC_OCC" config:system:set enabledPreviewProviders 5 --value='OC\\Preview\\JPEG'
sudo -u www-data php "$NC_OCC" config:system:set enabledPreviewProviders 6 --value='OC\\Preview\\GIF'
sudo -u www-data php "$NC_OCC" config:system:set enabledPreviewProviders 7 --value='OC\\Preview\\BMP'
sudo -u www-data php "$NC_OCC" config:system:set enabledPreviewProviders 8 --value='OC\\Preview\\XBitmap'
sudo -u www-data php "$NC_OCC" config:system:set enabledPreviewProviders 9 --value='OC\\Preview\\MP3'
sudo -u www-data php "$NC_OCC" config:system:set enabledPreviewProviders 10 --value='OC\\Preview\\TXT'
sudo -u www-data php "$NC_OCC" config:system:set enabledPreviewProviders 11 --value='OC\\Preview\\MarkDown'

# Set preview size limits
sudo -u www-data php "$NC_OCC" config:system:set preview_max_x --value=2048 --type=integer
sudo -u www-data php "$NC_OCC" config:system:set preview_max_y --value=2048 --type=integer

echo -e "${GREEN}✅ Configuration updated${NC}"
echo ""

# Update mimetypes
echo -e "${BLUE}🔧 Updating mimetypes...${NC}"
sudo -u www-data php "$NC_OCC" maintenance:mimetype:update-js
sudo -u www-data php "$NC_OCC" maintenance:mimetype:update-db
echo -e "${GREEN}✅ Mimetypes updated${NC}"
echo ""

echo -e "${GREEN}╔═══════════════════════════════════╗${NC}"
echo -e "${GREEN}║   ✅ Base Setup Complete!         ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════╝${NC}"
echo ""

# Ask about Preview Generator app
echo -e "${CYAN}═══════════════════════════════════════${NC}"
echo -e "${CYAN}📦 Preview Generator App (Optional)${NC}"
echo -e "${CYAN}═══════════════════════════════════════${NC}"
echo ""
echo "The Preview Generator app can pre-generate thumbnails"
echo "for better performance and user experience."
echo ""
read -p "Install Preview Generator app? (Y/n): " install_app
install_app=${install_app:-Y}

if [[ $install_app =~ ^[Yy]$ ]]; then
    echo ""
    echo -e "${BLUE}📦 Installing Preview Generator app...${NC}"
    
    # Check if already installed
    if sudo -u www-data php "$NC_OCC" app:list | grep -q "previewgenerator"; then
        echo -e "${YELLOW}Preview Generator is already installed${NC}"
    else
        sudo -u www-data php "$NC_OCC" app:install previewgenerator
        echo -e "${GREEN}✅ Preview Generator installed${NC}"
    fi
    
    # Enable the app
    sudo -u www-data php "$NC_OCC" app:enable previewgenerator
    echo -e "${GREEN}✅ Preview Generator enabled${NC}"
    echo ""
    
    # Ask about cron job
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo -e "${CYAN}⏰ Automatic Preview Generation${NC}"
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo ""
    echo "Set up a cron job to automatically generate previews?"
    echo ""
    read -p "Setup cron job? (Y/n): " setup_cron
    setup_cron=${setup_cron:-Y}
    
    if [[ $setup_cron =~ ^[Yy]$ ]]; then
        echo ""
        echo "Select frequency for preview generation:"
        echo "  1) Every 10 minutes (recommended)"
        echo "  2) Every 30 minutes"
        echo "  3) Every hour"
        echo "  4) Every 6 hours"
        echo "  5) Daily"
        echo ""
        read -p "Select frequency [1]: " freq_choice
        freq_choice=${freq_choice:-1}
        
        case $freq_choice in
            1)
                CRON_SCHEDULE="*/10 * * * *"
                FREQ_DESC="every 10 minutes"
                ;;
            2)
                CRON_SCHEDULE="*/30 * * * *"
                FREQ_DESC="every 30 minutes"
                ;;
            3)
                CRON_SCHEDULE="0 * * * *"
                FREQ_DESC="every hour"
                ;;
            4)
                CRON_SCHEDULE="0 */6 * * *"
                FREQ_DESC="every 6 hours"
                ;;
            5)
                CRON_SCHEDULE="0 2 * * *"
                FREQ_DESC="daily at 2 AM"
                ;;
            *)
                CRON_SCHEDULE="*/10 * * * *"
                FREQ_DESC="every 10 minutes"
                ;;
        esac
        
        # Add cron job for www-data user
        CRON_CMD="$CRON_SCHEDULE /usr/bin/php $NC_OCC preview:pre-generate > /dev/null 2>&1"
        
        # Check if cron entry already exists
        if crontab -u www-data -l 2>/dev/null | grep -q "preview:pre-generate"; then
            echo -e "${YELLOW}Cron job already exists. Removing old entry...${NC}"
            crontab -u www-data -l 2>/dev/null | grep -v "preview:pre-generate" | crontab -u www-data -
        fi
        
        # Add new cron entry
        (crontab -u www-data -l 2>/dev/null; echo "$CRON_CMD") | crontab -u www-data -
        
        echo -e "${GREEN}✅ Cron job configured to run $FREQ_DESC${NC}"
        echo ""
    fi
    
    # Ask about running preview generation now
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo -e "${CYAN}🚀 Generate Previews Now${NC}"
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo ""
    echo "Generate previews for existing files now?"
    echo -e "${YELLOW}⚠️  This may take a while for large libraries${NC}"
    echo ""
    read -p "Start preview generation? (y/N): " generate_now
    
    if [[ $generate_now =~ ^[Yy]$ ]]; then
        echo ""
        echo -e "${BLUE}🎬 Generating previews for all files...${NC}"
        echo -e "${YELLOW}This will run in the background. You can monitor progress with:${NC}"
        echo -e "   ${BLUE}sudo -u www-data php $NC_OCC preview:generate-all -vvv${NC}"
        echo ""
        
        # Run in background
        sudo -u www-data php "$NC_OCC" preview:generate-all > /tmp/nextcloud-preview-generation.log 2>&1 &
        
        echo -e "${GREEN}✅ Preview generation started in background${NC}"
        echo -e "${CYAN}Log file: /tmp/nextcloud-preview-generation.log${NC}"
        echo ""
    fi
fi

echo ""
echo -e "${GREEN}╔═══════════════════════════════════╗${NC}"
echo -e "${GREEN}║   ✅ Video Previews Configured!   ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════╝${NC}"
echo ""
echo -e "${CYAN}Summary:${NC}"
echo -e "  ✅ FFmpeg installed: ${BLUE}$FFMPEG_PATH${NC}"
echo -e "  ✅ Video formats: ${BLUE}MP4, MOV, AVI, MKV${NC}"
echo -e "  ✅ Nextcloud configured for video previews"
if [[ $install_app =~ ^[Yy]$ ]]; then
    echo -e "  ✅ Preview Generator app installed"
    if [[ $setup_cron =~ ^[Yy]$ ]]; then
        echo -e "  ✅ Cron job configured: ${BLUE}$FREQ_DESC${NC}"
    fi
fi
echo ""
echo -e "${YELLOW}💡 Useful commands:${NC}"
echo -e "   Generate all previews:    ${BLUE}sudo -u www-data php $NC_OCC preview:generate-all${NC}"
echo -e "   Clear preview cache:      ${BLUE}sudo -u www-data php $NC_OCC preview:reset-rendered-texts${NC}"
echo -e "   Check app status:         ${BLUE}sudo -u www-data php $NC_OCC app:list | grep preview${NC}"
echo ""
echo -e "${YELLOW}📄 Config backup:${NC}"
echo -e "   ${BLUE}$BACKUP_FILE${NC}"
echo ""
echo -e "${BLUE}🧱 Video preview setup brick is complete!${NC}"
