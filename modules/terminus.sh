#!/usr/bin/env bash
# Module: terminus - Terminus CLI for Pantheon.

# Print the installed Terminus version. Fails when terminus is missing, cannot
# run, or prints something other than a Terminus version line (for example an
# empty file, which bash would happily "execute" with exit status 0).
_terminus_version() {
  local out
  out=$(terminus --version 2>/dev/null) || return 1
  [[ "$out" == Terminus* ]] || return 1
  printf '%s\n' "$out"
}

mod::terminus() {
  begin_section "Terminus Installation"

  local url="https://github.com/pantheon-systems/terminus/releases/latest/download/terminus.phar"
  local target="/usr/local/bin/terminus"
  local tmp check

  if _terminus_version >/dev/null; then
    log_skip "Terminus"; end_section "Terminus Installation"; return 0
  fi

  if cmd_exists terminus; then
    log_warning "Existing $(command -v terminus) is broken or empty, reinstalling"
  fi

  tmp=$(mktemp) || die "Could not create a temporary file for Terminus"

  log "Downloading Terminus..."
  if ! curl -fsSL -o "$tmp" "$url"; then
    rm -f "$tmp"
    die "Failed to download Terminus from $url"
  fi

  # The download must be a runnable PHP phar, not an error page or empty body.
  check=$(php "$tmp" --version 2>&1) || check=""
  if [[ "$check" != Terminus* ]]; then
    rm -f "$tmp"
    log_error "php could not run the Terminus phar: ${check%%$'\n'*}"
    die "Downloaded Terminus file is not a working phar (are the PHP extensions installed?)"
  fi

  log "Installing Terminus to $target..."
  if ! sudo install -m 0755 "$tmp" "$target"; then
    rm -f "$tmp"
    die "Failed to install Terminus to $target"
  fi
  rm -f "$tmp"

  if ! _terminus_version >/dev/null; then
    die "Terminus was installed to $target but 'terminus --version' does not work"
  fi

  log "Installing Terminus build tools plugin..."
  if ! terminus self:plugin:install terminus-build-tools-plugin; then
    log_warning "Terminus build tools plugin could not be installed; continuing without it"
  fi

  log_success "Terminus installed"
  end_section "Terminus Installation"
}
