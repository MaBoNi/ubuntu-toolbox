#!/bin/bash

# 🧱 APT Cacher Configuration Brick
# Configures apt-cacher-ng proxy for faster package downloads

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   🧱 APT Cacher Configuration     ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════╝${NC}"
echo ""

# Ensure script is running with sudo
if [ "$EUID" -ne 0 ]; then
  echo -e "${YELLOW}⚠️  This script needs to run with sudo. Re-running...${NC}"
  exec sudo "$0" "$@"
fi

# Ensure netcat is installed
if ! command -v nc >/dev/null 2>&1; then
  echo -e "${YELLOW}📦 netcat (nc) is not installed. Installing now...${NC}"
  apt update && apt install -y netcat-openbsd
  echo -e "${GREEN}✅ netcat installed${NC}"
  echo ""
fi

# Default APT cacher IP
DEFAULT_IP="192.168.5.200"

echo -e "${CYAN}APT Cacher Configuration${NC}"
echo -e "${YELLOW}This will configure your system to use an apt-cacher-ng proxy server${NC}"
echo -e "${YELLOW}for faster package downloads and reduced bandwidth usage.${NC}"
echo ""

read -p "Enter apt-cacher-ng IP [${DEFAULT_IP}]: " APT_CACHER_IP
APT_CACHER_IP="${APT_CACHER_IP:-$DEFAULT_IP}"

echo ""
echo -e "${BLUE}🔧 Using apt-cacher-ng at: ${GREEN}${APT_CACHER_IP}${NC}"
echo ""

# Test connection first
echo -e "${CYAN}Testing connection to apt-cacher-ng...${NC}"
if nc -w2 -z "$APT_CACHER_IP" 3142; then
    echo -e "${GREEN}✅ Connection successful!${NC}"
else
    echo -e "${YELLOW}⚠️  Warning: Cannot connect to $APT_CACHER_IP:3142${NC}"
    echo -e "${YELLOW}   The configuration will be created anyway, but may not work until the server is reachable.${NC}"
fi
echo ""

# ========== File 1: Proxy detection script ==========
PROXY_SCRIPT="/usr/local/bin/apt-proxy-detect.sh"

if [ -f "$PROXY_SCRIPT" ]; then
  echo -e "${YELLOW}⚠️  $PROXY_SCRIPT already exists.${NC}"
  head -n 3 "$PROXY_SCRIPT"
  read -p "Do you want to overwrite it? [Y/n]: " OVERWRITE_SCRIPT
  OVERWRITE_SCRIPT="${OVERWRITE_SCRIPT:-Y}"
  if [[ "$OVERWRITE_SCRIPT" =~ ^[Yy]$ ]]; then
    echo -e "${BLUE}📄 Overwriting $PROXY_SCRIPT...${NC}"
    cat > "$PROXY_SCRIPT" <<EOF
#!/bin/bash
if nc -w1 -z "$APT_CACHER_IP" 3142; then
  echo -n "http://$APT_CACHER_IP:3142"
else
  echo -n "DIRECT"
fi
EOF
    chmod +x "$PROXY_SCRIPT"
    echo -e "${GREEN}✅ Script updated${NC}"
  else
    echo -e "${YELLOW}⏭️  Skipping $PROXY_SCRIPT${NC}"
  fi
else
  echo -e "${BLUE}📄 Creating $PROXY_SCRIPT...${NC}"
  cat > "$PROXY_SCRIPT" <<EOF
#!/bin/bash
if nc -w1 -z "$APT_CACHER_IP" 3142; then
  echo -n "http://$APT_CACHER_IP:3142"
else
  echo -n "DIRECT"
fi
EOF
  chmod +x "$PROXY_SCRIPT"
  echo -e "${GREEN}✅ Script created${NC}"
fi

echo ""

# ========== File 2: APT config ==========
APT_CONF="/etc/apt/apt.conf.d/00aptproxy"

if [ -f "$APT_CONF" ]; then
  echo -e "${YELLOW}⚠️  $APT_CONF already exists.${NC}"
  head -n 3 "$APT_CONF"
  read -p "Do you want to overwrite it? [Y/n]: " OVERWRITE_CONF
  OVERWRITE_CONF="${OVERWRITE_CONF:-Y}"
  if [[ "$OVERWRITE_CONF" =~ ^[Yy]$ ]]; then
    echo -e "${BLUE}📄 Overwriting $APT_CONF...${NC}"
    cat > "$APT_CONF" <<EOF
Acquire::http::Proxy-Auto-Detect "$PROXY_SCRIPT";
EOF
    echo -e "${GREEN}✅ APT config updated${NC}"
  else
    echo -e "${YELLOW}⏭️  Skipping $APT_CONF${NC}"
  fi
else
  echo -e "${BLUE}📄 Creating $APT_CONF...${NC}"
  cat > "$APT_CONF" <<EOF
Acquire::http::Proxy-Auto-Detect "$PROXY_SCRIPT";
EOF
  echo -e "${GREEN}✅ APT config created${NC}"
fi

# ========== Done ==========
echo ""
echo -e "${GREEN}╔═══════════════════════════════════╗${NC}"
echo -e "${GREEN}║   ✅ Configuration Complete!      ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════╝${NC}"
echo ""
echo -e "${CYAN}What was configured:${NC}"
echo -e "  • Proxy detection script: ${GREEN}$PROXY_SCRIPT${NC}"
echo -e "  • APT configuration: ${GREEN}$APT_CONF${NC}"
echo -e "  • Proxy server: ${GREEN}http://$APT_CACHER_IP:3142${NC}"
echo ""
echo -e "${YELLOW}💡 Test your configuration:${NC}"
echo -e "   ${BLUE}$PROXY_SCRIPT${NC}   (should show proxy URL or DIRECT)"
echo -e "   ${BLUE}sudo apt update${NC}   (should use the cache if available)"
echo ""
echo -e "${CYAN}ℹ️  How it works:${NC}"
echo "   APT will automatically detect if the cache server is available."
echo "   If reachable, packages are fetched through the cache (faster!)."
echo "   If not reachable, APT falls back to direct download (no interruption)."
echo ""
echo -e "${BLUE}🧱 APT cacher brick is built!${NC}"
