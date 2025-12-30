#!/bin/bash

# 🧱 Docker Installer Brick
# Installs Docker, Docker Compose, and optional management tools

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   🧱 Docker Installer Brick       ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════╝${NC}"
echo ""

# Ensure script is running with sudo
if [ "$EUID" -ne 0 ]; then
  echo -e "${YELLOW}⚠️  This script needs to run with sudo. Re-running...${NC}"
  exec sudo "$0" "$@"
fi

echo -e "${CYAN}This installer will set up:${NC}"
echo "  • Docker Engine"
echo "  • Docker Compose (latest)"
echo "  • User permissions"
echo "  • Optional: Portainer (web UI)"
echo "  • Optional: Portainer Agent (for remote management)"
echo "  • Optional: Watchtower (auto-updates)"
echo ""

read -p "Continue with Docker installation? (Y/n): " confirm
confirm=${confirm:-Y}

if [[ ! $confirm =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Installation cancelled.${NC}"
    exit 0
fi

# Check if Docker is already installed
if command -v docker &> /dev/null; then
    DOCKER_VERSION=$(docker --version | awk '{print $3}' | sed 's/,//')
    echo ""
    echo -e "${YELLOW}⚠️  Docker is already installed (version $DOCKER_VERSION)${NC}"
    read -p "Reinstall Docker? (y/N): " reinstall
    
    if [[ ! $reinstall =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Skipping Docker installation. Will configure additional tools.${NC}"
        SKIP_DOCKER=true
    fi
fi

# Install Docker
if [ "$SKIP_DOCKER" != "true" ]; then
    echo ""
    echo -e "${BLUE}📦 Installing Docker...${NC}"
    
    # Remove old versions
    echo -e "${CYAN}Removing old Docker versions...${NC}"
    apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true
    
    # Install prerequisites
    echo -e "${CYAN}Installing prerequisites...${NC}"
    apt-get update
    apt-get install -y ca-certificates curl gnupg lsb-release
    
    # Add Docker's official GPG key
    echo -e "${CYAN}Adding Docker GPG key...${NC}"
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg
    
    # Set up repository
    echo -e "${CYAN}Setting up Docker repository...${NC}"
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
      tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Install Docker Engine
    echo -e "${CYAN}Installing Docker Engine...${NC}"
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    echo -e "${GREEN}✅ Docker installed${NC}"
fi

# Configure user permissions
echo ""
echo -e "${BLUE}👤 Configuring user permissions...${NC}"
echo -e "${YELLOW}Which user should be able to run Docker without sudo?${NC}"
read -p "Username [$(logname 2>/dev/null || echo $SUDO_USER)]: " DOCKER_USER
DOCKER_USER=${DOCKER_USER:-$(logname 2>/dev/null || echo $SUDO_USER)}

if [ -n "$DOCKER_USER" ] && id "$DOCKER_USER" &>/dev/null; then
    usermod -aG docker "$DOCKER_USER"
    echo -e "${GREEN}✅ User $DOCKER_USER added to docker group${NC}"
    echo -e "${YELLOW}⚠️  $DOCKER_USER needs to log out and back in for this to take effect${NC}"
else
    echo -e "${YELLOW}⚠️  User not found or not specified, skipping${NC}"
fi

# Start and enable Docker
echo ""
echo -e "${BLUE}🚀 Starting Docker service...${NC}"
systemctl start docker
systemctl enable docker
echo -e "${GREEN}✅ Docker service started and enabled${NC}"

# Test Docker installation
echo ""
echo -e "${BLUE}🧪 Testing Docker installation...${NC}"
if docker run --rm hello-world &>/dev/null; then
    echo -e "${GREEN}✅ Docker is working correctly${NC}"
else
    echo -e "${YELLOW}⚠️  Docker test failed, but installation completed${NC}"
fi

# Portainer installation
echo ""
echo -e "${CYAN}═══════════════════════════════════${NC}"
echo -e "${CYAN}    Container Management Options    ${NC}"
echo -e "${CYAN}═══════════════════════════════════${NC}"
echo ""
echo -e "${YELLOW}Would you like to install Portainer?${NC}"
echo -e "${CYAN}Portainer provides a web UI for managing Docker containers${NC}"
read -p "Install Portainer? (Y/n): " install_portainer
install_portainer=${install_portainer:-Y}

if [[ $install_portainer =~ ^[Yy]$ ]]; then
    echo ""
    echo -e "${BLUE}📦 Installing Portainer...${NC}"
    
    # Create volume for Portainer data
    docker volume create portainer_data
    
    # Run Portainer container
    docker run -d \
      --name=portainer \
      --restart=always \
      -p 8000:8000 \
      -p 9443:9443 \
      -v /var/run/docker.sock:/var/run/docker.sock \
      -v portainer_data:/data \
      portainer/portainer-ce:latest
    
    echo -e "${GREEN}✅ Portainer installed${NC}"
    echo ""
    echo -e "${CYAN}Access Portainer at:${NC}"
    echo -e "  ${GREEN}https://$(hostname -I | awk '{print $1}'):9443${NC}"
    echo -e "  ${YELLOW}Note: First visit will ask you to create an admin account${NC}"
    
    PORTAINER_INSTALLED=true
else
    # Ask about Portainer Agent if Portainer not installed
    echo ""
    echo -e "${YELLOW}Would you like to install Portainer Agent instead?${NC}"
    echo -e "${CYAN}Portainer Agent allows remote management from another Portainer instance${NC}"
    read -p "Install Portainer Agent? (y/N): " install_agent
    
    if [[ $install_agent =~ ^[Yy]$ ]]; then
        echo ""
        echo -e "${BLUE}📦 Installing Portainer Agent...${NC}"
        
        docker run -d \
          --name=portainer-agent \
          --restart=always \
          -p 9001:9001 \
          -v /var/run/docker.sock:/var/run/docker.sock \
          -v /var/lib/docker/volumes:/var/lib/docker/volumes \
          portainer/agent:latest
        
        echo -e "${GREEN}✅ Portainer Agent installed${NC}"
        echo ""
        echo -e "${CYAN}Agent accessible at:${NC}"
        echo -e "  ${GREEN}$(hostname -I | awk '{print $1}'):9001${NC}"
        echo -e "  ${YELLOW}Add this endpoint in your main Portainer instance${NC}"
    fi
fi

# Watchtower installation
echo ""
echo -e "${CYAN}═══════════════════════════════════${NC}"
echo -e "${CYAN}    Automatic Updates (Watchtower)  ${NC}"
echo -e "${CYAN}═══════════════════════════════════${NC}"
echo ""
echo -e "${YELLOW}Would you like to install Watchtower?${NC}"
echo -e "${CYAN}Watchtower automatically updates your Docker containers${NC}"
echo -e "${YELLOW}It checks for new images and updates containers automatically${NC}"
read -p "Install Watchtower? (y/N): " install_watchtower

if [[ $install_watchtower =~ ^[Yy]$ ]]; then
    echo ""
    echo -e "${YELLOW}Watchtower update schedule:${NC}"
    echo "  1) Daily at 2 AM (recommended)"
    echo "  2) Every 6 hours"
    echo "  3) Weekly on Sunday at 2 AM"
    echo "  4) Custom cron schedule"
    read -p "Select schedule (1-4) [1]: " schedule_choice
    schedule_choice=${schedule_choice:-1}
    
    case $schedule_choice in
        1) WATCHTOWER_SCHEDULE="0 0 2 * * *" ;; # Daily at 2 AM
        2) WATCHTOWER_SCHEDULE="0 0 */6 * * *" ;; # Every 6 hours
        3) WATCHTOWER_SCHEDULE="0 0 2 * * 0" ;; # Sunday at 2 AM
        4)
            read -p "Enter cron schedule (e.g., '0 0 2 * * *'): " WATCHTOWER_SCHEDULE
            ;;
        *) WATCHTOWER_SCHEDULE="0 0 2 * * *" ;;
    esac
    
    echo ""
    echo -e "${BLUE}📦 Installing Watchtower...${NC}"
    
    docker run -d \
      --name=watchtower \
      --restart=always \
      -e WATCHTOWER_SCHEDULE="$WATCHTOWER_SCHEDULE" \
      -e WATCHTOWER_CLEANUP=true \
      -e WATCHTOWER_INCLUDE_RESTARTING=true \
      -v /var/run/docker.sock:/var/run/docker.sock \
      containrrr/watchtower
    
    echo -e "${GREEN}✅ Watchtower installed${NC}"
    echo -e "${CYAN}Schedule:${NC} ${GREEN}$WATCHTOWER_SCHEDULE${NC}"
    echo -e "${YELLOW}💡 Watchtower will automatically update containers and clean up old images${NC}"
