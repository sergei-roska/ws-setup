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
  # The keepalive must never touch the terminal: -n makes sudo fail instead of
  # prompting (a prompt would steal the user's keystrokes), and all three
  # standard streams are detached (also keeps "install.sh | tee" from waiting
  # on a pipe held open by the background loop). If a refresh fails, the loop
  # just ends.
  (
    while true; do
      sudo -n -v || exit 0
      sleep 60
      # Exit if parent process is gone (orphan protection).
      kill -0 "$parent_pid" 2>/dev/null || exit 0
    done
  ) </dev/null >/dev/null 2>&1 &
  _SUDO_KEEPALIVE_PID=$!
  log "Sudo keepalive started (PID: $_SUDO_KEEPALIVE_PID)"
}

stop_sudo_keepalive() {
  if [[ -n "${_SUDO_KEEPALIVE_PID:-}" ]]; then
    kill "$_SUDO_KEEPALIVE_PID" 2>/dev/null || true
    unset _SUDO_KEEPALIVE_PID
  fi
}
