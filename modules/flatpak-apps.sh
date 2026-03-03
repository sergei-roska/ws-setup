#!/usr/bin/env bash
# Module: flatpak-apps — install Flatpak applications by group.

mod::flatpak-apps() {
  begin_section "Flatpak Applications"

  local groups="${APP_GROUPS:-all}"
  log "Installing Flatpak app groups: $groups"

  source "$WS_ROOT/config/apps-flatpak.conf"

  _should_install_group() {
    local g="$1"
    [[ "$groups" == "all" ]] || [[ "$groups" =~ (^|,)$g($|,) ]]
  }

  _install_group() {
    local label="$1"; shift
    local -a apps=("$@")
    log "Installing $label applications..."
    for app_id in "${apps[@]}"; do
      install_flatpak_app "$app_id"
    done
  }

  _should_install_group "essential"                                  && _install_group "Essential" "${FLATPAK_ESSENTIAL[@]}"
  { _should_install_group "development" || _should_install_group "dev"; } && _install_group "Development" "${FLATPAK_DEV[@]}"
  _should_install_group "optional"                                   && _install_group "Optional" "${FLATPAK_OPTIONAL[@]}"

  log_success "Flatpak applications installation completed"
  end_section "Flatpak Applications"
}
