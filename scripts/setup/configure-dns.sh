#!/bin/bash

# 🧱 DNS Configuration Brick
# Configures DNS to use BondIT AdGuard Home (internal) with fallback

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   🧱 DNS Configuration             ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════╝${NC}"
echo ""

# Ensure script is running with sudo
if [ "$EUID" -ne 0 ]; then
  echo -e "${YELLOW}⚠️  This script needs to run with sudo. Re-running...${NC}"
  exec sudo "$0" "$@"
fi

# Defaults
DEFAULT_PRIMARY_DNS="10.20.40.10"
DEFAULT_FALLBACK_DNS="1.1.1.1"

echo -e "${CYAN}DNS Configuration${NC}"
echo -e "${YELLOW}This will configure your system to use the BondIT AdGuard Home DNS server${NC}"
echo -e "${YELLOW}with a fallback to Cloudflare (1.1.1.1) if the internal DNS is unreachable.${NC}"
echo ""

read -p "Enter primary DNS IP (AdGuard Home) [${DEFAULT_PRIMARY_DNS}]: " PRIMARY_DNS
PRIMARY_DNS="${PRIMARY_DNS:-$DEFAULT_PRIMARY_DNS}"

read -p "Enter fallback DNS IP [${DEFAULT_FALLBACK_DNS}]: " FALLBACK_DNS
FALLBACK_DNS="${FALLBACK_DNS:-$DEFAULT_FALLBACK_DNS}"

echo ""
echo -e "${BLUE}🔧 Primary DNS:  ${GREEN}${PRIMARY_DNS}${NC}"
echo -e "${BLUE}🔧 Fallback DNS: ${GREEN}${FALLBACK_DNS}${NC}"
echo ""

# Test connection to primary DNS
echo -e "${CYAN}Testing connection to DNS server...${NC}"
if nc -w2 -z "$PRIMARY_DNS" 53 2>/dev/null || curl -s --connect-timeout 2 "http://${PRIMARY_DNS}" -o /dev/null 2>/dev/null; then
    echo -e "${GREEN}✅ Primary DNS is reachable!${NC}"
else
    echo -e "${YELLOW}⚠️  Warning: Cannot reach $PRIMARY_DNS:53${NC}"
    echo -e "${YELLOW}   Configuration will be applied anyway - server must be on VLAN 40.${NC}"
fi
echo ""

# Detect DNS management method
if systemctl is-active --quiet systemd-resolved 2>/dev/null; then
    # Use systemd-resolved
    DNS_METHOD="systemd-resolved"
elif [ -f /etc/netplan ]; then
    DNS_METHOD="netplan"
else
    DNS_METHOD="resolv.conf"
fi

echo -e "${CYAN}Detected DNS management: ${YELLOW}${DNS_METHOD}${NC}"
echo ""

case "$DNS_METHOD" in
    systemd-resolved)
        echo -e "${BLUE}📄 Configuring systemd-resolved...${NC}"
        RESOLVED_CONF="/etc/systemd/resolved.conf.d/bondit-dns.conf"
        mkdir -p /etc/systemd/resolved.conf.d
        cat > "$RESOLVED_CONF" <<EOF
# BondIT DNS Configuration
# Managed by ubuntu-toolbox configure-dns.sh
[Resolve]
DNS=${PRIMARY_DNS}
FallbackDNS=${FALLBACK_DNS}
Domains=bondit-dom.net
EOF
        systemctl restart systemd-resolved
        echo -e "${GREEN}✅ systemd-resolved configured${NC}"
        ;;

    resolv.conf)
        echo -e "${BLUE}📄 Configuring /etc/resolv.conf...${NC}"
        # Backup existing
        cp /etc/resolv.conf /etc/resolv.conf.backup.$(date +%Y%m%d_%H%M%S) 2>/dev/null || true
        # Remove immutable flag if set
        chattr -i /etc/resolv.conf 2>/dev/null || true
        cat > /etc/resolv.conf <<EOF
# BondIT DNS Configuration
# Managed by ubuntu-toolbox configure-dns.sh
nameserver ${PRIMARY_DNS}
nameserver ${FALLBACK_DNS}
search bondit-dom.net
EOF
        echo -e "${GREEN}✅ /etc/resolv.conf configured${NC}"
        ;;
esac

echo ""

# Verify DNS resolution
echo -e "${CYAN}Verifying DNS resolution...${NC}"
sleep 1

# Test internal domain
if nslookup adguard.internal.bondit-dom.net "$PRIMARY_DNS" >/dev/null 2>&1; then
    ADGUARD_IP=$(nslookup adguard.internal.bondit-dom.net "$PRIMARY_DNS" 2>/dev/null | awk '/^Address: / { print $2 }' | head -1)
    echo -e "${GREEN}✅ Internal DNS working: adguard.internal.bondit-dom.net → ${ADGUARD_IP}${NC}"
else
    echo -e "${YELLOW}⚠️  Internal DNS lookup failed - server may not be on VLAN 40 yet${NC}"
fi

# Test external domain
if nslookup google.com "$PRIMARY_DNS" >/dev/null 2>&1; then
    echo -e "${GREEN}✅ External DNS working: google.com resolves correctly${NC}"
else
    echo -e "${YELLOW}⚠️  External DNS lookup failed - check AdGuard upstream${NC}"
fi

echo ""
echo -e "${GREEN}╔════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   ✅ DNS Configuration Complete!   ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════╝${NC}"
echo ""
echo -e "${CYAN}What was configured:${NC}"
echo -e "  • Primary DNS:  ${GREEN}${PRIMARY_DNS}${NC} (BondIT AdGuard Home)"
echo -e "  • Fallback DNS: ${GREEN}${FALLBACK_DNS}${NC}"
echo -e "  • Search domain: ${GREEN}bondit-dom.net${NC}"
echo ""
echo -e "${YELLOW}💡 Internal services are now resolvable:${NC}"
echo -e "   ${BLUE}adguard.internal.bondit-dom.net${NC}   → AdGuard UI"
echo -e "   ${BLUE}proxmox.internal.bondit-dom.net${NC}   → Proxmox UI"
echo -e "   ${BLUE}aptcache.internal.bondit-dom.net${NC}  → APT Cache UI"
echo ""
echo -e "${BLUE}🧱 DNS brick is built!${NC}"
