#!/usr/bin/env bash
# Module: php — PHP installation with extensions from config.

mod::php() {
  begin_section "PHP Installation"

  if cmd_exists php; then
    log_skip "PHP"; end_section "PHP Installation"; return 0
  fi

  source "$WS_ROOT/config/php.conf"
  local base="php${PHP_VERSION}"

  log "Adding PHP PPA..."
  sudo add-apt-repository ppa:ondrej/php -y
  sudo apt-get update -y

  # Install base package and each extension.
  install_apt_package "$base"
  for ext in "${PHP_EXTENSIONS[@]}"; do
    install_apt_package "${base}-${ext}"
  done

  log_success "PHP ${PHP_VERSION} installed"
  end_section "PHP Installation"
}
