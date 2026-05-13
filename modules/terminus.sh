#!/usr/bin/env bash
# Module: terminus — Terminus CLI for Pantheon.

mod::terminus() {
  begin_section "Terminus Installation"

  if cmd_exists terminus; then
    log_skip "Terminus"; end_section "Terminus Installation"; return 0
  fi

  log "Downloading Terminus..."
  curl -O https://github.com/pantheon-systems/terminus/releases/latest/download/terminus.phar
  chmod +x terminus.phar
  sudo mv terminus.phar /usr/local/bin/terminus

  log "Installing Terminus build tools plugin..."
  terminus self:plugin:install terminus-build-tools-plugin || true

  log_success "Terminus installed"
  end_section "Terminus Installation"
}
