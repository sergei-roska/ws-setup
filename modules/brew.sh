#!/usr/bin/env bash
# Module: brew — Homebrew for Linux.

mod::brew() {
  begin_section "Homebrew Installation"

  if cmd_exists brew; then
    log_skip "Homebrew"; end_section "Homebrew Installation"; return 0
  fi

  log "Running Homebrew installer..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

  if ! grep -q "/home/linuxbrew/.linuxbrew/bin/brew" "$HOME/.bashrc"; then
    # shellcheck disable=SC2016
    echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >> "$HOME/.bashrc"
  fi

  eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"

  log_success "Homebrew installed"
  end_section "Homebrew Installation"
}
