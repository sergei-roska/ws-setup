#!/usr/bin/env bash

# Node.js and NVM Installation Module
# Installs NVM and Node.js LTS with global packages


# === Load Common Library ===
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source the common library first
source "$WORKSPACE_ROOT/lib/common.sh"

begin_section "Node.js and NVM Installation"
log "🟢 Installing NVM and Node.js..."

if [[ -d "$HOME/.nvm" ]]; then
  log "NVM already installed, skipping..."
  return 0
fi

# Install NVM
log "Installing NVM..."
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash

# Source NVM
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

# Install latest LTS Node.js
log "Installing Node.js LTS..."
nvm install --lts
nvm alias default node
nvm use default

# Install global packages
log "Installing global npm packages..."
GLOBAL_PACKAGES=(
  yarn
  pnpm
  npm-check-updates
  eslint
  prettier
  serve
  vite
)

for package in "${GLOBAL_PACKAGES[@]}"; do
  npm install -g "$package"
done

log_success "NVM and Node.js installed"

end_section "Node.js and NVM Installation"
