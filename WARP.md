# WARP.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

## Project Overview

Ubuntu Toolbox is a collection of modular Bash scripts for Ubuntu/Linux server administration. The project uses a "LEGO brick" philosophy where each script is self-contained, focused on a single purpose, and can work independently or with other scripts.

### Architecture

The repository has two execution modes:

1. **Remote Execution**: Users can run the interactive menu directly from GitHub using a one-liner that downloads and executes scripts on-the-fly
2. **Local Execution**: Users can clone the repo and run individual scripts manually

All scripts are designed to:
- Download dependencies from GitHub's raw content URLs when needed
- Use a consistent temp directory (`/tmp/ubuntu-toolbox`)
- Self-elevate to sudo if required
- Provide interactive menus with color-coded output

### Directory Structure

```
scripts/
├── installers/       # Application installers (NextDNS, Nextcloud, Docker, Restic, Borg)
│   ├── nextcloud/    # Multi-script installer with submenu
│   ├── nextdns/
│   ├── docker/
│   ├── restic/
│   └── borg/
├── setup/            # Initial server configuration scripts
├── security/         # SSH hardening, Fail2Ban, GitHub SSH key import
└── maintenance/      # System updates, backup setup
```

### Key Design Patterns

**Menu System**: `toolbox.sh` is the main launcher. Some categories (like `nextcloud` and `initial-setup`) have their own submenus. Menus:
- Download scripts from GitHub on-demand using curl
- Execute scripts in `/tmp/ubuntu-toolbox` 
- Clean up temporary files after execution
- Use consistent color scheme (BLUE for headers, GREEN for success, RED for errors, YELLOW for warnings, CYAN for info)

**Script Self-Sufficiency**: Each script:
- Includes `set -e` for fail-fast behavior
- Checks for sudo and re-executes itself if needed: `if [ "$EUID" -ne 0 ]; then exec sudo "$0" "$@"; fi`
- Creates backups before modifying system files (e.g., `ssh-hardening.sh` backs up `/etc/ssh/sshd_config`)
- Validates configurations before applying (e.g., `sshd -t` before restarting SSH)
- Uses clear section headers and emoji for readability

**Configuration Management**: Scripts that modify system configs:
- Append timestamped headers to indicate changes
- Use sed to remove existing/commented settings before adding new ones
- Create dated backup files (e.g., `file.backup.20231230_142530`)

## Common Development Commands

### Testing Scripts Locally

To test individual scripts without pushing to GitHub:

```bash
# Make script executable
chmod +x scripts/category/script-name.sh

# Run directly
./scripts/category/script-name.sh

# Or with sudo if needed
sudo ./scripts/category/script-name.sh
```

### Testing Menu Flow

To test the main menu locally (requires modifying REPO_URL temporarily):

```bash
# Test main toolbox launcher
./toolbox.sh
```

### Code Style

All scripts follow these conventions:
- Bash shebang: `#!/bin/bash`
- Color definitions at the top (RED, GREEN, YELLOW, BLUE, CYAN, NC)
- `set -e` for error handling
- Box-drawing characters for banners using Unicode box-drawing
- Functions named with underscores: `show_menu()`, `run_script()`, etc.
- Local variables in functions: `local variable_name=$1`

## Target Environment

- **Primary**: Ubuntu 24.04 LTS (Noble Numbat)
- **Also supports**: Ubuntu 22.04 LTS (Jammy Jellyfish), Ubuntu 20.04 LTS (Focal Fossa)
- **Execution context**: Designed to run on Ubuntu servers, often in remote/headless environments
- **User expectation**: Scripts should work with minimal or no user interaction when run with default options

## Adding New Scripts

When creating new scripts:

1. **Category Placement**: Place scripts in the appropriate category folder (installers/setup/security/maintenance)
2. **Naming**: Use lowercase with hyphens (e.g., `configure-firewall.sh`)
3. **Header Pattern**: Include LEGO brick emoji and clear description in comments
4. **Error Handling**: Use `set -e` and validate operations before applying changes
5. **Sudo Handling**: Include self-elevation check
6. **Backup Critical Files**: Before modifying system configs
7. **User Confirmation**: Ask for confirmation on destructive operations
8. **Update Menus**: Add the new script to relevant menu(s) in `toolbox.sh` or submenu scripts
9. **Test Commands**: Include usage examples or helpful commands at script completion
10. **Modular Design**: Script should work independently and not require other scripts

## Repository Metadata

- **Main Branch**: `main`
- **GitHub URL**: https://github.com/MaBoNi/ubuntu-toolbox
- **License**: MIT
- **Author**: MaBoNi

## Important Notes

- Scripts download and execute from the main branch on GitHub, so changes take effect immediately after push
- No test suite currently exists - testing is done manually on target Ubuntu versions
- Scripts are designed for system administration and require root/sudo access
- The repository does not use package managers or build tools - pure Bash scripts only
