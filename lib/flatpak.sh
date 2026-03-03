#!/usr/bin/env bash
# Flatpak remote management and GPG repair helpers.
# Sourced by install.sh; do not execute directly.

ensure_flathub_remote() {
  log "Ensuring Flathub remote is available..."

  if sudo -n true 2>/dev/null; then
    log "Adding Flathub remote (system scope)..."
    if ! sudo flatpak remote-add --if-not-exists --system flathub \
         https://flathub.org/repo/flathub.flatpakrepo 2>>"$LOG_FILE"; then
      log_warning "Failed to add system Flathub remote, trying user scope..."
      flatpak remote-add --if-not-exists --user flathub \
        https://flathub.org/repo/flathub.flatpakrepo 2>>"$LOG_FILE" \
        || { log_error "Failed to add Flathub remote in both scopes"; return 1; }
      log "Flathub remote added (user scope)"
    else
      log "Flathub remote ensured (system scope)"
    fi
  else
    log "Adding Flathub remote (user scope — no sudo available)..."
    flatpak remote-add --if-not-exists --user flathub \
      https://flathub.org/repo/flathub.flatpakrepo 2>>"$LOG_FILE" \
      || { log_error "Failed to add Flathub remote (user scope)"; return 1; }
    log "Flathub remote added (user scope)"
  fi
}

attempt_flatpak_update() {
  log "Attempting Flatpak update..."

  local update_output exit_code=0
  update_output=$(flatpak update --user -y 2>&1 | sed 's/\x1b\[[0-9;]*[a-zA-Z]//g') || exit_code=$?
  echo "$update_output" >> "$LOG_FILE"

  if [[ $exit_code -ne 0 ]] && echo "$update_output" | grep -iE "(GPG|signature|keyring|no such remote)" >/dev/null; then
    log_warning "Detected GPG-related Flatpak error"
    return 1
  elif [[ $exit_code -ne 0 ]]; then
    log_error "Flatpak update failed with non-GPG error: $update_output"
    return "$exit_code"
  fi

  log "Flatpak update completed successfully"
}

repair_flatpak_gpg() {
  log "Repairing Flatpak GPG configuration..."

  # Remove remotes.
  if sudo -n true 2>/dev/null; then
    sudo flatpak remote-delete --system --force flathub 2>>"$LOG_FILE" || true
  fi
  flatpak remote-delete --user --force flathub 2>>"$LOG_FILE" || true

  # Repair.
  if sudo -n true 2>/dev/null; then
    sudo flatpak repair --system 2>>"$LOG_FILE" || log_warning "System Flatpak repair had issues"
  fi
  flatpak repair --user 2>>"$LOG_FILE" || log_warning "User Flatpak repair had issues"

  # Re-add remote.
  ensure_flathub_remote || { log_error "Failed to re-add Flathub after repair"; return 1; }

  # Retry update.
  log "Retrying Flatpak update after repair..."
  flatpak update --user -y 2>&1 | sed 's/\x1b\[[0-9;]*[a-zA-Z]//g' >> "$LOG_FILE" \
    || { log_error "Flatpak update still failed after GPG repair"; return 1; }

  flatpak uninstall --user --unused -y 2>>"$LOG_FILE" || true
  log_success "Flatpak GPG repair completed successfully"
}

# Install a single Flatpak app (user scope).
install_flatpak_app() {
  local app_id="$1"
  if flatpak list --app | grep -q "$app_id"; then
    log "$app_id already installed, skipping"
  else
    log "Installing $app_id..."
    if flatpak install --user flathub -y "$app_id" --noninteractive 2>&1 \
       | sed 's/\x1b\[[0-9;]*[a-zA-Z]//g' | grep -v '^$' >> "$LOG_FILE"; then
      log "Successfully installed $app_id"
    else
      log_error "Failed to install $app_id"
      return 1
    fi
  fi
}
