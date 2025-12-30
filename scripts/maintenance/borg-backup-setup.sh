#!/bin/bash

# 🧱 Backup Setup Brick - BorgBackup Client
# Configures automated backups using BorgBackup

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   🧱 BorgBackup Client Setup          ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
echo ""

# Ensure script is running with sudo
if [ "$EUID" -ne 0 ]; then
  echo -e "${YELLOW}⚠️  This script needs to run with sudo. Re-running...${NC}"
  exec sudo "$0" "$@"
fi

echo -e "${CYAN}This script will set up automated backups:${NC}"
echo "  • Install BorgBackup"
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

# Install BorgBackup
if ! command -v borg &> /dev/null; then
    echo ""
    echo -e "${BLUE}📦 Installing BorgBackup...${NC}"
    apt update
    apt install -y borgbackup
    echo -e "${GREEN}✅ BorgBackup installed${NC}"
else
    echo -e "${GREEN}✅ BorgBackup is already installed${NC}"
fi

echo -e "${CYAN}BorgBackup version: ${GREEN}$(borg --version)${NC}"

# Configure repository
echo ""
echo -e "${CYAN}═══════════════════════════════════════${NC}"
echo -e "${CYAN}    Repository Configuration           ${NC}"
echo -e "${CYAN}═══════════════════════════════════════${NC}"
echo ""
echo "Select backup destination:"
echo "  1) SSH/Remote Server (borg@hostname:/path)"
echo "  2) Local Directory"
read -p "Select option (1-2): " repo_type

case $repo_type in
    1)
        # SSH Repository
        read -p "SSH server address (e.g., backup.example.com): " ssh_host
        read -p "SSH user [borg]: " ssh_user
        ssh_user=${ssh_user:-borg}
        read -p "Remote path (e.g., /var/backups/borg/$(hostname)): " ssh_path
        ssh_path=${ssh_path:-/var/backups/borg/$(hostname)}
        BORG_REPO="${ssh_user}@${ssh_host}:${ssh_path}"
        
        echo ""
        echo -e "${YELLOW}SSH Key Configuration:${NC}"
        echo "Ensure SSH key authentication is set up for ${ssh_user}@${ssh_host}"
        echo ""
        read -p "Test SSH connection now? (Y/n): " test_ssh
        test_ssh=${test_ssh:-Y}
        
        if [[ $test_ssh =~ ^[Yy]$ ]]; then
            if ssh -o BatchMode=yes -o ConnectTimeout=5 "${ssh_user}@${ssh_host}" "echo 'Connection successful'" 2>/dev/null; then
                echo -e "${GREEN}✅ SSH connection successful${NC}"
            else
                echo -e "${RED}❌ SSH connection failed${NC}"
                echo -e "${YELLOW}You may need to:"
                echo "  1. Copy your SSH key: ssh-copy-id ${ssh_user}@${ssh_host}"
                echo "  2. Or manually add your public key to ${ssh_user}'s authorized_keys"
                echo ""
                read -p "Continue anyway? (y/N): " continue_anyway
                if [[ ! $continue_anyway =~ ^[Yy]$ ]]; then
                    exit 1
                fi
            fi
        fi
        ;;
    2)
        # Local Directory
        read -p "Local directory path [/var/backups/borg]: " local_path
        local_path=${local_path:-/var/backups/borg}
        mkdir -p "$local_path"
        BORG_REPO="$local_path"
        ;;
    *)
        echo -e "${RED}❌ Invalid selection${NC}"
        exit 1
        ;;
esac

# Repository passphrase
echo ""
read -sp "Enter repository passphrase (or empty for no encryption): " BORG_PASSPHRASE
echo ""

