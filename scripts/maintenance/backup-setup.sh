#!/bin/bash

# 🧱 Backup Setup Brick
# Configures automated backups using Restic

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   🧱 Backup Setup Brick                ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
echo ""

# Ensure script is running with sudo
if [ "$EUID" -ne 0 ]; then
  echo -e "${YELLOW}⚠️  This script needs to run with sudo. Re-running...${NC}"
  exec sudo "$0" "$@"
fi

echo -e "${CYAN}This script will set up automated backups:${NC}"
echo "  • Install Restic backup tool"
echo "  • Configure backup repository"
echo "  • Select backup paths"
echo "  • Configure database backups (optional)"
echo "  • Schedule automated backups"
echo ""

read -p "Continue with backup setup? (Y/n): " confirm
confirm=${confirm:-Y}

if [[ ! $confirm =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Setup cancelled.${NC}"
    exit 0
fi

# Install Restic
if ! command -v restic &> /dev/null; then
    echo ""
    echo -e "${BLUE}📦 Installing Restic...${NC}"
    apt update
    apt install -y restic
    echo -e "${GREEN}✅ Restic installed${NC}"
else
    echo -e "${GREEN}✅ Restic is already installed${NC}"
fi

echo -e "${CYAN}Restic version: ${GREEN}$(restic version)${NC}"

# Configure repository
echo ""
echo -e "${CYAN}═══════════════════════════════════════${NC}"
echo -e "${CYAN}    Repository Configuration           ${NC}"
echo -e "${CYAN}═══════════════════════════════════════${NC}"
echo ""
echo "Select backup destination:"
echo "  1) Restic REST Server"
echo "  2) SFTP/SSH Server"
echo "  3) Local Directory"
echo "  4) S3-compatible (AWS, B2, Wasabi, MinIO)"
read -p "Select option (1-4): " repo_type

case $repo_type in
    1)
        # REST Server
        read -p "REST server address (e.g., backup.example.com): " rest_host
        read -p "REST server port [8000]: " rest_port
        rest_port=${rest_port:-8000}
        read -p "Username: " rest_user
        RESTIC_REPOSITORY="rest:http://${rest_user}@${rest_host}:${rest_port}/"
        read -sp "Password: " RESTIC_PASSWORD
        echo ""
        ;;
    2)
        # SFTP
        read -p "SSH server address: " sftp_host
        read -p "SSH user: " sftp_user
        read -p "Remote path: " sftp_path
        RESTIC_REPOSITORY="sftp:${sftp_user}@${sftp_host}:${sftp_path}"
        read -sp "Repository password: " RESTIC_PASSWORD
        echo ""
        ;;
    3)
        # Local
        read -p "Local directory path: " local_path
        RESTIC_REPOSITORY="$local_path"
        read -sp "Repository password: " RESTIC_PASSWORD
        echo ""
        ;;
    4)
        # S3
        read -p "S3 endpoint (e.g., s3.amazonaws.com or s3.us-west-000.backblazeb2.com): " s3_endpoint
        read -p "Bucket name: " s3_bucket
        read -p "Access Key ID: " AWS_ACCESS_KEY_ID
        read -sp "Secret Access Key: " AWS_SECRET_ACCESS_KEY
        echo ""
        RESTIC_REPOSITORY="s3:${s3_endpoint}/${s3_bucket}"
        read -sp "Repository password: " RESTIC_PASSWORD
        echo ""
        ;;
    *)
        echo -e "${RED}❌ Invalid selection${NC}"
        exit 1
        ;;
esac

# Initialize repository
echo ""
echo -e "${BLUE}🔧 Initializing backup repository...${NC}"

export RESTIC_REPOSITORY
export RESTIC_PASSWORD
if [ -n "$AWS_ACCESS_KEY_ID" ]; then
    export AWS_ACCESS_KEY_ID
    export AWS_SECRET_ACCESS_KEY
fi

if restic snapshots &> /dev/null; then
    echo -e "${YELLOW}Repository already initialized${NC}"
else
    restic init
    echo -e "${GREEN}✅ Repository initialized${NC}"
fi

