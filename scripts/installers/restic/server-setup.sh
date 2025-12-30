#!/bin/bash

# 🧱 Restic REST Server Setup Brick
# Installs and configures Restic REST server for backup repository hosting

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   🧱 Restic REST Server Setup         ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
echo ""

# Ensure script is running with sudo
if [ "$EUID" -ne 0 ]; then
  echo -e "${YELLOW}⚠️  This script needs to run with sudo. Re-running...${NC}"
  exec sudo "$0" "$@"
fi

echo -e "${CYAN}This script will set up a Restic REST server:${NC}"
echo "  • Install Restic REST server"
echo "  • Configure storage location"
echo "  • Set up authentication"
echo "  • Configure as systemd service"
echo "  • Optional: TLS/HTTPS setup"
echo ""

read -p "Continue with Restic server setup? (Y/n): " confirm
confirm=${confirm:-Y}

if [[ ! $confirm =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Setup cancelled.${NC}"
    exit 0
fi

# Install dependencies
echo ""
echo -e "${BLUE}📦 Installing dependencies...${NC}"
apt update
apt install -y wget apache2-utils

# Download and install rest-server
echo ""
echo -e "${BLUE}📥 Downloading Restic REST server...${NC}"

# Get latest version
LATEST_VERSION=$(curl -s https://api.github.com/repos/restic/rest-server/releases/latest | grep '"tag_name"' | sed -E 's/.*"v([^"]+)".*/\1/')
echo -e "${CYAN}Latest version: ${GREEN}v${LATEST_VERSION}${NC}"

# Download
wget -q --show-progress "https://github.com/restic/rest-server/releases/download/v${LATEST_VERSION}/rest-server_${LATEST_VERSION}_linux_amd64.tar.gz" -O /tmp/rest-server.tar.gz

# Extract
tar -xzf /tmp/rest-server.tar.gz -C /tmp
mv /tmp/rest-server_${LATEST_VERSION}_linux_amd64/rest-server /usr/local/bin/
chmod +x /usr/local/bin/rest-server
rm -rf /tmp/rest-server.tar.gz /tmp/rest-server_${LATEST_VERSION}_linux_amd64

echo -e "${GREEN}✅ Restic REST server installed${NC}"

# Create restic user
echo ""
echo -e "${BLUE}👤 Creating restic user...${NC}"
if ! id "restic" &>/dev/null; then
    useradd -r -s /bin/false -d /var/lib/restic restic
    echo -e "${GREEN}✅ User 'restic' created${NC}"
else
    echo -e "${YELLOW}User 'restic' already exists${NC}"
fi

# Configure storage location
echo ""
echo -e "${YELLOW}📁 Storage configuration${NC}"
read -p "Enter storage path for backups [/var/lib/restic]: " STORAGE_PATH
STORAGE_PATH=${STORAGE_PATH:-/var/lib/restic}

mkdir -p "$STORAGE_PATH"
chown -R restic:restic "$STORAGE_PATH"
chmod 750 "$STORAGE_PATH"
echo -e "${GREEN}✅ Storage path configured: $STORAGE_PATH${NC}"

# Configure authentication
echo ""
echo -e "${YELLOW}🔐 Authentication setup${NC}"
echo "Create a username and password for REST server access"
read -p "Username: " REST_USER

if [ -z "$REST_USER" ]; then
    echo -e "${RED}❌ Username is required!${NC}"
    exit 1
fi

# Create htpasswd file
HTPASSWD_FILE="/etc/restic-rest-server.htpasswd"
htpasswd -c -B "$HTPASSWD_FILE" "$REST_USER"
chmod 600 "$HTPASSWD_FILE"
echo -e "${GREEN}✅ Authentication configured${NC}"

# Configure port
echo ""
read -p "REST server port [8000]: " REST_PORT
REST_PORT=${REST_PORT:-8000}

# Create systemd service
echo ""
echo -e "${BLUE}🔧 Creating systemd service...${NC}"

cat > /etc/systemd/system/restic-rest-server.service <<EOF
[Unit]
Description=Restic REST Server
After=network.target

[Service]
Type=simple
User=restic
Group=restic
ExecStart=/usr/local/bin/rest-server \\
    --listen :${REST_PORT} \\
    --path ${STORAGE_PATH} \\
    --htpasswd-file ${HTPASSWD_FILE} \\
    --log /var/log/restic-rest-server.log
Restart=on-failure
RestartSec=10

# Security settings
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=${STORAGE_PATH} /var/log

[Install]
WantedBy=multi-user.target
EOF

echo -e "${GREEN}✅ Systemd service created${NC}"

# Configure log rotation
echo ""
echo -e "${BLUE}📄 Configuring log rotation...${NC}"
cat > /etc/logrotate.d/restic-rest-server <<EOF
/var/log/restic-rest-server.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 0640 restic restic
}
EOF

touch /var/log/restic-rest-server.log
chown restic:restic /var/log/restic-rest-server.log

echo -e "${GREEN}✅ Log rotation configured${NC}"

# Start service
echo ""
echo -e "${BLUE}🚀 Starting Restic REST server...${NC}"
systemctl daemon-reload
systemctl enable restic-rest-server
systemctl start restic-rest-server

# Wait for service to start
sleep 2

if systemctl is-active --quiet restic-rest-server; then
    echo -e "${GREEN}✅ Restic REST server is running${NC}"
else
    echo -e "${RED}❌ Failed to start Restic REST server${NC}"
    journalctl -u restic-rest-server -n 20 --no-pager
    exit 1
fi

# Show firewall reminder
echo ""
echo -e "${YELLOW}⚠️  Firewall Configuration${NC}"
echo -e "Don't forget to allow port ${REST_PORT} in your firewall:"
echo -e "  ${BLUE}sudo ufw allow ${REST_PORT}/tcp${NC}"

echo ""
echo -e "${GREEN}╔════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   ✅ Restic Server Setup Complete!    ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════╝${NC}"
echo ""
echo -e "${CYAN}Configuration summary:${NC}"
echo -e "  • Server address: ${GREEN}http://$(hostname -I | awk '{print $1}'):${REST_PORT}${NC}"
echo -e "  • Storage path: ${GREEN}${STORAGE_PATH}${NC}"
echo -e "  • Username: ${GREEN}${REST_USER}${NC}"
echo -e "  • Service: ${GREEN}restic-rest-server${NC}"
echo ""
echo -e "${YELLOW}💡 Test connection from client:${NC}"
echo -e "  ${BLUE}restic -r rest:http://${REST_USER}@$(hostname -I | awk '{print $1}'):${REST_PORT}/ init${NC}"
echo ""
echo -e "${YELLOW}📊 Useful commands:${NC}"
echo -e "   Service status:     ${BLUE}sudo systemctl status restic-rest-server${NC}"
echo -e "   View logs:          ${BLUE}sudo journalctl -u restic-rest-server -f${NC}"
echo -e "   Restart service:    ${BLUE}sudo systemctl restart restic-rest-server${NC}"
echo -e "   Check storage:      ${BLUE}sudo du -sh ${STORAGE_PATH}${NC}"
echo ""
echo -e "${BLUE}🧱 Restic server setup brick is complete!${NC}"
