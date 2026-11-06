#!/usr/bin/env bash
# Module: php - PHP installation with extensions from config.

# Returns 0 when apt has an install candidate for the given package.
php_has_candidate() {
  local candidate
  candidate=$(apt-cache policy "$1" 2>/dev/null | awk '/Candidate:/ {print $2}')
  [[ -n "$candidate" && "$candidate" != "(none)" ]]
}

# install_apt_package returns 0 even when apt-get fails, so verify the result.
php_install_package() {
  install_apt_package "$1"
  if ! dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -q "install ok installed"; then
    log_error "Package $1 is not installed"
    return 1
  fi
}

mod::php() {
  begin_section "PHP Installation"

  if cmd_exists php; then
    log_skip "PHP"; end_section "PHP Installation"; return 0
  fi

  source "$WS_ROOT/config/php.conf"
  local base="php${PHP_VERSION}"

  if ! sudo apt-get update -y; then
    log_error "apt-get update failed"
    end_section "PHP Installation"; return 1
  fi

  # Ubuntu 26.04 ships PHP natively; older releases need ppa:ondrej/php.
  if ! php_has_candidate "${base}-cli"; then
    log "${base} is not available from configured repositories, adding PHP PPA..."
    if ! sudo add-apt-repository ppa:ondrej/php -y; then
      log_error "Failed to add ppa:ondrej/php"
      end_section "PHP Installation"; return 1
    fi
    if ! sudo apt-get update -y; then
      log_error "apt-get update failed after adding PHP PPA"
      end_section "PHP Installation"; return 1
    fi
    if ! php_has_candidate "${base}-cli"; then
      log_error "${base}-cli has no install candidate even with PHP PPA"
      end_section "PHP Installation"; return 1
    fi
  fi

  # Install base package and each extension.
  local failed=0
  php_install_package "$base" || failed=1
  for ext in "${PHP_EXTENSIONS[@]}"; do
    php_install_package "${base}-${ext}" || failed=1
  done

  if (( failed )); then
    log_error "PHP ${PHP_VERSION} installation incomplete"
    end_section "PHP Installation"; return 1
  fi

  log_success "PHP ${PHP_VERSION} installed"
  end_section "PHP Installation"
}
