#!/usr/bin/env bash

# Terminus Installation Module
# Installs Terminus CLI for Pantheon


# === Load Common Library ===
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source the common library first
source "$WORKSPACE_ROOT/lib/common.sh"

begin_section "Terminus Installation"
log "🧩 Installing Terminus (Pantheon CLI)..."

if command -v terminus &> /dev/null; then
  log "Terminus already installed, skipping..."
  return 0
fi

# Download and install Terminus
log "Downloading Terminus..."
curl -O https://github.com/pantheon-systems/terminus/releases/latest/download/terminus.phar
chmod +x terminus.phar
sudo mv terminus.phar /usr/local/bin/terminus

# Install build tools plugin
log "Installing Terminus build tools plugin..."
terminus self:plugin:install terminus-build-tools-plugin || true

log_success "Terminus installed"

end_section "Terminus Installation"
