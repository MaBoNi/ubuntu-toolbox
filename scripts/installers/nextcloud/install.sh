#!/bin/bash

# 🧱 Nextcloud Installer Brick
# Installs Nextcloud with LAMP stack on Ubuntu 24.04

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   🧱 Nextcloud Installer Brick    ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════╝${NC}"
echo ""

# Ensure script is running with sudo
if [ "$EUID" -ne 0 ]; then
  echo -e "${YELLOW}⚠️  This script needs to run with sudo. Re-running...${NC}"
  exec sudo "$0" "$@"
fi

# Confirm installation
echo -e "${YELLOW}This script will install:${NC}"
echo "  • Apache2 web server"
echo "  • MariaDB database server"
echo "  • PHP 8.3 and required modules"
echo "  • Nextcloud (latest version)"
echo ""
read -p "Continue with installation? (y/N): " confirm
if [[ ! $confirm =~ ^[Yy]$ ]]; then
    echo -e "${RED}Installation cancelled.${NC}"
    exit 0
fi

# Step 1: Update system
echo ""
echo -e "${CYAN}[1/8] 📦 Updating system packages...${NC}"
apt update && apt upgrade -y

# Step 2: Install Apache and PHP
echo ""
echo -e "${CYAN}[2/8] 🌐 Installing Apache2 and PHP modules...${NC}"
apt install -y apache2 libapache2-mod-php php-gd php-mysql php-curl \
    php-mbstring php-intl php-gmp php-xml php-imagick php-zip \
    php-bcmath unzip wget

# Step 3: Install MariaDB
echo ""
echo -e "${CYAN}[3/8] 🗄️  Installing MariaDB...${NC}"
apt install -y mariadb-server

# Step 4: Secure MariaDB
echo ""
echo -e "${CYAN}[4/8] 🔐 Setting up MariaDB...${NC}"
echo -e "${YELLOW}You'll be prompted to secure MariaDB installation.${NC}"
echo ""
mysql_secure_installation

# Step 5: Create database
echo ""
echo -e "${CYAN}[5/8] 🗃️  Creating Nextcloud database...${NC}"
read -p "Enter database name [nextcloud]: " DB_NAME
DB_NAME=${DB_NAME:-nextcloud}

read -p "Enter database username [nextclouduser]: " DB_USER
DB_USER=${DB_USER:-nextclouduser}

read -sp "Enter database password: " DB_PASS
echo ""

if [ -z "$DB_PASS" ]; then
    echo -e "${RED}❌ Database password is required!${NC}"
    exit 1
fi

mysql -e "CREATE DATABASE IF NOT EXISTS ${DB_NAME};"
mysql -e "CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';"
mysql -e "GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'localhost';"
mysql -e "FLUSH PRIVILEGES;"

echo -e "${GREEN}✅ Database created successfully${NC}"

# Step 6: Download Nextcloud
echo ""
echo -e "${CYAN}[6/8] ⬇️  Downloading Nextcloud...${NC}"
cd /tmp
wget https://download.nextcloud.com/server/releases/latest.zip -O nextcloud.zip
unzip -q nextcloud.zip
rm nextcloud.zip

# Step 7: Configure Apache
echo ""
echo -e "${CYAN}[7/8] ⚙️  Configuring Apache...${NC}"
read -p "Enter your domain or server IP: " SERVER_NAME

if [ -z "$SERVER_NAME" ]; then
    echo -e "${RED}❌ Server name is required!${NC}"
    exit 1
fi

# Move Nextcloud to web directory
mv nextcloud /var/www/
chown -R www-data:www-data /var/www/nextcloud

# Create Apache virtual host
cat > /etc/apache2/sites-available/nextcloud.conf <<EOF
<VirtualHost *:80>
    ServerName ${SERVER_NAME}
    DocumentRoot /var/www/nextcloud

    <Directory /var/www/nextcloud/>
        Options +FollowSymlinks
        AllowOverride All
        Require all granted

        <IfModule mod_dav.c>
            Dav off
        </IfModule>

        SetEnv HOME /var/www/nextcloud
        SetEnv HTTP_HOME /var/www/nextcloud
    </Directory>

    ErrorLog \${APACHE_LOG_DIR}/nextcloud-error.log
    CustomLog \${APACHE_LOG_DIR}/nextcloud-access.log combined
</VirtualHost>
EOF

# Enable site and modules
a2ensite nextcloud.conf
a2enmod rewrite headers env dir mime setenvif ssl
systemctl reload apache2

echo -e "${GREEN}✅ Apache configured${NC}"

# Step 8: Final setup instructions
echo ""
echo -e "${CYAN}[8/8] 🎉 Installation complete!${NC}"
echo ""
echo -e "${GREEN}╔═══════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   ✅ Nextcloud is ready to configure! ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Open your browser and navigate to: http://${SERVER_NAME}"
echo "2. Create an admin account"
echo "3. Enter database details:"
echo "   - Database: ${DB_NAME}"
echo "   - Username: ${DB_USER}"
echo "   - Password: [the one you entered]"
echo "   - Database host: localhost"
echo ""
echo -e "${YELLOW}💡 Tips:${NC}"
echo "• Consider setting up SSL with Let's Encrypt (certbot)"
echo "• Configure PHP memory limits for better performance"
echo "• Set up regular backups"
echo ""
echo -e "${BLUE}🧱 Your Nextcloud brick is built and ready!${NC}"
