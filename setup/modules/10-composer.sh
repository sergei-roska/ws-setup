#!/usr/bin/env bash

# Composer Installation Module
# Installs Composer with signature verification


# === Load Common Library ===
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source the common library first
source "$WORKSPACE_ROOT/lib/common.sh"

begin_section "Composer Installation"
log "🎼 Installing Composer..."

# Check if Composer is already installed
composer_already_installed=false
if command -v composer &> /dev/null; then
  log "Composer already installed, skipping installation..."
  composer_already_installed=true
else
  # Download and verify Composer installer
  log "Downloading Composer installer..."
  EXPECTED_HASH=$(curl -s https://composer.github.io/installer.sig)
  php -r "copy('https://getcomposer.org/installer', '/tmp/composer-setup.php');"
  ACTUAL_HASH=$(php -r "echo hash_file('sha384', '/tmp/composer-setup.php');")

  if [[ "$EXPECTED_HASH" == "$ACTUAL_HASH" ]]; then
    log "Composer installer verified"
    sudo php /tmp/composer-setup.php --install-dir=/usr/local/bin --filename=composer
    rm /tmp/composer-setup.php
    log_success "Composer installed"
  else
    log_error "Composer installer verification failed"
    rm /tmp/composer-setup.php
    return 1
  fi
fi

# === Install Global Composer Packages ===
log "Installing essential global Composer packages..."

# List of essential global packages for PHP development
# Note: phpcs/phpcbf are installed in 11-phpcs-drupal.sh module
GLOBAL_PACKAGES=(
  "phpstan/phpstan"               # PHPStan static analysis
  "vimeo/psalm"                   # Psalm static analysis  
  "friendsofphp/php-cs-fixer"     # PHP-CS-Fixer code formatter
)

# Install each package if not already installed
for package in "${GLOBAL_PACKAGES[@]}"; do
  package_name=$(echo "$package" | cut -d'/' -f2)
  
  if composer global show "$package" &>/dev/null; then
    log "$package already installed globally, skipping..."
  else
    log "Installing global package: $package"
    if composer global require "$package" --no-interaction; then
      log_success "$package installed globally"
    else
      log_error "Failed to install $package"
    fi
  fi
done

# Ensure Composer global bin directory is in PATH
COMPOSER_BIN_DIR="$HOME/.config/composer/vendor/bin"
if [[ -d "$COMPOSER_BIN_DIR" ]]; then
  if [[ ":$PATH:" != *":$COMPOSER_BIN_DIR:"* ]]; then
    log "Adding Composer global bin directory to PATH..."
    echo "export PATH=\"$COMPOSER_BIN_DIR:\$PATH\"" >> "$HOME/.bashrc"
    export PATH="$COMPOSER_BIN_DIR:$PATH"
    log_success "Composer bin directory added to PATH"
  else
    log "Composer global bin directory already in PATH"
  fi
fi

log_success "Composer and global packages installation completed"

end_section "Composer Installation"
