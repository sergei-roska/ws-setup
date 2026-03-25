#!/usr/bin/env bash
# Module: antigravity — Antigravity Auto-Updater.

mod::antigravity() {
  begin_section "Antigravity Installation"

  if cmd_exists antigravity; then
    log_skip "Antigravity"
    end_section "Antigravity Installation"
    return 0
  fi

  log "Setting up Antigravity repository..."

  # Create keyrings directory if it doesn't exist
  sudo mkdir -p /etc/apt/keyrings

  # Download and dearmor the GPG key
  curl -fsSL https://us-central1-apt.pkg.dev/doc/repo-signing-key.gpg | \
    sudo gpg --dearmor --yes -o /etc/apt/keyrings/antigravity-repo-key.gpg

  # Add the repository to sources.list.d
  echo "deb [signed-by=/etc/apt/keyrings/antigravity-repo-key.gpg] https://us-central1-apt.pkg.dev/projects/antigravity-auto-updater-dev/ antigravity-debian main" | \
    sudo tee /etc/apt/sources.list.d/antigravity.list > /dev/null

  log "Updating package lists and installing antigravity..."
  sudo apt-get update -y
  sudo apt-get install -y antigravity

  log_success "Antigravity installed"
  end_section "Antigravity Installation"
}
