#!/usr/bin/env bash
# Module: node — NVM, Node.js LTS, and global npm packages.

mod::node() {
  begin_section "Node.js and NVM Installation"

  source "$WS_ROOT/config/node.conf"

  export NVM_DIR="$HOME/.nvm"
  if [[ -d "$NVM_DIR" ]]; then
    log "NVM already installed"
  else
    log "Installing NVM ${NVM_INSTALL_VERSION}..."
    curl -o- "https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_INSTALL_VERSION}/install.sh" | bash
  fi

  # shellcheck source=/dev/null
  [[ -s "$NVM_DIR/nvm.sh" ]] && \. "$NVM_DIR/nvm.sh" || die "nvm.sh not found in $NVM_DIR"

  if cmd_exists node; then
    log "Node.js already installed"
  else
    log "Installing Node.js LTS..."
    nvm install --lts
    nvm alias default node
  fi
  nvm use default >/dev/null

  log "Installing global npm packages..."
  for package in "${NPM_GLOBAL_PACKAGES[@]}"; do
    npm install -g "$package"
  done

  log_success "Node.js tooling installed"
  end_section "Node.js and NVM Installation"
}
