#!/bin/bash

# 🧱 Import GitHub SSH Keys Brick
# Imports SSH public keys from a GitHub username

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   🧱 Import GitHub SSH Keys       ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════╝${NC}"
echo ""

echo -e "${CYAN}This script imports SSH public keys from a GitHub user account.${NC}"
echo -e "${YELLOW}Keys will be added to ~/.ssh/authorized_keys${NC}"
echo ""

# Get target user
read -p "Import keys for which user? [$(whoami)]: " TARGET_USER
TARGET_USER=${TARGET_USER:-$(whoami)}

# Validate user exists
if ! id "$TARGET_USER" &>/dev/null; then
    echo -e "${RED}❌ User $TARGET_USER does not exist!${NC}"
    exit 1
fi

# Get user's home directory
TARGET_HOME=$(eval echo ~$TARGET_USER)
SSH_DIR="$TARGET_HOME/.ssh"
AUTH_KEYS="$SSH_DIR/authorized_keys"

echo -e "${CYAN}Target user:${NC} ${GREEN}$TARGET_USER${NC}"
echo -e "${CYAN}SSH directory:${NC} ${GREEN}$SSH_DIR${NC}"
echo ""

# Get GitHub username
read -p "Enter GitHub username: " GITHUB_USER

if [ -z "$GITHUB_USER" ]; then
    echo -e "${RED}❌ GitHub username is required!${NC}"
    exit 1
fi

echo ""
echo -e "${BLUE}🔍 Fetching SSH keys for GitHub user: ${GREEN}$GITHUB_USER${NC}"

# Fetch keys from GitHub
GITHUB_KEYS_URL="https://github.com/$GITHUB_USER.keys"
TEMP_KEYS=$(mktemp)

if ! curl -fsSL "$GITHUB_KEYS_URL" -o "$TEMP_KEYS"; then
    echo -e "${RED}❌ Failed to fetch keys from GitHub${NC}"
    echo "Check that the username is correct and the user has public SSH keys."
    rm -f "$TEMP_KEYS"
    exit 1
fi

# Check if any keys were found
if [ ! -s "$TEMP_KEYS" ]; then
    echo -e "${YELLOW}⚠️  No SSH keys found for user $GITHUB_USER${NC}"
    rm -f "$TEMP_KEYS"
    exit 1
fi

# Count keys
KEY_COUNT=$(wc -l < "$TEMP_KEYS")
echo -e "${GREEN}✅ Found $KEY_COUNT SSH key(s)${NC}"
echo ""

# Show keys preview
echo -e "${CYAN}Keys to import:${NC}"
while IFS= read -r key; do
    KEY_TYPE=$(echo "$key" | awk '{print $1}')
    KEY_FINGERPRINT=$(echo "$key" | awk '{print $2}' | cut -c1-20)
    echo "  • ${KEY_TYPE} ${KEY_FINGERPRINT}..."
done < "$TEMP_KEYS"
echo ""

# Confirm import
read -p "Import these keys? (y/N): " confirm

if [[ ! $confirm =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Import cancelled.${NC}"
    rm -f "$TEMP_KEYS"
    exit 0
fi

echo ""
echo -e "${BLUE}🔧 Setting up SSH directory...${NC}"

# Need sudo for other users
if [ "$TARGET_USER" != "$(whoami)" ] && [ "$EUID" -ne 0 ]; then
    echo -e "${YELLOW}⚠️  Need sudo to modify another user's SSH keys. Re-running with sudo...${NC}"
    exec sudo "$0" "$@"
fi

# Create .ssh directory if it doesn't exist
if [ "$TARGET_USER" == "$(whoami)" ]; then
    mkdir -p "$SSH_DIR"
    touch "$AUTH_KEYS"
    chmod 700 "$SSH_DIR"
    chmod 600 "$AUTH_KEYS"
else
    sudo -u "$TARGET_USER" mkdir -p "$SSH_DIR"
    sudo -u "$TARGET_USER" touch "$AUTH_KEYS"
    sudo chmod 700 "$SSH_DIR"
    sudo chmod 600 "$AUTH_KEYS"
fi

echo -e "${GREEN}✅ SSH directory ready${NC}"

echo ""
echo -e "${BLUE}🔧 Importing keys...${NC}"

# Backup existing authorized_keys
if [ -f "$AUTH_KEYS" ] && [ -s "$AUTH_KEYS" ]; then
    BACKUP_FILE="${AUTH_KEYS}.backup.$(date +%Y%m%d_%H%M%S)"
    cp "$AUTH_KEYS" "$BACKUP_FILE"
    echo -e "${YELLOW}📄 Backed up existing keys to: $BACKUP_FILE${NC}"
fi

# Add keys with a comment
echo "" >> "$AUTH_KEYS"
echo "# GitHub keys for $GITHUB_USER (imported $(date +%Y-%m-%d))" >> "$AUTH_KEYS"

# Check for duplicates and add keys
ADDED_COUNT=0
SKIPPED_COUNT=0

while IFS= read -r key; do
    if grep -qF "$key" "$AUTH_KEYS"; then
        echo -e "${YELLOW}⏭️  Key already exists, skipping${NC}"
        SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
    else
        echo "$key" >> "$AUTH_KEYS"
        ADDED_COUNT=$((ADDED_COUNT + 1))
    fi
done < "$TEMP_KEYS"

# Fix ownership if we're root modifying another user's files
if [ "$TARGET_USER" != "$(whoami)" ]; then
    chown -R "$TARGET_USER:$TARGET_USER" "$SSH_DIR"
fi

# Clean up
rm -f "$TEMP_KEYS"

echo ""
echo -e "${GREEN}╔═══════════════════════════════════╗${NC}"
echo -e "${GREEN}║   ✅ SSH Keys Imported!           ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════╝${NC}"
echo ""
echo -e "${CYAN}Summary:${NC}"
echo "  • GitHub user: ${GREEN}$GITHUB_USER${NC}"
echo "  • Target user: ${GREEN}$TARGET_USER${NC}"
echo "  • Keys added: ${GREEN}$ADDED_COUNT${NC}"
echo "  • Keys skipped (duplicates): ${YELLOW}$SKIPPED_COUNT${NC}"
echo ""
echo -e "${YELLOW}💡 Test your SSH connection:${NC}"
echo "   ${BLUE}ssh $TARGET_USER@$(hostname)${NC}"
echo ""
echo -e "${BLUE}🧱 SSH keys import brick is complete!${NC}"