if [ -z "$BORG_PASSPHRASE" ]; then
    echo -e "${YELLOW}⚠️  Warning: Repository will be unencrypted!${NC}"
    read -p "Continue without encryption? (y/N): " no_encrypt
    if [[ ! $no_encrypt =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Setup cancelled. Please run again with a passphrase.${NC}"
        exit 1
    fi
    ENCRYPTION_MODE="none"
else
    ENCRYPTION_MODE="repokey-blake2"
fi

# Initialize repository
echo ""
echo -e "${BLUE}🔧 Initializing backup repository...${NC}"

export BORG_REPO
export BORG_PASSPHRASE

if borg list &> /dev/null; then
    echo -e "${YELLOW}Repository already exists${NC}"
else
    if [ "$ENCRYPTION_MODE" = "none" ]; then
        borg init --encryption=none
    else
        borg init --encryption=repokey-blake2
    fi
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

BACKUP_SCRIPT="/usr/local/bin/borg-backup.sh"

cat > "$BACKUP_SCRIPT" <<'BACKUP_EOF'
#!/bin/bash
# Automated BorgBackup Script
# Generated by ubuntu-toolbox

set -e

# Load environment
BACKUP_EOF

# Add repository configuration
cat >> "$BACKUP_SCRIPT" <<BACKUP_EOF
export BORG_REPO="$BORG_REPO"
export BORG_PASSPHRASE="$BORG_PASSPHRASE"

# Some helpers
info() { printf "\\n%s %s\\n\\n" "\$( date )" "\$*" >&2; }
trap 'echo \$( date ) Backup interrupted >&2; exit 2' INT TERM

BACKUP_EOF

# Add database backup logic
if [ "$BACKUP_MYSQL" = true ]; then
cat >> "$BACKUP_SCRIPT" <<'BACKUP_EOF'

# MySQL backup
info "Backing up MySQL databases..."
mysqldump --all-databases --single-transaction --quick --lock-tables=false > /var/backups/mysql/all-databases.sql
BACKUP_EOF
fi

if [ "$BACKUP_POSTGRES" = true ]; then
cat >> "$BACKUP_SCRIPT" <<'BACKUP_EOF'

# PostgreSQL backup
info "Backing up PostgreSQL databases..."
sudo -u postgres pg_dumpall > /var/backups/postgresql/all-databases.sql
BACKUP_EOF
fi

# Add borg backup command
cat >> "$BACKUP_SCRIPT" <<BACKUP_EOF

# Create backup archive
info "Starting backup..."

borg create \\
    --verbose \\
    --filter AME \\
    --list \\
    --stats \\
    --show-rc \\
    --compression lz4 \\
    --exclude-caches \\
    --exclude '/home/*/.cache' \\
    --exclude '/var/cache' \\
    --exclude '/var/tmp' \\
    ::'{hostname}-{now}' \\
    ${BACKUP_PATHS[@]}

backup_exit=\$?

# Prune old backups (keep last 7 daily, 4 weekly, 6 monthly)
info "Pruning old backups..."

borg prune \\
    --list \\
    --prefix '{hostname}-' \\
    --show-rc \\
    --keep-daily 7 \\
    --keep-weekly 4 \\
    --keep-monthly 6

prune_exit=\$?

# Use highest exit code as global exit code
global_exit=\$(( backup_exit > prune_exit ? backup_exit : prune_exit ))

if [ \${global_exit} -eq 0 ]; then
    info "Backup and Prune completed successfully"
elif [ \${global_exit} -eq 1 ]; then
    info "Backup and/or Prune finished with warnings"
else
    info "Backup and/or Prune finished with errors"
fi

exit \${global_exit}
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
(crontab -l 2>/dev/null | grep -v "$BACKUP_SCRIPT"; echo "$CRON_SCHEDULE $BACKUP_SCRIPT >> /var/log/borg-backup.log 2>&1") | crontab -

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
echo -e "  • Repository: ${GREEN}${BORG_REPO}${NC}"
echo -e "  • Backup paths: ${GREEN}${#BACKUP_PATHS[@]} configured${NC}"
echo -e "  • Schedule: ${GREEN}${CRON_SCHEDULE}${NC}"
echo -e "  • Script: ${GREEN}${BACKUP_SCRIPT}${NC}"
echo ""
echo -e "${YELLOW}💡 Useful commands:${NC}"
echo -e "   List archives:      ${BLUE}borg list${NC}"
echo -e "   Manual backup:      ${BLUE}sudo $BACKUP_SCRIPT${NC}"
echo -e "   Restore file:       ${BLUE}borg extract ::archive-name path/to/file${NC}"
echo -e "   Check repository:   ${BLUE}borg check${NC}"
echo -e "   View backup log:    ${BLUE}tail -f /var/log/borg-backup.log${NC}"
echo -e "   Info about archive: ${BLUE}borg info ::archive-name${NC}"
echo ""
echo -e "${YELLOW}📄 Credentials stored in:${NC}"
echo -e "   ${BLUE}$BACKUP_SCRIPT${NC}"
echo -e "   ${RED}⚠️  Keep this file secure!${NC}"
echo ""
echo -e "${BLUE}🧱 Backup setup brick is complete!${NC}"
