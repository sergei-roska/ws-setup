#!/usr/bin/env bash
#
# Web Development Environment Setup — Single Entry Point
# Version: 3.0
#
# Usage: ./install.sh [OPTIONS]
# Run ./install.sh --help for full usage information.

set -euo pipefail

# === Resolve project root ====================================================

WS_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export WS_ROOT

# === Load libraries (order matters: log first, then everything else) ==========

source "$WS_ROOT/lib/log.sh"
source "$WS_ROOT/lib/os.sh"
source "$WS_ROOT/lib/backup.sh"
source "$WS_ROOT/lib/sudo.sh"
source "$WS_ROOT/lib/prompt.sh"
source "$WS_ROOT/lib/flatpak.sh"

# === CLI flags (defaults) =====================================================

NON_INTERACTIVE=${NON_INTERACTIVE:-false}
SKIP_MODULES=${SKIP_MODULES:-}
ONLY_MODULES=${ONLY_MODULES:-}
LIST_ONLY=${LIST_ONLY:-false}
VERBOSE=${VERBOSE:-false}
RESET_CONFIG=${RESET_CONFIG:-false}
CUSTOM_LOG_FILE=${CUSTOM_LOG_FILE:-}
export NON_INTERACTIVE

# === Module registry ==========================================================
#
# Ordered list of module names.  Dependencies are stored in a parallel
# associative array keyed by module name.

declare -a MODULE_ORDER=()
declare -A MODULE_DEPS=()

register_module() {
  local name="$1" deps="${2:-}"
  MODULE_ORDER+=("$name")
  MODULE_DEPS["$name"]="$deps"
}

# Registration — order here IS execution order.
register_module  prereqs      ""
register_module  drivers      "prereqs"
register_module  snap         "prereqs"
register_module  flatpak      "prereqs"
register_module  flatpak-apps "flatpak"
register_module  git-ssh      "prereqs"
register_module  docker       "prereqs"
register_module  lando        "docker"
register_module  ddev         "docker"
register_module  php          "prereqs"
register_module  composer     "php"
register_module  phpcs        "composer"
register_module  node         "prereqs"
register_module  claude       "prereqs"
register_module  antigravity  "prereqs"
register_module  brew         "prereqs"
register_module  terminus     "php composer"
register_module  shell        ""
register_module  apps-deb     "prereqs"
register_module  apps-apt     "prereqs"
register_module  summary      ""

# === Load all module files (defines mod::* functions) =========================

for _mod in "${MODULE_ORDER[@]}"; do
  _file="$WS_ROOT/modules/${_mod}.sh"
  if [[ -f "$_file" ]]; then
    source "$_file"
  else
    die "Module file not found: $_file"
  fi
done
unset _mod _file

# === Help =====================================================================

show_help() {
  cat <<'EOF'
Web Development Environment Setup — v3.0

USAGE:
  ./install.sh [OPTIONS]

OPTIONS:
  --yes                    Non-interactive mode (skip all prompts)
  --only MOD1,MOD2         Execute only specified modules
  --skip MOD1,MOD2         Skip specified modules
  --list                   List available modules and exit
  --log-file PATH          Override default log file path
  --verbose                Enable verbose output
  --reset-config           Reset saved user configuration
  --help                   Show this help message

ENVIRONMENT VARIABLES:
  GIT_NAME                 Git user name
  GIT_EMAIL                Git user email
  SSH_PASSPHRASE           SSH key passphrase (empty = no passphrase)
  PANTHEON_ENV_ID          Pantheon environment ID
  APP_GROUPS               Comma-separated: essential,dev,optional  (default: essential)
  SNAP_APPS                essential | all | none | app1,app2       (default: essential)
  APT_PPA_PACKAGES         essential | all | none | pkg1,pkg2       (default: essential)

EXAMPLES:
  ./install.sh                                  # Interactive
  ./install.sh --yes                            # Non-interactive
  ./install.sh --only prereqs,docker,lando      # Selected modules
  ./install.sh --skip drivers,brew              # Skip modules
  GIT_NAME="John" GIT_EMAIL="j@x.com" ./install.sh --yes
EOF
}

# === Argument parsing =========================================================

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --yes)           NON_INTERACTIVE=true; export DEBIAN_FRONTEND=noninteractive; shift ;;
      --only)          ONLY_MODULES="$2"; shift 2 ;;
      --skip)          SKIP_MODULES="$2"; shift 2 ;;
      --list)          LIST_ONLY=true; shift ;;
      --log-file)      CUSTOM_LOG_FILE="$2"; shift 2 ;;
      --verbose)       VERBOSE=true; shift ;;
      --reset-config)  RESET_CONFIG=true; shift ;;
      --help|-h)       show_help; exit 0 ;;
      *)               echo "Error: Unknown option $1" >&2; echo "Use --help for usage." >&2; exit 1 ;;
    esac
  done
}

# === Module filtering =========================================================

# Returns the filtered list of module names (one per line).
filtered_modules() {
  local -a result=()

  if [[ -n "$ONLY_MODULES" ]]; then
    IFS=',' read -ra only_list <<< "$ONLY_MODULES"
    for name in "${only_list[@]}"; do
      name="${name// /}"
      # Validate it exists in registry.
      local found=false
      for reg in "${MODULE_ORDER[@]}"; do
        [[ "$reg" == "$name" ]] && { found=true; break; }
      done
      $found || die "Unknown module in --only: $name"
      result+=("$name")
    done
  else
    result=("${MODULE_ORDER[@]}")
  fi

  if [[ -n "$SKIP_MODULES" ]]; then
    IFS=',' read -ra skip_list <<< "$SKIP_MODULES"
    local -a tmp=()
    for name in "${result[@]}"; do
      local skip=false
      for s in "${skip_list[@]}"; do
        [[ "$name" == "${s// /}" ]] && { skip=true; break; }
      done
      $skip || tmp+=("$name")
    done
    result=("${tmp[@]}")
  fi

  printf '%s\n' "${result[@]}"
}

