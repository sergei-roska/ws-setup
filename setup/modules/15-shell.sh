#!/usr/bin/env bash

# Shell Enhancement Module
# Configures shell with useful aliases and environment variables


# === Load Common Library ===
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source the common library first
source "$WORKSPACE_ROOT/lib/common.sh"

begin_section "Shell Enhancement"
log "🐚 Setting up shell enhancements..."

# Check if enhancements are already added
if grep -q "=== Development Environment Setup ===" ~/.bashrc; then
  log "Shell enhancements already added, skipping..."
  return 0
fi

# Add to .bashrc
log "Adding shell enhancements to .bashrc..."
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
  echo "alias ws='cd ~/workspace-scripts'"
  echo ''
} >> ~/.bashrc

log_success "Shell enhancements added to .bashrc"

end_section "Shell Enhancement"
