#!/bin/bash

# 🧱 NextDNS Installer Brick
# Installs and configures NextDNS for privacy-focused DNS resolution

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════╗${NC}"
echo -e "${BLUE}║   🧱 NextDNS Installer Brick   ║${NC}"
echo -e "${BLUE}╚════════════════════════════════╝${NC}"
echo ""

# Ensure script is running with sudo
if [ "$EUID" -ne 0 ]; then
  echo -e "${YELLOW}⚠️  This script needs to run with sudo. Re-running...${NC}"
  exec sudo "$0" "$@"
fi

# Prompt for NextDNS configuration ID
echo -e "${YELLOW}📝 Please enter your NextDNS configuration ID${NC}"
echo -e "${BLUE}   (You can find this at https://my.nextdns.io)${NC}"
read -p "Configuration ID: " NEXTDNS_CONFIG_ID

if [ -z "$NEXTDNS_CONFIG_ID" ]; then
    echo -e "${RED}❌ Configuration ID is required!${NC}"
    exit 1
fi

# Ensure dependencies
command -v curl >/dev/null 2>&1 || {
  echo -e "${YELLOW}📦 curl is required but not installed. Installing...${NC}"
  apt update && apt install -y curl
}

# Download and install NextDNS
echo ""
echo -e "${BLUE}📦 Installing NextDNS...${NC}"
sh -c "$(curl -sL https://nextdns.io/install)"

# Set configuration
echo ""
echo -e "${BLUE}🔧 Setting configuration ID...${NC}"
nextdns config set -config "$NEXTDNS_CONFIG_ID"

# Ask about query logging
echo ""
read -p "Enable query logging? (y/N): " enable_logging
if [[ $enable_logging =~ ^[Yy]$ ]]; then
    nextdns config set -log-queries true
    echo -e "${GREEN}✅ Query logging enabled${NC}"
else
    nextdns config set -log-queries false
    echo -e "${GREEN}✅ Query logging disabled${NC}"
fi

# Ask about client info reporting
echo ""
read -p "Report client information? (y/N): " report_client
if [[ $report_client =~ ^[Yy]$ ]]; then
    nextdns config set -report-client-info true
    echo -e "${GREEN}✅ Client info reporting enabled${NC}"
else
    echo -e "${GREEN}✅ Client info reporting disabled${NC}"
fi

# Enable and start the service
echo ""
echo -e "${BLUE}🚀 Enabling and starting NextDNS...${NC}"
nextdns install
nextdns start

# Verify
echo ""
echo -e "${GREEN}╔═══════════════════════════════╗${NC}"
echo -e "${GREEN}║   ✅ Installation Complete!   ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}NextDNS Status:${NC}"
nextdns status

echo ""
echo -e "${YELLOW}💡 Tip: Visit https://test.nextdns.io to verify your setup${NC}"