# === Dependency validation ====================================================

validate_deps() {
  local -a modules=()
  while IFS= read -r m; do [[ -n "$m" ]] && modules+=("$m"); done < <(filtered_modules)

  # Build a set of scheduled modules for O(1) lookup.
  local -A scheduled=()
  for m in "${modules[@]}"; do scheduled["$m"]=1; done

  for m in "${modules[@]}"; do
    local deps="${MODULE_DEPS[$m]:-}"
    [[ -z "$deps" ]] && continue
    read -ra dep_list <<< "$deps"
    for d in "${dep_list[@]}"; do
      if [[ -z "${scheduled[$d]:-}" ]]; then
        die "Module '$m' depends on '$d', but '$d' is not scheduled (skipped or not in --only)."
      fi
    done
  done
}

# === List modules =============================================================

list_modules() {
  echo "Available modules:"
  echo ""
  local i=1
  for name in "${MODULE_ORDER[@]}"; do
    local deps="${MODULE_DEPS[$name]:-}"
    if [[ -n "$deps" ]]; then
      printf "  %2d. %-16s  (depends: %s)\n" "$i" "$name" "$deps"
    else
      printf "  %2d. %-16s\n" "$i" "$name"
    fi
    ((i++))
  done
  echo ""
  echo "Usage examples:"
  echo "  ./install.sh --only prereqs,docker,lando"
  echo "  ./install.sh --skip drivers,brew"
  echo "  ./install.sh --yes"
}

# === Confirm execution ========================================================

confirm_execution() {
  [[ "$NON_INTERACTIVE" == "true" ]] && return 0

  local -a modules=()
  while IFS= read -r m; do [[ -n "$m" ]] && modules+=("$m"); done < <(filtered_modules)

  [[ ${#modules[@]} -eq 0 ]] && die "No modules selected. Use --list to see available modules."

  echo "The following modules will be executed:"
  local i=1
  for m in "${modules[@]}"; do
    printf "  %2d. %s\n" "$i" "$m"
    ((i++))
  done
  echo ""
  confirm_yes "Proceed with installation?" || { log "Installation cancelled by user"; exit 0; }
}

# === Execute modules ==========================================================

execute_modules() {
  local -a modules=()
  while IFS= read -r m; do [[ -n "$m" ]] && modules+=("$m"); done < <(filtered_modules)

  local total=${#modules[@]} current=1

  for name in "${modules[@]}"; do
    log "[$current/$total] Executing module: $name"

    # Resolve function name: mod::name  (hyphens kept as-is; bash allows them in function names).
    local fn="mod::${name}"
    if ! declare -f "$fn" &>/dev/null; then
      die "Module function $fn not defined"
    fi

    if "$fn"; then
      log_success "[$current/$total] Module $name completed"
    else
      local rc=$?
      log_error "[$current/$total] Module $name failed (exit code $rc)"
      log_error "Check the log file: $LOG_FILE"
      [[ -d "$BACKUP_DIR" ]] && log_error "Backup directory: $BACKUP_DIR"
      exit "$rc"
    fi

    ((current++))
  done
}

# === Error / interrupt traps ==================================================

_on_error() {
  local rc=$?
  echo
  log_error "==========================================="
  log_error "Script failed with exit code: $rc"
  log_error "Log file: $LOG_FILE"
  [[ -d "$BACKUP_DIR" ]] && log_error "Backup dir: $BACKUP_DIR"
  log_error "==========================================="
  exit "$rc"
}

_on_interrupt() {
  echo
  log "Interrupted by user (Ctrl+C)"
  rollback
  log "Terminated. Log: $LOG_FILE"
  exit 130
}

# === Main =====================================================================

main() {
  parse_args "$@"

  # Custom log file.
  if [[ -n "$CUSTOM_LOG_FILE" ]]; then
    LOG_FILE="$CUSTOM_LOG_FILE"
    mkdir -p "$(dirname "$LOG_FILE")"
  fi

  # Early actions.
  if [[ "$LIST_ONLY" == "true" ]]; then list_modules; exit 0; fi

  if [[ "$RESET_CONFIG" == "true" ]]; then
    reset_user_config
    echo "User configuration reset. Run the script again."
    exit 0
  fi

  # User config.
  load_user_config

  # Traps.
  trap _on_error ERR
  trap _on_interrupt INT TERM
  trap stop_sudo_keepalive EXIT

  # Setup environment.
  export APP_GROUPS=${APP_GROUPS:-"essential"}

  if [[ "$VERBOSE" == "true" ]]; then
    echo "Configuration:"
    echo "  NON_INTERACTIVE : $NON_INTERACTIVE"
    echo "  APP_GROUPS      : $APP_GROUPS"
    echo "  LOG_FILE        : $LOG_FILE"
    echo ""
  fi

  # Pre-flight.
  log "Starting web development environment setup (v3.0)"
  log "Log file: $LOG_FILE"
  check_os
  is_root && die "Do not run as root"
  require_sudo
  start_sudo_keepalive
  check_internet || die "No internet connection"

  # Validate and confirm.
  validate_deps
  confirm_execution

  # Execute.
  execute_modules

  # Post-install.
  record_tool_versions

  log "Installation completed successfully!"
  log "Log file: $LOG_FILE"
  [[ -d "$BACKUP_DIR" ]] && log "Backup dir: $BACKUP_DIR"
}

main "$@"
