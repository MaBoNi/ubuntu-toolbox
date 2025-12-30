#!/bin/bash

# 🧱 Ubuntu Toolbox - Main Launcher
# Downloads and runs scripts from the GitHub repository

set -e

# Colors for LEGO-themed output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Repository configuration
REPO_URL="https://raw.githubusercontent.com/MaBoNi/ubuntu-toolbox/main/scripts"
TEMP_DIR="/tmp/ubuntu-toolbox"

# Create temp directory
mkdir -p "$TEMP_DIR"

# Banner
echo -e "${BLUE}"
echo "╔══════════════════════════════════════╗"
echo "║     🧱 Ubuntu Toolbox 🧱             ║"
echo "║  'Everything is awesome with Linux!' ║"
echo "╚══════════════════════════════════════╝"
echo -e "${NC}"

# Function to display menu
show_menu() {
    echo -e "${GREEN}Available Building Blocks:${NC}"
    echo ""
    echo "  📦 INSTALLERS"
    echo "    1) NextDNS - Privacy-focused DNS resolver"
    echo "    2) Nextcloud - Self-hosted cloud platform"
    echo "    3) Docker - Container platform"
    echo ""
    echo "  🚀 SETUP"
    echo "    4) Set Hostname - Change hostname & view network info"
    echo "    5) Initial Server Setup - Interactive setup menu"
    echo "    6) Firewall Setup - UFW configuration"
    echo ""
    echo "  🔐 SECURITY"
    echo "    7) Import GitHub SSH Keys - Add keys from GitHub user"
    echo "    8) SSH Hardening - Secure SSH configuration"
    echo "    9) Fail2Ban - Intrusion prevention"
    echo ""
    echo "  🔄 MAINTENANCE"
    echo "    10) System Update - Full system upgrade"
    echo "    11) Backup Setup - Automated backup configuration"
    echo ""
    echo "  0) Exit"
    echo ""
}

# Function to download and run script
run_script() {
    local script_path=$1
    local script_name=$(basename "$script_path")
    local local_script="$TEMP_DIR/$script_name"
    
    echo -e "${YELLOW}📥 Downloading $script_name...${NC}"
    
    if curl -fsSL "$REPO_URL/$script_path" -o "$local_script"; then
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

# Main loop
while true; do
    show_menu
    read -p "Select a brick to build (0-11): " choice
    
    case $choice in
        1)
            run_script "installers/nextdns-installer.sh"
            ;;
        2)
            run_script "installers/nextcloud-menu.sh"
            ;;
        3)
            run_script "installers/docker-installer.sh"
            ;;
        4)
            run_script "setup/set-hostname.sh"
            ;;
        5)
            run_script "setup/initial-setup.sh"
            ;;
        6)
            run_script "setup/firewall-setup.sh"
            ;;
        7)
            run_script "security/import-github-ssh-keys.sh"
            ;;
        8)
            run_script "security/ssh-hardening.sh"
            ;;
        9)
            run_script "security/fail2ban-setup.sh"
            ;;
        10)
            run_script "maintenance/system-update.sh"
            ;;
        11)
            run_script "maintenance/backup-setup.sh"
            ;;
        0)
            echo -e "${GREEN}👋 Thanks for using Ubuntu Toolbox!${NC}"
            echo -e "${BLUE}Remember: The best part about LEGO is rebuilding it better!${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}❌ Invalid option. Please try again.${NC}"
            ;;
    esac
    
    echo ""
    echo -e "${YELLOW}Press Enter to continue...${NC}"
    read
    clear
done
