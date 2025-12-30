#!/bin/bash

# 🧱 SSH Hardening Brick
# Applies security best practices to SSH configuration

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   🧱 SSH Hardening Brick          ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════╝${NC}"
echo ""

# Ensure script is running with sudo
if [ "$EUID" -ne 0 ]; then
  echo -e "${YELLOW}⚠️  This script needs to run with sudo. Re-running...${NC}"
  exec sudo "$0" "$@"
fi

SSHD_CONFIG="/etc/ssh/sshd_config"

echo -e "${CYAN}This will apply SSH security hardening:${NC}"
echo "  • Disable root login"
echo "  • Disable password authentication (key-only)"
echo "  • Disable empty passwords"
echo "  • Disable X11 forwarding"
echo "  • Set strong ciphers and MACs"
echo "  • Enable strict mode"
echo "  • Reduce login grace time"
echo "  • Limit authentication attempts"
echo ""
echo -e "${RED}⚠️  IMPORTANT: Make sure you have SSH key access before disabling passwords!${NC}"
echo ""

read -p "Continue with SSH hardening? (y/N): " confirm

if [[ ! $confirm =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Hardening cancelled.${NC}"
    exit 0
fi

echo ""
echo -e "${BLUE}🔧 Backing up SSH config...${NC}"
BACKUP_FILE="${SSHD_CONFIG}.backup.$(date +%Y%m%d_%H%M%S)"
cp "$SSHD_CONFIG" "$BACKUP_FILE"
echo -e "${GREEN}✅ Backup created: $BACKUP_FILE${NC}"

echo ""
echo -e "${BLUE}🔧 Applying hardening settings...${NC}"

# Function to set or update SSH config option
set_ssh_option() {
    local option=$1
    local value=$2
    
    # Remove any existing lines for this option (including commented ones)
    sed -i "/^${option}/d" "$SSHD_CONFIG"
    sed -i "/^#${option}/d" "$SSHD_CONFIG"
    
    # Add the new setting
    echo "${option} ${value}" >> "$SSHD_CONFIG"
}

# Create a new hardened config section
cat >> "$SSHD_CONFIG" <<EOF

# ============================================
# SSH Hardening Configuration
# Applied by ubuntu-toolbox on $(date +%Y-%m-%d)
# ============================================

EOF

# Basic security settings
set_ssh_option "PermitRootLogin" "no"
set_ssh_option "PasswordAuthentication" "no"
set_ssh_option "PermitEmptyPasswords" "no"
set_ssh_option "ChallengeResponseAuthentication" "no"
set_ssh_option "PubkeyAuthentication" "yes"

# Additional hardening
set_ssh_option "X11Forwarding" "no"
set_ssh_option "MaxAuthTries" "3"
set_ssh_option "MaxSessions" "2"
set_ssh_option "LoginGraceTime" "30"
set_ssh_option "ClientAliveInterval" "300"
set_ssh_option "ClientAliveCountMax" "2"
set_ssh_option "StrictModes" "yes"
set_ssh_option "IgnoreRhosts" "yes"
set_ssh_option "HostbasedAuthentication" "no"

# Protocol and crypto settings
set_ssh_option "Protocol" "2"

# Strong ciphers (modern, secure algorithms)
cat >> "$SSHD_CONFIG" <<EOF
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr
MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,hmac-sha2-512,hmac-sha2-256
KexAlgorithms curve25519-sha256,curve25519-sha256@libssh.org,diffie-hellman-group16-sha512,diffie-hellman-group18-sha512,diffie-hellman-group-exchange-sha256
EOF

# Optional: Allow specific users (commented out by default)
cat >> "$SSHD_CONFIG" <<EOF

# Uncomment and configure to limit SSH access to specific users:
# AllowUsers user1 user2

EOF

echo -e "${GREEN}✅ Hardening settings applied${NC}"

echo ""
echo -e "${BLUE}🔧 Testing SSH configuration...${NC}"
if sshd -t; then
    echo -e "${GREEN}✅ SSH configuration is valid${NC}"
else
    echo -e "${RED}❌ SSH configuration has errors! Restoring backup...${NC}"
    cp "$BACKUP_FILE" "$SSHD_CONFIG"
    echo -e "${YELLOW}Backup restored. No changes made.${NC}"
    exit 1
fi

echo ""
echo -e "${BLUE}🔄 Restarting SSH service...${NC}"
systemctl restart sshd || systemctl restart ssh
echo -e "${GREEN}✅ SSH service restarted${NC}"

echo ""
echo -e "${GREEN}╔═══════════════════════════════════╗${NC}"
echo -e "${GREEN}║   ✅ SSH Hardened!                ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════╝${NC}"
echo ""
echo -e "${CYAN}Applied security measures:${NC}"
echo "  ✅ Root login disabled"
echo "  ✅ Password authentication disabled"
echo "  ✅ Public key authentication only"
echo "  ✅ Strong encryption ciphers"
echo "  ✅ Reduced login grace time (30s)"
echo "  ✅ Max 3 authentication attempts"
echo "  ✅ Session timeouts configured"
echo ""
echo -e "${YELLOW}⚠️  Important notes:${NC}"
echo "  • Your current SSH session will remain active"
echo "  • New connections require SSH key authentication"
echo "  • Password login is now disabled"
echo "  • Root cannot login via SSH"
echo ""
echo -e "${YELLOW}💡 To allow specific users only, edit:${NC}"
echo "   ${BLUE}$SSHD_CONFIG${NC}"
echo "   Uncomment and set: ${BLUE}AllowUsers user1 user2${NC}"
echo ""
echo -e "${YELLOW}📄 Config backup saved at:${NC}"
echo "   ${BLUE}$BACKUP_FILE${NC}"
echo ""
echo -e "${BLUE}🧱 SSH hardening brick is complete!${NC}"
