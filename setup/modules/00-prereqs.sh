#!/usr/bin/env bash

# Prerequisites Module
# Installs base packages and essential tools

# === Load Common Library ===
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source the common library first
source "$WORKSPACE_ROOT/lib/common.sh"

begin_section "Prerequisites and Base Packages"
log "📦 Installing prerequisites and base packages..."

# === System Checks ===
log "Performing system checks..."
check_os
require_not_root
require_cmd sudo
require_cmd curl

# === Connectivity Check ===
log "Checking internet connectivity..."
if ! curl -s --head https://google.com > /dev/null; then
  die "Internet connectivity check failed. Please check your network connection."
fi
log_success "Internet connectivity verified"

# === Backup Dotfiles ===
log "Backing up existing dotfiles..."
DOTFILES=(
  "$HOME/.bashrc"
  "$HOME/.zshrc"
  "$HOME/.gitconfig"
  "$HOME/.ssh/config"
)

for dotfile in "${DOTFILES[@]}"; do
  backup_file "$dotfile"
done

# === Set Non-Interactive Mode ===
deb_noninteractive

# === Update package lists ===
log "Updating package lists..."
sudo apt update && sudo apt upgrade -y

# === Install essential packages ===
ESSENTIAL_PACKAGES=(
  build-essential
  curl
  git
  unzip
  zip
  wget
  software-properties-common
  ca-certificates
  gnupg
  lsb-release
  jq
  net-tools
  htop
  tree
  bash-completion
  xclip
  fonts-firacode
  libfuse2
  libnss3-tools
  zsh
  python3
  python3-pip
  gitk
  apt-transport-https
)

log "Installing base packages..."
for package in "${ESSENTIAL_PACKAGES[@]}"; do
  install_apt_package "$package"
done

log_success "Prerequisites and base packages installed"
end_section "Prerequisites and Base Packages"
