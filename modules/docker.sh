#!/usr/bin/env bash
# Module: docker — Docker CE installation.

mod::docker() {
  begin_section "Docker Installation"

  if cmd_exists docker; then
    log_skip "Docker"; end_section "Docker Installation"; return 0
  fi

  # GPG key.
  log "Adding Docker GPG key..."
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
    | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

  # Repository.
  log "Adding Docker repository..."
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
    | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null

  sudo apt-get update -y
  sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

  sudo usermod -aG docker "$USER"

  log_success "Docker installed (restart session for group membership)"
  end_section "Docker Installation"
}
