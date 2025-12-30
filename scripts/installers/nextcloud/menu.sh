#!/bin/bash

# 🧱 Nextcloud Menu - Submenu
# Interactive menu for Nextcloud installation and configuration

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Repository configuration
REPO_URL="https://raw.githubusercontent.com/MaBoNi/ubuntu-toolbox/main/scripts/installers/nextcloud"
TEMP_DIR="/tmp/ubuntu-toolbox"

# Create temp directory
mkdir -p "$TEMP_DIR"

# Function to display submenu
show_submenu() {
    clear
    echo -e "${BLUE}"
    echo "╔════════════════════════════════════════╗"
    echo "║   🧱 Nextcloud Installation Menu      ║"
    echo "║      'Build your cloud brick           ║"
    echo "║       by brick!'                       ║"
    echo "╚════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
    echo -e "${GREEN}Nextcloud Building Blocks:${NC}"
    echo ""
    echo "  1) Install Nextcloud - Complete LAMP stack + Nextcloud"
    echo "  2) Configure for Reverse Proxy - Set up trusted domains & proxies"
    echo "  3) Reset User Password - Reset any user's password"
    echo "  4) Setup Maintenance - Configure cron jobs & optimization"
    echo ""
    echo "  0) Back to Main Menu"
    echo ""
}

# Function to download and run script
run_nextcloud_script() {
    local script_name=$1
    local local_script="$TEMP_DIR/$script_name"
    
    echo -e "${YELLOW}📥 Downloading $script_name...${NC}"
    
    if curl -fsSL "$REPO_URL/$script_name" -o "$local_script"; then
        chmod +x "$local_script"
        echo -e "${GREEN}✅ Downloaded successfully!${NC}"
        echo -e "${BLUE}🔧 Running $script_name...${NC}"
        echo ""
        
        # Run the script
        bash "$local_script"
        
        # Clean up
        rm -f "$local_script"
    else
        echo -e "${RED}❌ Failed to download $script_name${NC}"
        echo "The script might not exist yet in the repository."
        return 1
    fi
}

# Main submenu loop
while true; do
    show_submenu
    read -p "Select a brick to build (0-4): " choice
    
    case $choice in
        1)
            run_nextcloud_script "install.sh"
            ;;
        2)
            run_nextcloud_script "proxy-config.sh"
            ;;
        3)
            run_nextcloud_script "reset-password.sh"
            ;;
        4)
            run_nextcloud_script "maintenance.sh"
            ;;
        0)
            echo -e "${GREEN}👋 Returning to main menu...${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}❌ Invalid option. Please try again.${NC}"
            ;;
    esac
    
    echo ""
    echo -e "${YELLOW}Press Enter to continue...${NC}"
    read
done
