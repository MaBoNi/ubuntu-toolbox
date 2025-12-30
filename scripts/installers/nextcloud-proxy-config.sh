#!/bin/bash

# 🧱 Nextcloud Proxy Configuration Brick
# Configures Nextcloud to work behind a reverse proxy (Nginx Proxy Manager, etc.)

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   🧱 Nextcloud Proxy Configuration    ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
echo ""

# Ensure script is running with sudo
if [ "$EUID" -ne 0 ]; then
  echo -e "${YELLOW}⚠️  This script needs to run with sudo. Re-running...${NC}"
  exec sudo "$0" "$@"
fi

# Find Nextcloud config
NEXTCLOUD_CONFIG="/var/www/nextcloud/config/config.php"

if [ ! -f "$NEXTCLOUD_CONFIG" ]; then
    echo -e "${RED}❌ Nextcloud config not found at $NEXTCLOUD_CONFIG${NC}"
    echo "Is Nextcloud installed?"
    exit 1
fi

echo -e "${CYAN}This script configures Nextcloud for reverse proxy usage.${NC}"
echo ""

# Get trusted domain
echo -e "${YELLOW}Enter your Nextcloud domain(s):${NC}"
echo "Example: cloud.example.com"
read -p "Domain: " TRUSTED_DOMAIN

if [ -z "$TRUSTED_DOMAIN" ]; then
    echo -e "${RED}❌ Domain is required!${NC}"
    exit 1
fi

# Get proxy IP
echo ""
echo -e "${YELLOW}Enter your reverse proxy IP address:${NC}"
echo "Example: 192.168.1.100"
read -p "Proxy IP: " PROXY_IP

if [ -z "$PROXY_IP" ]; then
    echo -e "${RED}❌ Proxy IP is required!${NC}"
    exit 1
fi

# Ask about overwrite protocol
echo ""
echo -e "${YELLOW}Does your proxy use HTTPS?${NC}"
read -p "Use HTTPS? (Y/n): " use_https
use_https=${use_https:-Y}

echo ""
echo -e "${BLUE}🔧 Backing up config...${NC}"
cp "$NEXTCLOUD_CONFIG" "${NEXTCLOUD_CONFIG}.backup.$(date +%Y%m%d_%H%M%S)"
echo -e "${GREEN}✅ Backup created${NC}"

echo ""
echo -e "${BLUE}🔧 Updating Nextcloud configuration...${NC}"

# Create a temporary PHP script to modify config.php
cat > /tmp/update_nextcloud_config.php <<'PHPSCRIPT'
<?php
$configFile = '/var/www/nextcloud/config/config.php';
$domain = getenv('TRUSTED_DOMAIN');
$proxyIP = getenv('PROXY_IP');
$useHttps = getenv('USE_HTTPS');

// Load existing config
$CONFIG = [];
include $configFile;

// Add trusted domain if not already present
if (!isset($CONFIG['trusted_domains'])) {
    $CONFIG['trusted_domains'] = [0 => 'localhost'];
}

// Add new domain
$domainExists = false;
foreach ($CONFIG['trusted_domains'] as $existingDomain) {
    if ($existingDomain === $domain) {
        $domainExists = true;
        break;
    }
}

if (!$domainExists) {
    $CONFIG['trusted_domains'][] = $domain;
}

// Add trusted proxies
if (!isset($CONFIG['trusted_proxies'])) {
    $CONFIG['trusted_proxies'] = [];
}

if (!in_array($proxyIP, $CONFIG['trusted_proxies'])) {
    $CONFIG['trusted_proxies'][] = $proxyIP;
}

// Configure overwrite settings for HTTPS
if ($useHttps === 'yes') {
    $CONFIG['overwriteprotocol'] = 'https';
    $CONFIG['overwrite.cli.url'] = 'https://' . $domain;
}

$CONFIG['overwritehost'] = $domain;

// Additional proxy headers
$CONFIG['forwarded_for_headers'] = ['HTTP_X_FORWARDED_FOR'];

// Write updated config
$configContent = "<?php\n\$CONFIG = " . var_export($CONFIG, true) . ";\n";
file_put_contents($configFile, $configContent);

echo "Configuration updated successfully!\n";
?>
PHPSCRIPT

# Set environment variables and run PHP script
export TRUSTED_DOMAIN="$TRUSTED_DOMAIN"
export PROXY_IP="$PROXY_IP"
if [[ $use_https =~ ^[Yy]$ ]]; then
    export USE_HTTPS="yes"
else
    export USE_HTTPS="no"
fi

php /tmp/update_nextcloud_config.php
rm /tmp/update_nextcloud_config.php

echo -e "${GREEN}✅ Configuration updated${NC}"

# Fix permissions
echo ""
echo -e "${BLUE}🔧 Setting proper permissions...${NC}"
chown www-data:www-data "$NEXTCLOUD_CONFIG"
chmod 640 "$NEXTCLOUD_CONFIG"

echo ""
echo -e "${GREEN}╔═══════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   ✅ Proxy Configuration Complete!    ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════╝${NC}"
echo ""
echo -e "${CYAN}Configuration summary:${NC}"
echo "  • Trusted domain: ${GREEN}$TRUSTED_DOMAIN${NC}"
echo "  • Trusted proxy: ${GREEN}$PROXY_IP${NC}"
if [[ $use_https =~ ^[Yy]$ ]]; then
    echo "  • Protocol: ${GREEN}HTTPS${NC}"
    echo "  • URL: ${GREEN}https://$TRUSTED_DOMAIN${NC}"
else
    echo "  • Protocol: ${GREEN}HTTP${NC}"
fi
echo ""
echo -e "${YELLOW}💡 Important:${NC}"
echo "  • Clear your browser cache"
echo "  • Configure your reverse proxy to forward these headers:"
echo "    - X-Forwarded-For"
echo "    - X-Forwarded-Proto"
echo "    - X-Forwarded-Host"
echo ""
echo -e "${YELLOW}📄 Config location:${NC}"
echo "   ${BLUE}$NEXTCLOUD_CONFIG${NC}"
echo ""
echo -e "${BLUE}🧱 Nextcloud proxy configuration brick is complete!${NC}"
