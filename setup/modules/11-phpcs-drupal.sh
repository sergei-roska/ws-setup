#!/usr/bin/env bash

# PHP CodeSniffer and Drupal Standards Module
# Installs and configures PHPCS with Drupal coding standards


# === Load Common Library ===
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source the common library first
source "$WORKSPACE_ROOT/lib/common.sh"

begin_section "PHP CodeSniffer and Drupal Standards"
log "📏 Installing PHP CodeSniffer and Drupal standards..."

# Call the existing installer script
PHPCS_INSTALLER="$WORKSPACE_ROOT/setup/install-phpcs-drupal.sh"

if [[ -f "$PHPCS_INSTALLER" && -x "$PHPCS_INSTALLER" ]]; then
  log "Running existing PHPCS Drupal installer..."
  bash "$PHPCS_INSTALLER"
  log_success "PHPCS and Drupal standards installed"
else
  log_error "PHPCS Drupal installer not found: $PHPCS_INSTALLER"
  return 1
fi

end_section "PHP CodeSniffer and Drupal Standards"
