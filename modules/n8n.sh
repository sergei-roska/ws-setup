#!/usr/bin/env bash
# Module: n8n — Dockerized n8n with persistent data and host file access.

mod::n8n() {
  begin_section "n8n Installation"

  source "$WS_ROOT/config/n8n.conf"

  require_cmd docker

  mkdir -p "$N8N_DATA_DIR" "$N8N_FILES_DIR"

  if sudo docker ps -a --format '{{.Names}}' | grep -Fxq "$N8N_CONTAINER_NAME"; then
    log "n8n container already exists"

    if ! sudo docker ps --format '{{.Names}}' | grep -Fxq "$N8N_CONTAINER_NAME"; then
      log "Starting existing n8n container..."
      sudo docker start "$N8N_CONTAINER_NAME" >/dev/null
    fi

    log_success "n8n is available at http://localhost:$N8N_PORT"
    end_section "n8n Installation"
    return 0
  fi

  log "Pulling n8n image..."
  sudo docker pull "$N8N_IMAGE"

  log "Creating n8n container with automatic restart on boot..."
  sudo docker run -d \
    --name "$N8N_CONTAINER_NAME" \
    --restart unless-stopped \
    -p "${N8N_PORT}:5678" \
    -v "${N8N_DATA_DIR}:/home/node/.n8n" \
    -v "${N8N_FILES_DIR}:/files" \
    "$N8N_IMAGE" >/dev/null

  log "Host directory ${N8N_FILES_DIR} is mounted inside n8n as /files"
  log_success "n8n installed and configured at http://localhost:$N8N_PORT"
  end_section "n8n Installation"
}
