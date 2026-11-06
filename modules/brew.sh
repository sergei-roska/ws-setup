#!/usr/bin/env bash
# Module: brew — Homebrew for Linux.
#
# The shell module owns the ~/.bashrc entry for Homebrew; this module only puts
# brew on PATH for the current run.

mod::brew() {
  begin_section "Homebrew Installation"

  local brew_bin="/home/linuxbrew/.linuxbrew/bin/brew"

  # PATH normally comes from ~/.bashrc, which a fresh install.sh run does not
  # have yet; look at the known install location too.
  if ! cmd_exists brew && [[ -x "$brew_bin" ]]; then
    eval "$("$brew_bin" shellenv)"
  fi

  if cmd_exists brew; then
    log_skip "Homebrew"; end_section "Homebrew Installation"; return 0
  fi

  log "Running Homebrew installer..."
  # The installer waits for RETURN unless NONINTERACTIVE is set; keep that
  # prompt in interactive mode only.
  if [[ "${NON_INTERACTIVE:-false}" == "true" ]]; then
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  else
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  fi

  [[ -x "$brew_bin" ]] || die "Homebrew installer finished but $brew_bin is missing"
  eval "$("$brew_bin" shellenv)"

  log_success "Homebrew installed"
  end_section "Homebrew Installation"
}
