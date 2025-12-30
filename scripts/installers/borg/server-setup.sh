#!/bin/bash

# 🧱 Ubuntu Toolbox - BorgBackup Server Setup
# Sets up a BorgBackup server with SSH access

set -e

# Colors for LEGO-themed output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo -e "${YELLOW}🔧 This script needs sudo privileges. Elevating...${NC}"
   exec sudo "$0" "$@"
fi

echo -e "${BLUE}"
echo "╔════════════════════════════════════════╗"
echo "║   🧱 BorgBackup Server Setup 🧱        ║"
echo "║  'Build secure, efficient backups!'    ║"
echo "╚════════════════════════════════════════╝"
echo -e "${NC}"

echo -e "${CYAN}This script will set up a BorgBackup server with:${NC}"
echo -e "  • Dedicated borg user account"
echo -e "  • SSH key-based authentication"
echo -e "  • Restricted shell access (append-only option)"
echo -e "  • Secure storage directory"
echo ""

read -p "Continue with installation? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Installation cancelled.${NC}"
    exit 0
fi

echo -e "${BLUE}📦 Installing BorgBackup...${NC}"
apt-get update
apt-get install -y borgbackup

echo -e "${GREEN}✅ BorgBackup installed: $(borg --version)${NC}"

# Get storage path
echo ""
echo -e "${YELLOW}Configure backup storage:${NC}"
read -p "Enter backup storage path [/var/backups/borg]: " STORAGE_PATH
STORAGE_PATH=${STORAGE_PATH:-/var/backups/borg}

# Create borg user if it doesn't exist
if id "borg" &>/dev/null; then
    echo -e "${YELLOW}⚠️  User 'borg' already exists${NC}"
else
    echo -e "${BLUE}👤 Creating borg user...${NC}"
    useradd --system --shell /bin/bash --create-home --home-dir /home/borg borg
    echo -e "${GREEN}✅ User 'borg' created${NC}"
fi

# Create storage directory
echo -e "${BLUE}📁 Creating storage directory...${NC}"
mkdir -p "$STORAGE_PATH"
chown borg:borg "$STORAGE_PATH"
chmod 700 "$STORAGE_PATH"

# Set up SSH directory
echo -e "${BLUE}🔑 Setting up SSH access...${NC}"
mkdir -p /home/borg/.ssh
touch /home/borg/.ssh/authorized_keys
chmod 700 /home/borg/.ssh
chmod 600 /home/borg/.ssh/authorized_keys
chown -R borg:borg /home/borg/.ssh

# Ask for SSH key
echo ""
echo -e "${YELLOW}SSH Key Configuration:${NC}"
echo "You need to add the client's SSH public key to allow access."
echo ""
echo "Options:"
echo "  1) Paste SSH public key now"
echo "  2) Import from a file"
echo "  3) Skip (add manually later to /home/borg/.ssh/authorized_keys)"
echo ""
read -p "Select option [1-3]: " ssh_option

case $ssh_option in
    1)
        echo -e "${YELLOW}Paste the SSH public key (press Enter, then Ctrl+D when done):${NC}"
        cat >> /home/borg/.ssh/authorized_keys
        echo -e "${GREEN}✅ SSH key added${NC}"
        ;;
    2)
        read -p "Enter path to public key file: " key_file
        if [[ -f "$key_file" ]]; then
            cat "$key_file" >> /home/borg/.ssh/authorized_keys
            echo -e "${GREEN}✅ SSH key imported${NC}"
        else
            echo -e "${RED}❌ File not found${NC}"
        fi
        ;;
    3)
        echo -e "${YELLOW}⚠️  Remember to add SSH key manually to /home/borg/.ssh/authorized_keys${NC}"
        ;;
esac

# Ask about append-only mode
echo ""
echo -e "${YELLOW}Security Options:${NC}"
echo "Append-only mode prevents clients from deleting backups (protects against ransomware)."
read -p "Enable append-only mode? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    # Configure restricted SSH command
    echo -e "${BLUE}🔒 Configuring append-only mode...${NC}"
    
    # Backup authorized_keys if it has content
    if [[ -s /home/borg/.ssh/authorized_keys ]]; then
        cp /home/borg/.ssh/authorized_keys /home/borg/.ssh/authorized_keys.tmp
        
        # Add borg serve command restriction to each key
        sed -i 's|^ssh-|command="borg serve --append-only --restrict-to-path '"$STORAGE_PATH"'",restrict ssh-|' /home/borg/.ssh/authorized_keys
        
        echo -e "${GREEN}✅ Append-only mode enabled${NC}"
        echo -e "${CYAN}Note: Clients can create backups but cannot delete them via SSH${NC}"
    else
        echo -e "${YELLOW}⚠️  No SSH keys configured yet. Add this prefix to keys manually:${NC}"
        echo -e "${CYAN}command=\"borg serve --append-only --restrict-to-path $STORAGE_PATH\",restrict${NC}"
    fi
else
    # Regular mode with path restriction
    if [[ -s /home/borg/.ssh/authorized_keys ]]; then
        cp /home/borg/.ssh/authorized_keys /home/borg/.ssh/authorized_keys.tmp
        sed -i 's|^ssh-|command="borg serve --restrict-to-path '"$STORAGE_PATH"'",restrict ssh-|' /home/borg/.ssh/authorized_keys
        echo -e "${GREEN}✅ Path restriction enabled${NC}"
    fi
fi

# Get server hostname/IP
HOSTNAME=$(hostname -f 2>/dev/null || hostname)
IP_ADDR=$(hostname -I | awk '{print $1}')

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║          🎉 BorgBackup Server Setup Complete! 🎉          ║${NC}"
echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo ""
echo -e "${CYAN}📋 Server Configuration:${NC}"
echo -e "  Storage Path:     $STORAGE_PATH"
echo -e "  SSH User:         borg"
echo -e "  Server Address:   $HOSTNAME ($IP_ADDR)"
echo ""
echo -e "${CYAN}📝 Client Connection:${NC}"
echo -e "  Repository URL:   borg@$HOSTNAME:$STORAGE_PATH/backup-name"
echo -e "  Or using IP:      borg@$IP_ADDR:$STORAGE_PATH/backup-name"
echo ""
echo -e "${CYAN}🔑 Next Steps:${NC}"
echo -e "  1. If you haven't added SSH keys yet, edit: /home/borg/.ssh/authorized_keys"
echo -e "  2. Use the 'Backup Setup' tool on client machines to configure backups"
echo -e "  3. Ensure SSH port is open in your firewall"
echo ""
echo -e "${YELLOW}💡 Tip: Each client can have its own subdirectory in $STORAGE_PATH${NC}"
echo ""
