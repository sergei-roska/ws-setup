#!/usr/bin/env bash

# Lando Installation Module
# Installs Lando development environment tool


# === Load Common Library ===
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source the common library first
source "$WORKSPACE_ROOT/lib/common.sh"

begin_section "Lando Installation"
log "🛠️ Installing Lando..."

if command -v lando &> /dev/null; then
  log "Lando already installed, skipping..."
  return 0
fi

# Download and run Lando installer
log "Downloading Lando installer..."
curl -fsSL https://get.lando.dev/setup-lando.sh -o /tmp/setup-lando.sh
chmod +x /tmp/setup-lando.sh

log "Running Lando installer..."
bash /tmp/setup-lando.sh --yes

# Cleanup
rm /tmp/setup-lando.sh

log_success "Lando installed"

end_section "Lando Installation"