# Configure what to backup
echo ""
echo -e "${CYAN}═══════════════════════════════════════${NC}"
echo -e "${CYAN}    Backup Configuration                ${NC}"
echo -e "${CYAN}═══════════════════════════════════════${NC}"
echo ""

BACKUP_PATHS=()

# Home directories
read -p "Backup home directories? (Y/n): " backup_home
backup_home=${backup_home:-Y}
if [[ $backup_home =~ ^[Yy]$ ]]; then
    BACKUP_PATHS+=("/home")
fi

# Docker volumes
if command -v docker &> /dev/null; then
    read -p "Backup Docker volumes? (Y/n): " backup_docker
    backup_docker=${backup_docker:-Y}
    if [[ $backup_docker =~ ^[Yy]$ ]]; then
        BACKUP_PATHS+=("/var/lib/docker/volumes")
    fi
fi

# Custom paths
read -p "Add custom backup paths? (y/N): " add_custom
if [[ $add_custom =~ ^[Yy]$ ]]; then
    while true; do
        read -p "Enter path to backup (or empty to finish): " custom_path
        [ -z "$custom_path" ] && break
        if [ -d "$custom_path" ]; then
            BACKUP_PATHS+=("$custom_path")
            echo -e "${GREEN}✅ Added: $custom_path${NC}"
        else
            echo -e "${YELLOW}⚠️  Path doesn't exist: $custom_path${NC}"
        fi
    done
fi

# Database backups
echo ""
BACKUP_MYSQL=false
BACKUP_POSTGRES=false

if command -v mysql &> /dev/null; then
    read -p "Configure MySQL/MariaDB backup? (y/N): " backup_mysql
    if [[ $backup_mysql =~ ^[Yy]$ ]]; then
        BACKUP_MYSQL=true
        MYSQL_BACKUP_DIR="/var/backups/mysql"
        mkdir -p "$MYSQL_BACKUP_DIR"
        BACKUP_PATHS+=("$MYSQL_BACKUP_DIR")
    fi
fi

if command -v psql &> /dev/null; then
    read -p "Configure PostgreSQL backup? (y/N): " backup_postgres
    if [[ $backup_postgres =~ ^[Yy]$ ]]; then
        BACKUP_POSTGRES=true
        PG_BACKUP_DIR="/var/backups/postgresql"
        mkdir -p "$PG_BACKUP_DIR"
        BACKUP_PATHS+=("$PG_BACKUP_DIR")
    fi
fi

# Create backup script
echo ""
echo -e "${BLUE}📝 Creating backup script...${NC}"

BACKUP_SCRIPT="/usr/local/bin/restic-backup.sh"

cat > "$BACKUP_SCRIPT" <<'BACKUP_EOF'
#!/bin/bash
# Automated Restic Backup Script
# Generated by ubuntu-toolbox

set -e

# Load environment
BACKUP_EOF

# Add repository configuration
cat >> "$BACKUP_SCRIPT" <<BACKUP_EOF
export RESTIC_REPOSITORY="$RESTIC_REPOSITORY"
export RESTIC_PASSWORD="$RESTIC_PASSWORD"
BACKUP_EOF

if [ -n "$AWS_ACCESS_KEY_ID" ]; then
cat >> "$BACKUP_SCRIPT" <<BACKUP_EOF
export AWS_ACCESS_KEY_ID="$AWS_ACCESS_KEY_ID"
export AWS_SECRET_ACCESS_KEY="$AWS_SECRET_ACCESS_KEY"
BACKUP_EOF
fi

# Add database backup logic
if [ "$BACKUP_MYSQL" = true ]; then
cat >> "$BACKUP_SCRIPT" <<'BACKUP_EOF'

# MySQL backup
echo "Backing up MySQL databases..."
mysqldump --all-databases --single-transaction --quick --lock-tables=false > /var/backups/mysql/all-databases.sql
BACKUP_EOF
fi

if [ "$BACKUP_POSTGRES" = true ]; then
cat >> "$BACKUP_SCRIPT" <<'BACKUP_EOF'

