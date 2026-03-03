#!/usr/bin/env bash
# Module: shell — shell aliases and environment configuration.

mod::shell() {
  begin_section "Shell Enhancement"

  if grep -q "=== Development Environment Setup ===" "$HOME/.bashrc" 2>/dev/null; then
    log_skip "Shell enhancements"; end_section "Shell Enhancement"; return 0
  fi

  log "Adding shell enhancements to .bashrc..."
  # shellcheck disable=SC2016
  {
    echo ''
    echo '# === Development Environment Setup ==='
    echo 'export PATH="$HOME/.config/composer/vendor/bin:$PATH"'
    echo 'export NVM_DIR="$HOME/.nvm"'
    echo '[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"'
    echo '[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"'
    echo ''
    echo '# Development Aliases'
    echo "alias ll='ls -alF'"
    echo "alias la='ls -A'"
    echo "alias l='ls -CF'"
    echo "alias gs='git status'"
    echo "alias gl='git log --oneline'"
    echo "alias gp='git pull'"
    echo "alias ddev-up='ddev start && ddev ssh'"
    echo "alias lando-up='lando start && lando ssh'"
    echo ''
  } >> "$HOME/.bashrc"

  log_success "Shell enhancements added to .bashrc"
  end_section "Shell Enhancement"
}
