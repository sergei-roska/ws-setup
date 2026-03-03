#!/usr/bin/env bash

# PHP Installation Module
# Installs PHP 8.4 with common extensions


# === Load Common Library ===
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source the common library first
source "$WORKSPACE_ROOT/lib/common.sh"

begin_section "PHP Installation"
log "🐘 Installing PHP 8.4..."

if command -v php &> /dev/null; then
  log "PHP already installed, skipping..."
  return 0
fi

# Add Ondrej's PHP PPA
log "Adding PHP PPA..."
sudo add-apt-repository ppa:ondrej/php -y
sudo apt update

# Install PHP 8.4 and common extensions
PHP_PACKAGES=(
  php8.4
  php8.4-cli
  php8.4-mbstring
  php8.4-xml
  php8.4-curl
  php8.4-zip
  php8.4-gd
  php8.4-mysql
  php8.4-opcache
  php8.4-intl
  php8.4-bcmath
  php8.4-fpm
)

for package in "${PHP_PACKAGES[@]}"; do
  install_apt_package "$package"
done

log_success "PHP 8.4 installed"

end_section "PHP Installation"