# PostgreSQL backup
echo "Backing up PostgreSQL databases..."
sudo -u postgres pg_dumpall > /var/backups/postgresql/all-databases.sql
BACKUP_EOF
fi

# Add restic backup command
cat >> "$BACKUP_SCRIPT" <<BACKUP_EOF

# Run backup
echo "Starting backup..."
restic backup ${BACKUP_PATHS[@]} \\
    --exclude-caches \\
    --exclude '/home/*/.cache' \\
    --exclude '/var/cache' \\
    --exclude '/var/tmp'

# Forget old snapshots (keep last 7 daily, 4 weekly, 6 monthly)
echo "Pruning old backups..."
restic forget --keep-daily 7 --keep-weekly 4 --keep-monthly 6 --prune

echo "Backup completed: \$(date)"
BACKUP_EOF

chmod +x "$BACKUP_SCRIPT"
echo -e "${GREEN}✅ Backup script created: $BACKUP_SCRIPT${NC}"

# Schedule backups
echo ""
echo -e "${BLUE}⏰ Scheduling automated backups...${NC}"
echo "Select backup frequency:"
echo "  1) Daily at 2 AM"
echo "  2) Daily at specific time"
echo "  3) Every 6 hours"
echo "  4) Custom cron schedule"
read -p "Select option (1-4): " schedule_option

case $schedule_option in
    1) CRON_SCHEDULE="0 2 * * *" ;;
    2)
        read -p "Enter hour (0-23): " backup_hour
        CRON_SCHEDULE="0 ${backup_hour} * * *"
        ;;
    3) CRON_SCHEDULE="0 */6 * * *" ;;
    4)
        read -p "Enter cron schedule (e.g., '0 2 * * *'): " CRON_SCHEDULE
        ;;
    *)
        CRON_SCHEDULE="0 2 * * *"
        ;;
esac

# Add to crontab
(crontab -l 2>/dev/null | grep -v "$BACKUP_SCRIPT"; echo "$CRON_SCHEDULE $BACKUP_SCRIPT >> /var/log/restic-backup.log 2>&1") | crontab -

echo -e "${GREEN}✅ Backup scheduled: $CRON_SCHEDULE${NC}"

# Test backup
echo ""
read -p "Run test backup now? (Y/n): " test_backup
test_backup=${test_backup:-Y}

if [[ $test_backup =~ ^[Yy]$ ]]; then
    echo -e "${BLUE}🧪 Running test backup...${NC}"
    if bash "$BACKUP_SCRIPT"; then
        echo -e "${GREEN}✅ Test backup successful!${NC}"
    else
        echo -e "${RED}❌ Test backup failed${NC}"
    fi
fi

echo ""
echo -e "${GREEN}╔════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   ✅ Backup Setup Complete!           ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════╝${NC}"
echo ""
echo -e "${CYAN}Configuration summary:${NC}"
echo -e "  • Repository: ${GREEN}${RESTIC_REPOSITORY}${NC}"
echo -e "  • Backup paths: ${GREEN}${#BACKUP_PATHS[@]} configured${NC}"
echo -e "  • Schedule: ${GREEN}${CRON_SCHEDULE}${NC}"
echo -e "  • Script: ${GREEN}${BACKUP_SCRIPT}${NC}"
echo ""
echo -e "${YELLOW}💡 Useful commands:${NC}"
echo -e "   List snapshots:     ${BLUE}restic snapshots${NC}"
echo -e "   Manual backup:      ${BLUE}sudo $BACKUP_SCRIPT${NC}"
echo -e "   Restore file:       ${BLUE}restic restore latest --target /restore --include /path/to/file${NC}"
echo -e "   Check repository:   ${BLUE}restic check${NC}"
echo -e "   View backup log:    ${BLUE}tail -f /var/log/restic-backup.log${NC}"
echo ""
echo -e "${YELLOW}📄 Credentials stored in:${NC}"
echo -e "   ${BLUE}$BACKUP_SCRIPT${NC}"
echo -e "   ${RED}⚠️  Keep this file secure!${NC}"
echo ""
echo -e "${BLUE}🧱 Backup setup brick is complete!${NC}"
