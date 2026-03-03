#!/usr/bin/env bash

# DDEV Installation Module
# Installs DDEV development environment tool


# === Load Common Library ===
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source the common library first
source "$WORKSPACE_ROOT/lib/common.sh"

begin_section "DDEV Installation"
log "⚙️ Installing DDEV..."

if command -v ddev &> /dev/null; then
  log "DDEV already installed, skipping..."
  return 0
fi

# Install DDEV using their installation script
log "Running DDEV installer..."
curl -fsSL https://ddev.com/install.sh | bash

log_success "DDEV installed"

end_section "DDEV Installation"
