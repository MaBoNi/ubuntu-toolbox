#!/bin/bash

# 🧱 Beszel Agent Installer Brick
# Installs Beszel monitoring agent on Ubuntu VMs

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   🧱 Beszel Agent Installer       ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════╝${NC}"
echo ""

# Ensure script is running with sudo
if [ "$EUID" -ne 0 ]; then
  echo -e "${YELLOW}⚠️  This script needs to run with sudo. Re-running...${NC}"
  exec sudo "$0" "$@"
fi

# Default configuration (BondIT DK01-P-BESZEL hub)
# Key and token are generated per-system from the Beszel Hub UI (Add System)
# Update these when the hub is reinstalled or when adding to a new site
DEFAULT_HUB_URL="https://beszel.internal.bondit-dom.net"
DEFAULT_PUBLIC_KEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPtVvengnpj3zbPaaYx5/y1tp7CqQoHla6kFuQzEs3f9"
DEFAULT_TOKEN="78f74db0-5580-4055-b97f-d4ecbab00ab7"
DEFAULT_PORT="45876"

echo -e "${CYAN}Beszel is a lightweight server monitoring agent that:${NC}"
echo "  • Monitors CPU, memory, disk, and network usage"
echo "  • Sends metrics to your Beszel Hub"
echo "  • Runs as a system service (non-root)"
echo "  • Supports automatic updates"
echo ""
echo -e "${CYAN}Hub URL:${NC} ${GREEN}$DEFAULT_HUB_URL${NC}"
echo -e "${CYAN}Port:${NC} ${GREEN}$DEFAULT_PORT${NC}"
echo ""

# Check if already installed
if systemctl is-active --quiet beszel-agent 2>/dev/null; then
    echo -e "${YELLOW}⚠️  Beszel agent is already installed and running.${NC}"
    echo -e "${CYAN}💡 To check agent status:${NC}"
    echo -e "   ${BLUE}sudo systemctl status beszel-agent${NC}"
    echo ""
    read -p "Continue with reinstallation? (y/N): " confirm
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Installation cancelled.${NC}"
        exit 0
    fi
    echo -e "${YELLOW}Stopping existing service...${NC}"
    systemctl stop beszel-agent || true
    echo ""
fi

echo -e "${CYAN}Press Enter to use defaults or type to override:${NC}"
echo ""

# Hub URL
read -p "Hub URL [$DEFAULT_HUB_URL]: " HUB_URL
HUB_URL=${HUB_URL:-$DEFAULT_HUB_URL}

# Port
read -p "Listen Port [$DEFAULT_PORT]: " PORT
PORT=${PORT:-$DEFAULT_PORT}

# Public Key
read -p "Public Key [${DEFAULT_PUBLIC_KEY:0:40}...]: " PUBLIC_KEY
PUBLIC_KEY=${PUBLIC_KEY:-$DEFAULT_PUBLIC_KEY}

# Token
read -p "Token [${DEFAULT_TOKEN:0:20}...]: " TOKEN
TOKEN=${TOKEN:-$DEFAULT_TOKEN}

echo ""
echo -e "${BLUE}📦 Downloading and installing Beszel agent...${NC}"
echo ""

# Download the official installer from get.beszel.dev
TEMP_INSTALLER="/tmp/install-beszel-agent.sh"
if ! curl -sL "https://get.beszel.dev" -o "$TEMP_INSTALLER"; then
    echo -e "${RED}❌ Failed to download installer${NC}"
    exit 1
fi

chmod +x "$TEMP_INSTALLER"

# Run the official installer with all configuration in one go
# -p: port, -k: public key, -t: token, -url: hub URL
echo -e "${BLUE}🔧 Installing and configuring agent...${NC}"
"$TEMP_INSTALLER" -p "$PORT" -k "$PUBLIC_KEY" -t "$TOKEN" -url "$HUB_URL"

# Clean up installer
rm -f "$TEMP_INSTALLER"

echo -e "${GREEN}✅ Installation complete${NC}"

# Wait a moment for service to start
sleep 3

echo ""
if systemctl is-active --quiet beszel-agent; then
    echo -e "${GREEN}╔═══════════════════════════════════╗${NC}"
    echo -e "${GREEN}║   ✅ Beszel Agent Installed!      ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════╝${NC}"
else
    echo -e "${YELLOW}╔═══════════════════════════════════╗${NC}"
    echo -e "${YELLOW}║   ⚠️  Agent may need attention    ║${NC}"
    echo -e "${YELLOW}╚═══════════════════════════════════╝${NC}"
fi

echo ""
echo -e "${CYAN}Configuration summary:${NC}"
echo -e "  Hub URL:     ${BLUE}$HUB_URL${NC}"
echo -e "  Listen Port: ${BLUE}$PORT${NC}"
echo -e "  Public Key:  ${BLUE}${PUBLIC_KEY:0:40}...${NC}"
echo -e "  Token:       ${BLUE}${TOKEN:0:20}...${NC}"
echo ""

# Show service status
systemctl status beszel-agent --no-pager -l | head -n 10

echo ""
echo -e "${YELLOW}💡 Useful commands:${NC}"
echo -e "   Check status:       ${BLUE}sudo systemctl status beszel-agent${NC}"
echo -e "   View logs:          ${BLUE}sudo journalctl -u beszel-agent -f${NC}"
echo -e "   Restart agent:      ${BLUE}sudo systemctl restart beszel-agent${NC}"
echo -e "   Stop agent:         ${BLUE}sudo systemctl stop beszel-agent${NC}"
echo ""
echo -e "${YELLOW}📄 Configuration files:${NC}"
echo -e "   Service file:       ${BLUE}/etc/systemd/system/beszel-agent.service${NC}"
echo -e "   Binary location:    ${BLUE}/opt/beszel-agent/beszel-agent${NC}"
echo ""
echo -e "${YELLOW}🔥 Firewall note:${NC}"
echo -e "   Make sure port ${BLUE}$PORT${NC} is accessible from your Beszel Hub"
echo -e "   To allow through UFW: ${BLUE}sudo ufw allow $PORT/tcp${NC}"
echo ""
echo -e "${CYAN}🌐 Next steps:${NC}"
echo "  1. Verify the agent appears as 'up' in your Beszel Hub"
echo "  2. Check that metrics are being collected"
echo "  3. If needed, configure firewall rules"
echo ""
echo -e "${BLUE}🧱 Beszel agent installation brick is complete!${NC}"
