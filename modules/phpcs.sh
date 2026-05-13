#!/usr/bin/env bash
# Module: phpcs — PHP CodeSniffer and Drupal coding standards.

mod::phpcs() {
  begin_section "PHP CodeSniffer and Drupal Standards"

  local installer="$WS_ROOT/setup/install-phpcs-drupal.sh"

  if [[ -f "$installer" && -x "$installer" ]]; then
    log "Running PHPCS Drupal installer..."
    bash "$installer"
    log_success "PHPCS and Drupal standards installed"
  else
    log_warning "PHPCS installer not found at $installer, skipping"
  fi

  end_section "PHP CodeSniffer and Drupal Standards"
}
