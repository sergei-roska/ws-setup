#!/usr/bin/env bash
# Module: prereqs — base packages and essential tools.

mod::prereqs() {
  begin_section "Prerequisites and Base Packages"

  check_os
  require_not_root
  require_cmd curl

  # Connectivity check.
  if ! check_internet; then
    die "Internet connectivity check failed. Please check your network connection."
  fi
  log_success "Internet connectivity verified"

  # Backup dotfiles.
  local -a dotfiles=("$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.gitconfig" "$HOME/.ssh/config")
  for f in "${dotfiles[@]}"; do
    backup_file "$f"
  done

  # Update package lists (no upgrade — explicit opt-in via env var).
  export DEBIAN_FRONTEND=noninteractive
  log "Updating package lists..."
  sudo apt-get update -y
  if [[ "${WS_UPGRADE:-false}" == "true" ]]; then
    log "WS_UPGRADE=true, upgrading all packages..."
    sudo apt-get upgrade -y
  else
    log "Skipping apt upgrade (set WS_UPGRADE=true to enable)"
  fi

  # Install base packages from config.
  source "$WS_ROOT/config/packages.conf"
  log "Installing base packages..."
  for package in "${ESSENTIAL_PACKAGES[@]}"; do
    install_apt_package "$package"
  done

  log_success "Prerequisites and base packages installed"
  end_section "Prerequisites and Base Packages"
}
