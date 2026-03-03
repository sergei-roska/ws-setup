#!/usr/bin/env bash

# Flatpak Setup Module
# Installs Flatpak and adds Flathub repository

# === Load Common Library ===
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source the common library first
source "$WORKSPACE_ROOT/lib/common.sh"

# Source shared Flatpak library
source "$WORKSPACE_ROOT/lib/flatpak.sh"

begin_section "Flatpak Setup"
log "🧧 Installing Flatpak and adding Flathub repository..."

# Install Flatpak and GNOME Software plugin
install_apt_package flatpak
install_apt_package gnome-software-plugin-flatpak

# Add Flathub repository using shared helper function
ensure_flathub_remote

log_success "Flatpak setup completed"
end_section "Flatpak Setup"
