#!/usr/bin/env bash

# Flatpak Helper Library
# Shared functions for Flatpak remote management and GPG repair across setup and update modules

# === Flatpak Helper Functions ===

# Ensure Flathub remote is available, preferring system scope with sudo when available
ensure_flathub_remote() {
  log "Ensuring Flathub remote is available..."
  
  # Try system scope first if we have sudo access
  if sudo -n true 2>/dev/null; then
    log "Adding Flathub remote (system scope)..."
    if ! sudo flatpak remote-add --if-not-exists --system flathub https://flathub.org/repo/flathub.flatpakrepo 2>"$LOG_FILE"; then
      log_warning "Failed to add system Flathub remote, trying user scope..."
      if ! flatpak remote-add --if-not-exists --user flathub https://flathub.org/repo/flathub.flatpakrepo 2>>"$LOG_FILE"; then
        log_error "Failed to add Flathub remote in both system and user scope"
        return 1
      else
        log "Flathub remote added (user scope)"
      fi
    else
      log "Flathub remote ensured (system scope)"
    fi
  else
    log "Adding Flathub remote (user scope - no sudo available)..."
    if ! flatpak remote-add --if-not-exists --user flathub https://flathub.org/repo/flathub.flatpakrepo 2>>"$LOG_FILE"; then
      log_error "Failed to add Flathub remote (user scope)"
      return 1
    else
      log "Flathub remote added (user scope)"
    fi
  fi
  
  return 0
}

# Attempt Flatpak update and detect GPG-related failures
attempt_flatpak_update() {
  log "Attempting Flatpak update..."
  
  local update_output
  local exit_code
  
  # Capture both output and exit code, strip ANSI escape sequences
  # Initialize exit_code to avoid unbound variable error
  exit_code=0
  update_output=$(flatpak update --user -y 2>&1 | sed 's/\x1b\[[0-9;]*[a-zA-Z]//g') || exit_code=$?
  echo "$update_output" >> "$LOG_FILE"
  
  # Check for GPG-related error patterns
  if [[ $exit_code -ne 0 ]] && echo "$update_output" | grep -iE "(GPG|signature|keyring|no such remote)" >/dev/null; then
    log_warning "Detected GPG-related Flatpak error"
    log "Error output: $update_output"
    return 1
  elif [[ $exit_code -ne 0 ]]; then
    log_error "Flatpak update failed with non-GPG error: $update_output"
    return $exit_code
  fi
  
  log "Flatpak update completed successfully"
  return 0
}

# Repair Flatpak GPG issues by deleting and re-adding remotes
repair_flatpak_gpg() {
  log "Repairing Flatpak GPG configuration..."
  
  # Delete flathub remote from both scopes if present
  log "Removing existing Flathub remotes..."
  
  # Try to remove system remote
  if sudo -n true 2>/dev/null; then
    sudo flatpak remote-delete --system --force flathub 2>>"$LOG_FILE" || true
    log "Removed system Flathub remote (if it existed)"
  fi
  
  # Try to remove user remote
  flatpak remote-delete --user --force flathub 2>>"$LOG_FILE" || true
  log "Removed user Flathub remote (if it existed)"
  
  # Run flatpak repair for both scopes when possible
  log "Running Flatpak repair..."
  
  if sudo -n true 2>/dev/null; then
    if ! sudo flatpak repair --system 2>>"$LOG_FILE"; then
      log_warning "System Flatpak repair failed or had issues"
    else
      log "System Flatpak repair completed"
    fi
  fi
  
  if ! flatpak repair --user 2>>"$LOG_FILE"; then
    log_warning "User Flatpak repair failed or had issues"
  else
    log "User Flatpak repair completed"
  fi
  
  # Re-add Flathub remote
  if ! ensure_flathub_remote; then
    log_error "Failed to re-add Flathub remote after repair"
    return 1
  fi
  
  # Retry the update
  log "Retrying Flatpak update after repair..."
  if ! flatpak update --user -y 2>&1 | sed 's/\x1b\[[0-9;]*[a-zA-Z]//g' >> "$LOG_FILE"; then
    log_error "Flatpak update still failed after GPG repair"
    return 1
  fi
  
  # Optionally clean up unused packages
  log "Cleaning up unused Flatpak packages..."
  flatpak uninstall --user --unused -y 2>>"$LOG_FILE" || true
  
  log_success "Flatpak GPG repair completed successfully"
  return 0
}
