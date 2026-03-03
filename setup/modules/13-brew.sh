#!/usr/bin/env bash

# Homebrew Installation Module
# Installs Homebrew for Linux


# === Load Common Library ===
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source the common library first
source "$WORKSPACE_ROOT/lib/common.sh"

begin_section "Homebrew Installation"
log "🍺 Installing Homebrew..."

if command -v brew &> /dev/null; then
  log "Homebrew already installed, skipping..."
  return 0
fi

# Install Homebrew
log "Running Homebrew installer..."
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Add to PATH
if ! grep -q "/home/linuxbrew/.linuxbrew/bin/brew" ~/.bashrc; then
  echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >> ~/.bashrc
fi

# Source for current session
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"

log_success "Homebrew installed"

end_section "Homebrew Installation"
