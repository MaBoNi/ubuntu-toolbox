# 🧱 Ubuntu Toolbox

> *"Everything is awesome when you're working with scripts!"*

Welcome to the Ubuntu Toolbox - your collection of LEGO-like building blocks for Ubuntu/Linux server administration! Each script is designed to snap together perfectly, helping you build and maintain your infrastructure piece by piece.

## 🏗️ What's in the Box?

This toolbox contains modular scripts and utilities for common Ubuntu server tasks. Each tool is designed to:
- 🔧 Work independently (like a good LEGO brick)
- 📝 Be well-documented and easy to understand
- 🎯 Solve a specific problem
- 🔗 Play nicely with other tools

## 📦 Available Bricks

### 📦 Installers
- **NextDNS** - Privacy-focused DNS resolver with automatic configuration
- **Nextcloud** - Complete LAMP stack + Nextcloud installation
- **Docker** - Coming soon!

### 🚀 Setup
- **Configure APT Cacher** - Speed up package downloads with caching proxy
- **Set Hostname** - Interactive hostname configuration + network info
- **Initial Server Setup** - Interactive submenu with:
  - System updates
  - Timezone configuration
  - Root SSH disable
  - Automatic security updates
  - Swap configuration
  - Run all (complete automated setup)
- **Firewall Setup** - Coming soon!

### 🔐 Security
- **Import GitHub SSH Keys** - Fetch and import SSH keys from GitHub users
- **SSH Hardening** - Coming soon!
- **Fail2Ban** - Coming soon!

### 🔄 Maintenance
- **System Update** - Full system upgrade with cleanup
- **Backup Setup** - Coming soon!

## 🎨 How to Use

### Quick Start (One-Liner)

Run the interactive menu directly from GitHub:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/MaBoNi/ubuntu-toolbox/main/toolbox.sh)
```

### Manual Usage

Or clone and run individual scripts:

```bash
# 1. Clone the toolbox
git clone https://github.com/MaBoNi/ubuntu-toolbox.git
cd ubuntu-toolbox

# 2. Make the script executable
chmod +x scripts/installers/your-script.sh

# 3. Run it!
./scripts/installers/your-script.sh
```

## 🧩 Contributing

Got a useful script? We'd love to add it to the toolbox! Just remember:
- Keep it modular (one brick, one purpose)
- Add clear documentation
- Include error handling
- Test on Ubuntu 24.04 LTS (and note compatibility with other versions)

## 📖 Script Categories

- **🚀 Setup** - Initial server configuration and hardening
- **📦 Installers** - One-click installers for popular applications
- **🔐 Security** - Tools for securing your server
- **🔄 Maintenance** - Backup, update, and monitoring scripts
- **🌐 Network** - Network configuration and diagnostics
- **🐳 Containers** - Docker and container management

## 🎯 Requirements

Most scripts are designed for:
- Ubuntu 24.04 LTS (Noble Numbat)
- Ubuntu 22.04 LTS (Jammy Jellyfish)
- Ubuntu 20.04 LTS (Focal Fossa)

Specific requirements will be listed in each script's documentation.

## 📜 License

MIT License - Build whatever you want!

## 🤝 Credits

Built with ❤️ and 🧱 by [MaBoNi](https://github.com/MaBoNi)

---

*Remember: The best part about LEGO is that you can always rebuild it better!*
