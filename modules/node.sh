#!/usr/bin/env bash
# Module: node — NVM, Node.js LTS, and global npm packages.

mod::node() {
  begin_section "Node.js and NVM Installation"

  if [[ -d "$HOME/.nvm" ]]; then
    log_skip "NVM"; end_section "Node.js and NVM Installation"; return 0
  fi

  source "$WS_ROOT/config/node.conf"

  log "Installing NVM ${NVM_INSTALL_VERSION}..."
  curl -o- "https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_INSTALL_VERSION}/install.sh" | bash

  export NVM_DIR="$HOME/.nvm"
  # shellcheck source=/dev/null
  [[ -s "$NVM_DIR/nvm.sh" ]] && \. "$NVM_DIR/nvm.sh"

  log "Installing Node.js LTS..."
  nvm install --lts
  nvm alias default node
  nvm use default

  log "Installing global npm packages..."
  for package in "${NPM_GLOBAL_PACKAGES[@]}"; do
    npm install -g "$package"
  done

  log_success "NVM and Node.js installed"
  end_section "Node.js and NVM Installation"
}
