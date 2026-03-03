#!/usr/bin/env bash
# Module: drivers — hardware driver installation.

mod::drivers() {
  begin_section "Hardware Drivers"

  if ! cmd_exists ubuntu-drivers; then
    log_warning "ubuntu-drivers not available, skipping driver installation"
    end_section "Hardware Drivers"
    return 0
  fi

  log "Detecting recommended drivers..."
  local recommended
  recommended=$(ubuntu-drivers devices 2>/dev/null || true)

  if [[ -z "$recommended" ]]; then
    log "No recommended drivers found, skipping"
    end_section "Hardware Drivers"
    return 0
  fi

  echo "$recommended"

  if [[ "${NON_INTERACTIVE:-false}" != "true" ]]; then
    confirm_yes "Install recommended drivers?" || {
      log "Driver installation skipped by user"
      end_section "Hardware Drivers"
      return 0
    }
  fi

  log "Installing recommended drivers..."
  sudo ubuntu-drivers autoinstall

  log_success "Hardware drivers installed"
  end_section "Hardware Drivers"
}