fi

# Final summary
echo ""
echo -e "${GREEN}╔═══════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   ✅ Docker Installation Complete!    ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════╝${NC}"
echo ""
echo -e "${CYAN}Installed components:${NC}"
echo "  • Docker Engine: ${GREEN}$(docker --version | awk '{print $3}')${NC}"
echo "  • Docker Compose: ${GREEN}$(docker compose version | awk '{print $4}')${NC}"

if [ "$PORTAINER_INSTALLED" = "true" ]; then
    echo "  • Portainer: ${GREEN}Installed${NC}"
fi

if docker ps --format '{{.Names}}' | grep -q watchtower; then
    echo "  • Watchtower: ${GREEN}Installed${NC}"
fi

echo ""
echo -e "${YELLOW}💡 Useful Docker commands:${NC}"
echo "   List containers:    ${BLUE}docker ps -a${NC}"
echo "   List images:        ${BLUE}docker images${NC}"
echo "   View logs:          ${BLUE}docker logs <container>${NC}"
echo "   Stop container:     ${BLUE}docker stop <container>${NC}"
echo "   Remove container:   ${BLUE}docker rm <container>${NC}"
echo "   System cleanup:     ${BLUE}docker system prune -a${NC}"
echo ""
echo -e "${YELLOW}📄 Docker info:${NC}"
docker info | grep -E "Server Version|Storage Driver|Containers|Images" | sed 's/^/   /'
echo ""
echo -e "${BLUE}🧱 Docker installation brick is complete!${NC}"
