#!/usr/bin/env bash
# Backup and rollback helpers.
# Sourced by install.sh; do not execute directly.

BACKUP_DIR="${BACKUP_DIR:-$HOME/.config-backup-$(date +%Y%m%d_%H%M%S)}"

backup_file() {
  local file="$1"
  if [[ -f "$file" ]]; then
    mkdir -p "$BACKUP_DIR"
    cp "$file" "$BACKUP_DIR/$(basename "$file")"
    log "Backed up $file to $BACKUP_DIR"
  fi
}

rollback() {
  log "Attempting to rollback changes..."
  if [[ -d "$BACKUP_DIR" ]]; then
    for backup in "$BACKUP_DIR"/*; do
      if [[ -f "$backup" ]]; then
        local original
        original="$HOME/.$(basename "$backup")"
        if cp "$backup" "$original"; then
          log "Restored $original"
        else
          log_error "Failed to restore $original"
        fi
      fi
    done
  else
    log "No backup directory found, nothing to rollback"
  fi
}
