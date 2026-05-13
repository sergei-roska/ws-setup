#!/usr/bin/env bash
# Logging library — all output and log-file management.
# Sourced by install.sh; do not execute directly.

# Logging configuration with timestamped filenames.
LOG_DIR="${WS_LOG_DIR:-/tmp/workspace-scripts}"
[[ -d "$LOG_DIR" ]] || mkdir -p "$LOG_DIR"
LOG_FILE="${LOG_FILE:-$LOG_DIR/ws-setup-$(date +%Y%m%d_%H%M%S).log}"

# --- Core helpers -----------------------------------------------------------

log() {
  printf '%s - %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$1" | tee -a "$LOG_FILE"
}

log_error() {
  printf '%s - ERROR: %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$1" | tee -a "$LOG_FILE" >&2
}

log_success() {
  printf '%s - SUCCESS: %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$1" | tee -a "$LOG_FILE"
}

log_warning() {
  printf '%s - WARNING: %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$1" | tee -a "$LOG_FILE"
}

log_skip() {
  log "$1 already installed, skipping"
}

# --- Sections ----------------------------------------------------------------

begin_section() {
  log ""
  log "=== BEGIN: $1 ==="
}

end_section() {
  log "=== END: $1 ==="
  log ""
}

# --- Fatal -------------------------------------------------------------------

die() {
  local message="$1"
  local exit_code="${2:-1}"
  log_error "$message"
  log_error "Script terminated. Check log file: $LOG_FILE"
  exit "$exit_code"
}
