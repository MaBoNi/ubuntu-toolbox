#!/bin/bash

# 🧱 Initial Server Setup - Submenu
# Interactive menu for setting up a new Ubuntu server

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Repository configuration
REPO_URL="https://raw.githubusercontent.com/MaBoNi/ubuntu-toolbox/main/scripts/setup"
TEMP_DIR="/tmp/ubuntu-toolbox"

# Create temp directory
mkdir -p "$TEMP_DIR"

# Function to display submenu
show_submenu() {
    clear
    echo -e "${BLUE}"
    echo "╔════════════════════════════════════════╗"
    echo "║   🚀 Initial Server Setup Submenu     ║"
    echo "║      'Building your server brick       ║"
    echo "║       by brick!'                       ║"
    echo "╚════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
    echo -e "${GREEN}Setup Building Blocks:${NC}"
    echo ""
    echo "  1) Configure APT Cacher - Speed up package downloads"
    echo "  2) Set Hostname - Configure server name & view IPs"
    echo "  3) Update System - Full system upgrade"
    echo "  4) Configure Timezone - Set server timezone"
    echo "  5) Disable Root SSH - Improve security"
    echo "  6) Enable Auto Updates - Automatic security updates"
    echo "  7) Configure Swap - Setup swap space"
    echo ""
    echo "  8) Run All - Execute complete setup (recommended for new servers)"
    echo ""
    echo "  0) Back to Main Menu"
    echo ""
}

# Function to download and run script
run_setup_script() {
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

# Function to run all setup scripts
run_all_setup() {
    echo -e "${BLUE}"
    echo "╔════════════════════════════════════════╗"
    echo "║   🏗️  Complete Server Setup            ║"
    echo "╚════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
    echo -e "${YELLOW}This will run all setup steps in order:${NC}"
    echo "  1. Configure APT Cacher"
    echo "  2. Update System"
    echo "  3. Configure Timezone"
    echo "  4. Set Hostname"
    echo "  5. Disable Root SSH"
    echo "  6. Enable Auto Updates"
    echo "  7. Configure Swap"
    echo ""
    read -p "Continue with complete setup? (y/N): " confirm
    
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Setup cancelled.${NC}"
        return
    fi
    
    echo ""
    echo -e "${GREEN}🏗️  Starting complete server setup...${NC}"
    echo ""
    
    # Run each script
    echo -e "${CYAN}[Step 1/7] Configuring APT Cacher...${NC}"
    run_setup_script "configure-apt-cacher.sh" || true
    echo ""
    
    echo -e "${CYAN}[Step 2/7] Updating system...${NC}"
    run_setup_script "update-system.sh" || true
    echo ""
    
    echo -e "${CYAN}[Step 3/7] Configuring timezone...${NC}"
    run_setup_script "configure-timezone.sh" || true
    echo ""
    
    echo -e "${CYAN}[Step 4/7] Setting hostname...${NC}"
    run_setup_script "set-hostname.sh" || true
    echo ""
    
    echo -e "${CYAN}[Step 5/7] Disabling root SSH...${NC}"
    run_setup_script "disable-root-ssh.sh" || true
    echo ""
    
    echo -e "${CYAN}[Step 6/7] Enabling auto updates...${NC}"
    run_setup_script "enable-auto-updates.sh" || true
    echo ""
    
    echo -e "${CYAN}[Step 7/7] Configuring swap...${NC}"
    run_setup_script "configure-swap.sh" || true
    echo ""
    
    echo -e "${GREEN}╔════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║   ✅ Complete Setup Finished!          ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${YELLOW}💡 Your server is now configured with basic security and performance settings.${NC}"
    echo -e "${YELLOW}   Consider reviewing the security section for additional hardening.${NC}"
}

# Main submenu loop
while true; do
    show_submenu
    read -p "Select a brick to build (0-8): " choice
    
    case $choice in
        1)
            run_setup_script "configure-apt-cacher.sh"
            ;;
        2)
            run_setup_script "set-hostname.sh"
            ;;
        3)
            run_setup_script "update-system.sh"
            ;;
        4)
            run_setup_script "configure-timezone.sh"
            ;;
        5)
            run_setup_script "disable-root-ssh.sh"
            ;;
        6)
            run_setup_script "enable-auto-updates.sh"
            ;;
        7)
            run_setup_script "configure-swap.sh"
            ;;
        8)
            run_all_setup
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
