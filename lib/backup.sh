#!/usr/bin/env bash
# Backup and rollback helpers.
# Sourced by install.sh; do not execute directly.

BACKUP_DIR="${BACKUP_DIR:-$HOME/.config-backup-$(date +%Y%m%d_%H%M%S)}"

# Backups mirror the file's path relative to $HOME, e.g. $HOME/.ssh/config is
# stored as $BACKUP_DIR/.ssh/config, so rollback can restore it in place.
backup_file() {
  local file="$1" rel dest
  if [[ -f "$file" ]]; then
    rel="${file#"$HOME"/}"
    if [[ "$rel" == "$file" ]]; then
      log_warning "Not backing up $file: it is outside \$HOME"
      return 0
    fi
    dest="$BACKUP_DIR/$rel"
    mkdir -p "$(dirname "$dest")"
    cp -p "$file" "$dest"
    log "Backed up $file to $dest"
  fi
  return 0
}

rollback() {
  local backup rel original
  log "Attempting to rollback changes..."
  if [[ -d "$BACKUP_DIR" ]]; then
    while IFS= read -r -d '' backup; do
      rel="${backup#"$BACKUP_DIR"/}"
      original="$HOME/$rel"
      if cp -p "$backup" "$original"; then
        log "Restored $original"
      else
        log_error "Failed to restore $original"
      fi
    done < <(find "$BACKUP_DIR" -type f -print0)
  else
    log "No backup directory found, nothing to rollback"
  fi
  return 0
}
