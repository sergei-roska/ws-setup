#!/usr/bin/env bash
# Module: phpcs - PHP CodeSniffer and Drupal coding standards (drupal/coder).

mod::phpcs() {
  begin_section "PHP CodeSniffer and Drupal Standards"

  require_cmd composer

  # drupal/coder pulls squizlabs/php_codesniffer and the installer plugin that
  # registers the Drupal and DrupalPractice standards with phpcs.
  log "Allowing the PHPCS standards installer plugin..."
  composer global config --no-interaction \
    allow-plugins.dealerdirect/phpcodesniffer-composer-installer true

  log "Installing drupal/coder globally..."
  composer global require --no-interaction drupal/coder

  # Make sure phpcs is reachable for the check below.
  local bin_dir
  bin_dir=$(composer global config bin-dir --absolute --quiet)
  case ":$PATH:" in
    *":$bin_dir:"*) ;;
    *) export PATH="$bin_dir:$PATH" ;;
  esac

  local standards
  if ! standards=$(phpcs -i); then
    log_error "phpcs is not usable after installing drupal/coder"
    return 1
  fi
  log "$standards"

  local std
  for std in Drupal DrupalPractice; do
    if ! grep -qw "$std" <<< "$standards"; then
      log_error "PHPCS standard $std is not registered"
      return 1
    fi
  done

  log_success "PHPCS and Drupal standards installed"
  end_section "PHP CodeSniffer and Drupal Standards"
}
