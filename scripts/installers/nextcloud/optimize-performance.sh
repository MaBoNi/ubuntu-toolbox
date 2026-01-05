#!/bin/bash

# 🧱 Nextcloud Performance Optimization
# Install and configure Redis for memcache and file locking

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   🧱 Performance Optimization      ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════╝${NC}"
echo ""

# Ensure script is running with sudo
if [ "$EUID" -ne 0 ]; then
  echo -e "${YELLOW}⚠️  This script needs to run with sudo. Re-running...${NC}"
  exec sudo "$0" "$@"
fi

# Detect Nextcloud installation
NC_DIR="/var/www/nextcloud"
NC_CONFIG="$NC_DIR/config/config.php"
NC_OCC="$NC_DIR/occ"

if [ ! -f "$NC_CONFIG" ]; then
    echo -e "${RED}❌ Nextcloud not found at $NC_DIR${NC}"
    echo -e "${YELLOW}Please run the Nextcloud installer first.${NC}"
    exit 1
fi

echo -e "${CYAN}About Redis:${NC}"
echo "  • In-memory cache for faster file operations"
echo "  • Reduces database load significantly"
echo "  • Handles file locking efficiently"
echo "  • Lightweight (~10-50MB RAM usage)"
echo ""
echo -e "${YELLOW}This will significantly improve Nextcloud performance!${NC}"
echo ""
read -p "Continue? (Y/n): " continue_install
continue_install=${continue_install:-Y}

if [[ ! $continue_install =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Cancelled.${NC}"
    exit 0
fi

echo ""
echo -e "${BLUE}═══════════════════════════════════════${NC}"
echo -e "${BLUE}1️⃣  Installing Redis${NC}"
echo -e "${BLUE}═══════════════════════════════════════${NC}"
echo ""

# Install Redis
echo -e "${CYAN}Installing Redis server and PHP extension...${NC}"
apt update
apt install -y redis-server php-redis

# Configure Redis for better performance
echo -e "${CYAN}Configuring Redis...${NC}"
REDIS_CONF="/etc/redis/redis.conf"

# Backup Redis config
cp "$REDIS_CONF" "${REDIS_CONF}.backup.$(date +%Y%m%d_%H%M%S)"

# Configure Redis to use Unix socket for better performance
sed -i 's/^port 6379/port 0/' "$REDIS_CONF"
sed -i 's|^# unixsocket /run/redis/redis-server.sock|unixsocket /run/redis/redis-server.sock|' "$REDIS_CONF"
sed -i 's|^# unixsocketperm 700|unixsocketperm 770|' "$REDIS_CONF"

# Add www-data to redis group for socket access
usermod -a -G redis www-data

# Restart Redis
systemctl restart redis-server
systemctl enable redis-server

if systemctl is-active --quiet redis-server; then
    echo -e "${GREEN}✅ Redis installed and configured${NC}"
else
    echo -e "${RED}❌ Redis failed to start${NC}"
    exit 1
fi

echo ""
echo -e "${BLUE}═══════════════════════════════════════${NC}"
echo -e "${BLUE}2️⃣  Configuring Nextcloud to use Redis${NC}"
echo -e "${BLUE}═══════════════════════════════════════${NC}"
echo ""

# Backup Nextcloud config
BACKUP_FILE="${NC_CONFIG}.backup.$(date +%Y%m%d_%H%M%S)"
cp "$NC_CONFIG" "$BACKUP_FILE"
echo -e "${GREEN}✅ Backup created: $BACKUP_FILE${NC}"

# Configure Nextcloud to use Redis for memcache and file locking
echo -e "${CYAN}Configuring Redis connection...${NC}"

# IMPORTANT: Set Redis connection details FIRST, before enabling memcache
sudo -u www-data php "$NC_OCC" config:system:set redis host --value='/run/redis/redis-server.sock'
sudo -u www-data php "$NC_OCC" config:system:set redis port --value=0 --type=integer

echo -e "${CYAN}Enabling memcache...${NC}"

# Now enable memcache (this will try to connect to Redis)
sudo -u www-data php "$NC_OCC" config:system:set memcache.local --value='\OC\Memcache\Redis'
sudo -u www-data php "$NC_OCC" config:system:set memcache.locking --value='\OC\Memcache\Redis'

echo -e "${GREEN}✅ Redis memcache configured${NC}"

echo ""
echo -e "${GREEN}╔═══════════════════════════════════╗${NC}"
echo -e "${GREEN}║   ✅ Redis Configured!            ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════╝${NC}"
echo ""

echo -e "${CYAN}Summary:${NC}"
echo -e "  ✅ Redis server installed and running"
echo -e "  ✅ Redis memcache configured for file locking and caching"
echo -e "  ✅ Unix socket configured for optimal performance"
echo ""

# Verify Redis configuration
echo -e "${CYAN}Verifying configuration...${NC}"
if sudo -u www-data php "$NC_OCC" config:system:get memcache.local | grep -q "Redis"; then
    echo -e "  ✅ Redis memcache: ${GREEN}Active${NC}"
else
    echo -e "  ⚠️  Redis memcache: ${YELLOW}Not detected${NC}"
fi

if systemctl is-active --quiet redis-server; then
    echo -e "  ✅ Redis service: ${GREEN}Running${NC}"
else
    echo -e "  ⚠️  Redis service: ${YELLOW}Not running${NC}"
fi

echo ""
echo -e "${YELLOW}💡 Useful commands:${NC}"
echo -e "   Check Redis status:       ${BLUE}sudo systemctl status redis-server${NC}"
echo -e "   Monitor Redis:            ${BLUE}redis-cli -s /run/redis/redis-server.sock monitor${NC}"
echo -e "   View Nextcloud config:    ${BLUE}sudo -u www-data php $NC_OCC config:list system${NC}"
echo -e "   Restart Apache:           ${BLUE}sudo systemctl restart apache2${NC}"
echo ""
echo -e "${CYAN}Configuration backup:${NC}"
echo -e "   ${BLUE}$BACKUP_FILE${NC}"
echo ""
echo -e "${YELLOW}📊 Expected improvements:${NC}"
echo "  • Faster file operations and uploads"
echo "  • Reduced database load"
echo "  • Better concurrent user handling"
echo "  • Improved UI responsiveness"
echo ""
echo -e "${BLUE}🧱 Performance optimization brick is complete!${NC}"
