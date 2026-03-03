#!/usr/bin/env bash
# Module: flatpak — install Flatpak and add Flathub remote.

mod::flatpak() {
  begin_section "Flatpak Setup"

  install_apt_package flatpak
  install_apt_package gnome-software-plugin-flatpak

  ensure_flathub_remote

  log_success "Flatpak setup completed"
  end_section "Flatpak Setup"
}
