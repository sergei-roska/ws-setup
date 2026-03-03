#!/usr/bin/env bash
# Module: lando — Lando development environment.

mod::lando() {
  begin_section "Lando Installation"

  if cmd_exists lando; then
    log_skip "Lando"; end_section "Lando Installation"; return 0
  fi

  log "Downloading Lando installer..."
  curl -fsSL https://get.lando.dev/setup-lando.sh -o /tmp/setup-lando.sh
  chmod +x /tmp/setup-lando.sh

  log "Running Lando installer..."
  bash /tmp/setup-lando.sh --yes
  rm -f /tmp/setup-lando.sh

  log_success "Lando installed"
  end_section "Lando Installation"
}
