#!/usr/bin/env bash
# Module: snap — Snap package manager setup and app installation.

mod::snap() {
  begin_section "Snap Applications"

  local snap_mode="${SNAP_APPS:-essential}"
  log "Snap apps mode: $snap_mode"

  if [[ "$snap_mode" == "none" ]]; then
    log "SNAP_APPS=none, skipping"
    end_section "Snap Applications"
    return 0
  fi

  # Ensure snapd is installed.
  if ! cmd_exists snap; then
    log "Installing snapd..."
    install_apt_package snapd
    if cmd_exists systemctl; then
      sudo systemctl enable --now snapd.service
      sudo systemctl enable --now snapd.socket
    fi
    [[ -L /snap ]] || sudo ln -sf /var/lib/snapd/snap /snap
  else
    log "Snap already installed"
  fi

  source "$WS_ROOT/config/apps-snap.conf"

  # Decide which apps to install.
  local -a apps_to_install=()
  case "$snap_mode" in
    essential) apps_to_install=("${SNAP_ESSENTIAL[@]}") ;;
    all)       apps_to_install=("${SNAP_ESSENTIAL[@]}" "${SNAP_OPTIONAL[@]}") ;;
    *)
      # Comma-separated list of specific app names.
      IFS=',' read -ra apps_to_install <<< "$snap_mode"
      ;;
  esac

  local -a failed=()
  for app in "${apps_to_install[@]}"; do
    app="${app// /}"  # trim
    [[ -z "$app" ]] && continue
    if snap list "$app" &>/dev/null; then
      log "$app already installed via snap, skipping"
    else
      log "Installing $app via snap..."
      if sudo snap install "$app"; then
        log_success "$app installed"
      else
        log_error "Failed to install $app"
        failed+=("$app")
      fi
    fi
  done

  if [[ ${#failed[@]} -gt 0 ]]; then
    log_warning "Failed snap apps: ${failed[*]}"
  else
    log_success "All snap applications installed"
  fi

  end_section "Snap Applications"
}
