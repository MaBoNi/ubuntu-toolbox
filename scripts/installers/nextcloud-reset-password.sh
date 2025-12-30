#!/bin/bash

# 🧱 Nextcloud Password Reset Brick
# Reset a user's password using occ command

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   🧱 Nextcloud Password Reset         ║${NC}"
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

echo -e "${CYAN}This script resets a Nextcloud user's password.${NC}"
echo ""

# List users
echo -e "${BLUE}📋 Existing Nextcloud users:${NC}"
sudo -u www-data php "$OCC_CMD" user:list | sed 's/^/  • /'
echo ""

# Get username
read -p "Enter username to reset: " USERNAME

if [ -z "$USERNAME" ]; then
    echo -e "${RED}❌ Username is required!${NC}"
    exit 1
fi

# Check if user exists
if ! sudo -u www-data php "$OCC_CMD" user:list | grep -q "^  - $USERNAME:"; then
    echo -e "${RED}❌ User '$USERNAME' does not exist!${NC}"
    exit 1
fi

echo ""
echo -e "${YELLOW}Choose password reset method:${NC}"
echo "  1) Generate random password"
echo "  2) Set custom password"
echo ""
read -p "Select method (1-2): " method

case $method in
    1)
        # Generate random password
        NEW_PASSWORD=$(openssl rand -base64 12)
        echo ""
        echo -e "${BLUE}🔧 Generating random password...${NC}"
        ;;
    2)
        # Custom password
        echo ""
        read -sp "Enter new password: " NEW_PASSWORD
        echo ""
        
        if [ -z "$NEW_PASSWORD" ]; then
            echo -e "${RED}❌ Password cannot be empty!${NC}"
            exit 1
        fi
        
        read -sp "Confirm password: " PASSWORD_CONFIRM
        echo ""
        
        if [ "$NEW_PASSWORD" != "$PASSWORD_CONFIRM" ]; then
            echo -e "${RED}❌ Passwords do not match!${NC}"
            exit 1
        fi
        ;;
    *)
        echo -e "${RED}❌ Invalid selection${NC}"
        exit 1
        ;;
esac

echo ""
echo -e "${BLUE}🔧 Resetting password for user: ${GREEN}$USERNAME${NC}"

# Reset password using occ
if echo "$NEW_PASSWORD" | sudo -u www-data php "$OCC_CMD" user:resetpassword "$USERNAME" --password-from-env; then
    echo ""
    echo -e "${GREEN}╔═══════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║   ✅ Password Reset Successful!       ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${CYAN}User:${NC} ${GREEN}$USERNAME${NC}"
    
    if [ "$method" = "1" ]; then
        echo -e "${CYAN}New password:${NC} ${YELLOW}$NEW_PASSWORD${NC}"
        echo ""
        echo -e "${RED}⚠️  Save this password! It will not be shown again.${NC}"
    else
        echo -e "${GREEN}✅ Custom password has been set${NC}"
    fi
else
    echo ""
    echo -e "${RED}❌ Failed to reset password${NC}"
    exit 1
fi

echo ""
echo -e "${BLUE}🧱 Password reset brick is complete!${NC}"
