#!/bin/bash

# 🧱 Ubuntu Toolbox - Backup Setup Menu
# Choose between Restic and BorgBackup

set -e

# Colors for LEGO-themed output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Repository configuration
REPO_URL="https://raw.githubusercontent.com/MaBoNi/ubuntu-toolbox/main/scripts"
TEMP_DIR="/tmp/ubuntu-toolbox"

# Create temp directory
mkdir -p "$TEMP_DIR"

echo -e "${BLUE}"
echo "╔════════════════════════════════════════╗"
echo "║   🧱 Backup Setup Menu 🧱              ║"
echo "║  'Keep your bricks safe!'              ║"
echo "╚════════════════════════════════════════╝"
echo -e "${NC}"

echo -e "${CYAN}Choose your backup solution:${NC}"
echo ""
echo "  1) 📦 Restic"
echo "     • Fast, secure backups with deduplication"
echo "     • Multiple backends: REST, SFTP, S3, Local"
echo "     • Built-in encryption"
echo "     • Easy to use"
echo ""
echo "  2) 🔐 BorgBackup"
echo "     • Deduplicating backup program"
echo "     • Very efficient compression"
echo "     • Authenticated encryption"
echo "     • Perfect for SSH-based backups"
echo ""
echo "  0) Back to main menu"
echo ""

read -p "Select backup tool (0-2): " choice

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
        return 1
    fi
}

case $choice in
    1)
        run_script "maintenance/restic-backup-setup.sh"
        ;;
    2)
        run_script "maintenance/borg-backup-setup.sh"
        ;;
    0)
        echo -e "${YELLOW}Returning to main menu...${NC}"
        exit 0
        ;;
    *)
        echo -e "${RED}❌ Invalid option${NC}"
        exit 1
        ;;
esac
