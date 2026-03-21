#!/usr/bin/env bash
# Module: claude — Claude Code CLI.

mod::claude() {
  begin_section "Claude Code Installation"

  if cmd_exists claude; then
    log_skip "Claude Code"
    end_section "Claude Code Installation"
    return 0
  fi

  log "Running Claude Code installer..."
  curl -fsSL https://claude.ai/install.sh | bash

  log_success "Claude Code installed"
  end_section "Claude Code Installation"
}
