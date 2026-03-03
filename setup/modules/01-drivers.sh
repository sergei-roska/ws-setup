#!/usr/bin/env bash

# Hardware Drivers Module
# Installs recommended hardware drivers

# === Load Common Library ===
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source the common library first
source "$WORKSPACE_ROOT/lib/common.sh"

begin_section "Hardware Drivers"
log "🖥️ Installing recommended hardware drivers..."

if command -v ubuntu-drivers &> /dev/null; then
  log "Detecting recommended drivers..."
  ubuntu-drivers devices
  
  log "Installing recommended drivers..."
  sudo ubuntu-drivers autoinstall
  
  log_success "Hardware drivers installed"
else
  log_warning "ubuntu-drivers not available, skipping driver installation"
fi

log_success "Hardware drivers setup completed"

end_section "Hardware Drivers"
