#!/usr/bin/env bash
# Module: lando — Lando development environment.
#
# The shell module owns the ~/.bashrc PATH entry for Lando; this module only
# puts lando on PATH for the current run.

mod::lando() {
  begin_section "Lando Installation"

  local lando_dir="$HOME/.lando/bin"

  # PATH normally comes from ~/.bashrc, which a fresh install.sh run does not
  # have yet; look at the known install location too.
  if ! cmd_exists lando && [[ -x "$lando_dir/lando" ]]; then
    export PATH="$lando_dir:$PATH"
  fi

  if cmd_exists lando; then
    log_skip "Lando"; end_section "Lando Installation"; return 0
  fi

  log "Downloading Lando installer..."
  curl -fsSL https://get.lando.dev/setup-lando.sh -o /tmp/setup-lando.sh
  chmod +x /tmp/setup-lando.sh

  log "Running Lando installer..."
  bash /tmp/setup-lando.sh --yes
  rm -f /tmp/setup-lando.sh

  # The installer runs "lando shellenv --add", which appends its own PATH line
  # (tagged #landopath) to the shell rc files. Drop it: the shell module writes
  # the single, guarded PATH entry.
  local rc
  for rc in "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.profile" "$HOME/.bash_profile"; do
    if [[ -f "$rc" ]] && grep -q '#landopath' "$rc"; then
      sed -i '/#landopath/d' "$rc"
      log "Removed the Lando installer's PATH line from $rc"
    fi
  done

  [[ -x "$lando_dir/lando" ]] || die "Lando installer finished but $lando_dir/lando is missing"
  export PATH="$lando_dir:$PATH"

  log_success "Lando installed"
  end_section "Lando Installation"
}
