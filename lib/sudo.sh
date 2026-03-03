#!/usr/bin/env bash
# Sudo privilege management and keepalive.
# Sourced by install.sh; do not execute directly.

require_sudo() {
  if ! sudo -n true 2>/dev/null; then
    log "This script requires sudo privileges"
    sudo -v || die "Failed to obtain sudo privileges"
  fi
}

start_sudo_keepalive() {
  if [[ -n "${_SUDO_KEEPALIVE_PID:-}" ]]; then return 0; fi

  local parent_pid=$$
  log "Starting sudo keepalive background process..."
  (
    while true; do
      # Refresh credentials first, then sleep.
      sudo -v 2>/dev/null || exit 1
      sleep 60
      # Exit if parent process is gone (orphan protection).
      kill -0 "$parent_pid" 2>/dev/null || exit 0
    done
  ) &
  _SUDO_KEEPALIVE_PID=$!
  log "Sudo keepalive started (PID: $_SUDO_KEEPALIVE_PID)"
}

stop_sudo_keepalive() {
  if [[ -n "${_SUDO_KEEPALIVE_PID:-}" ]]; then
    kill "$_SUDO_KEEPALIVE_PID" 2>/dev/null || true
    unset _SUDO_KEEPALIVE_PID
  fi
}
