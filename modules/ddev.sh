#!/usr/bin/env bash
# Module: ddev — DDEV development environment.

mod::ddev() {
  begin_section "DDEV Installation"

  if cmd_exists ddev; then
    log_skip "DDEV"; end_section "DDEV Installation"; return 0
  fi

  log "Running DDEV installer..."
  curl -fsSL https://ddev.com/install.sh | bash

  log_success "DDEV installed"
  end_section "DDEV Installation"
}
