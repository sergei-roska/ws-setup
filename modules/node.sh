#!/usr/bin/env bash
# Module: node — NVM, Node.js LTS, and global npm packages.

# nvm.sh is not written for "set -u", and many nvm commands return non-zero
# in normal operation.  Run them with nounset off and in an || list, where
# errexit and the ERR trap are suspended, and hand the status back so the
# caller can check it explicitly.
_nvm_run() {
  local rc=0
  set +u
  "$@" || rc=$?
  set -u
  return "$rc"
}

mod::node() {
  begin_section "Node.js and NVM Installation"

  source "$WS_ROOT/config/node.conf"

  export NVM_DIR="$HOME/.nvm"
  if [[ -d "$NVM_DIR" ]]; then
    log "NVM already installed"
  else
    log "Installing NVM ${NVM_INSTALL_VERSION}..."
    curl -fsSo- "https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_INSTALL_VERSION}/install.sh" | bash
  fi

  [[ -s "$NVM_DIR/nvm.sh" ]] || die "nvm.sh not found in $NVM_DIR"
  # shellcheck source=/dev/null
  _nvm_run source "$NVM_DIR/nvm.sh" || die "Failed to load nvm.sh"

  if cmd_exists node; then
    log "Node.js already installed"
  else
    log "Installing Node.js LTS..."
    _nvm_run nvm install --lts || die "nvm install --lts failed"
    _nvm_run nvm alias default node || die "nvm alias default failed"
  fi
  _nvm_run nvm use default >/dev/null || die "nvm use default failed"

  log "Installing global npm packages..."
  for package in "${NPM_GLOBAL_PACKAGES[@]}"; do
    npm install -g "$package"
  done

  log_success "Node.js tooling installed"
  end_section "Node.js and NVM Installation"
}
