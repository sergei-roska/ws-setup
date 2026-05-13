#!/usr/bin/env bash
# Module: composer — Composer installation and global packages.

mod::composer() {
  begin_section "Composer Installation"

  if ! cmd_exists composer; then
    log "Downloading Composer installer..."
    local expected actual
    expected=$(curl -s https://composer.github.io/installer.sig)
    php -r "copy('https://getcomposer.org/installer', '/tmp/composer-setup.php');"
    actual=$(php -r "echo hash_file('sha384', '/tmp/composer-setup.php');")

    if [[ "$expected" == "$actual" ]]; then
      log "Composer installer verified"
      sudo php /tmp/composer-setup.php --install-dir=/usr/local/bin --filename=composer
      rm -f /tmp/composer-setup.php
      log_success "Composer installed"
    else
      log_error "Composer installer verification failed"
      rm -f /tmp/composer-setup.php
      return 1
    fi
  else
    log_skip "Composer"
  fi

  # Global packages from config.
  source "$WS_ROOT/config/composer.conf"
  log "Installing global Composer packages..."
  for package in "${COMPOSER_GLOBAL_PACKAGES[@]}"; do
    if composer global show "$package" &>/dev/null; then
      log "$package already installed globally, skipping"
    else
      log "Installing global package: $package"
      if composer global require "$package" --no-interaction; then
        log_success "$package installed globally"
      else
        log_error "Failed to install $package"
      fi
    fi
  done

  # Ensure global bin is in PATH (check .bashrc to avoid duplicates).
  local bin_dir="$HOME/.config/composer/vendor/bin"
  if [[ -d "$bin_dir" ]] && ! grep -q "composer/vendor/bin" "$HOME/.bashrc" 2>/dev/null; then
    log "Adding Composer global bin to PATH..."
    echo "export PATH=\"$bin_dir:\$PATH\"" >> "$HOME/.bashrc"
    export PATH="$bin_dir:$PATH"
    log_success "Composer bin directory added to PATH"
  fi

  log_success "Composer and global packages installation completed"
  end_section "Composer Installation"
}
