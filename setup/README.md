# Setup Scripts

This directory contains the modular installation system for setting up development environments.

## Core Files

- **`install.sh`** - Main installation orchestrator with module management
- **`modules/`** - Individual installation modules (00-15)
- **`config/`** - Configuration files and templates

## Installation Modules

The setup system is organized into numbered modules that run sequentially:

1. **00-prereqs.sh** - Base packages and dependencies
2. **01-drivers.sh** - Hardware drivers
3. **02-snap-remove.sh** - Optional Snap package removal
4. **03-flatpak.sh** - Flatpak installation and setup
5. **04-flatpak-apps.sh** - Flatpak application installation
6. **05-git-ssh.sh** - Git and SSH configuration
7. **06-docker.sh** - Docker installation
8. **07-lando.sh** - Lando installation
9. **08-ddev.sh** - DDEV installation
10. **09-php.sh** - PHP 8.4 installation
11. **10-composer.sh** - Composer installation
12. **11-phpcs-drupal.sh** - PHP CodeSniffer and Drupal standards
13. **12-node-nvm.sh** - Node.js and NVM
14. **13-brew.sh** - Homebrew installation
15. **14-terminus.sh** - Terminus CLI
16. **15-shell.sh** - Shell environment configuration

## Flatpak Application Configuration

**Module**: `modules/04-flatpak-apps.sh`

Flatpak applications are configured using three arrays with inline comments for easy management:

### Application Groups

#### Essential Applications (`ESSENTIAL_APPS`)
Core applications that most users need:
- Email client (Thunderbird)
- Office suite (LibreOffice)
- Media player (VLC)
- Password manager (KeePassXC)
- Code editor (VS Code)

#### Development Applications (`DEV_APPS`)
Development-focused tools:
- IDEs (PHPStorm)
- Communication (Slack, Zoom)
- Version control (GitKraken, GitHub Desktop)
- Note-taking (Obsidian)

#### Optional Applications (`OPTIONAL_APPS`)
Additional applications for specific use cases:
- Creative tools (GIMP, Kdenlive, OBS)
- Entertainment (Discord, Spotify)
- Utilities (System monitor, Weather, VPN clients)
- Games and other specialized software

### Configuration Examples

#### Adding New Applications
Edit the appropriate array in `modules/04-flatpak-apps.sh`:

```bash
ESSENTIAL_APPS=(
  "com.visualstudio.code"         # VS Code
  "com.brave.Browser"             # Brave Browser
  "your.new.app"                  # Your App Description
)
```

#### Removing Applications
Comment out or delete lines from the arrays:

```bash
DEV_APPS=(
  "com.jetbrains.PhpStorm"        # PHPStorm IDE
  # "com.slack.Slack"               # Slack (disabled)
  "com.axosoft.GitKraken"         # Git GUI
)
```

#### Selective Group Installation
Use the `APP_GROUPS` environment variable:

```bash
# Install only essential apps
APP_GROUPS="essential" ./install.sh

# Install essential and development apps
APP_GROUPS="essential,development" ./install.sh

# Install essential and optional apps (skip development)
APP_GROUPS="essential,optional" ./install.sh

# Install all groups (default behavior)
APP_GROUPS="all" ./install.sh
```

### Supported Group Names

- `essential` - Installs ESSENTIAL_APPS
- `development` or `dev` - Installs DEV_APPS  
- `optional` - Installs OPTIONAL_APPS
- `all` - Installs all groups (default)

### Usage Examples

```bash
# Run full setup with custom app groups
APP_GROUPS="essential,dev" ./install.sh --yes

# Install only Flatpak apps module with specific groups
APP_GROUPS="essential,optional" ./install.sh --only 04-flatpak-apps

# Non-interactive setup with essential apps only
export APP_GROUPS="essential"
./install.sh --yes
```

## Legacy Scripts

- **`web-setup-enhanced.sh`** - Legacy wrapper (now uses modular system)
- **`web-setup-enhanced-old.sh`** - Original monolithic script (deprecated)
