#!/usr/bin/env bash
#
# Web Development Environment Setup — Single Entry Point
# Version: 3.0
#
# Usage: ./install.sh [OPTIONS]
# Run ./install.sh --help for full usage information.

# errtrace (-E) makes the ERR trap fire for failures inside functions too.
set -Eeuo pipefail

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
register_module  brew         "prereqs"
register_module  terminus     "php composer"
register_module  shell        ""
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

arg_error() {
  echo "Error: $1" >&2
  echo "Use --help for usage." >&2
  exit 1
}

# Require a non-empty value after an option that takes one.
# Usage: need_value OPTION "$#" "${2:-}"
need_value() {
  local opt="$1" argc="$2" value="${3:-}"
  [[ "$argc" -ge 2 && -n "$value" && "$value" != --* ]] \
    || arg_error "Option $opt requires an argument"
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --yes)           NON_INTERACTIVE=true; export DEBIAN_FRONTEND=noninteractive; shift ;;
      --only)          need_value "$1" "$#" "${2:-}"; ONLY_MODULES="$2"; shift 2 ;;
      --skip)          need_value "$1" "$#" "${2:-}"; SKIP_MODULES="$2"; shift 2 ;;
      --list)          LIST_ONLY=true; shift ;;
      --log-file)      need_value "$1" "$#" "${2:-}"; CUSTOM_LOG_FILE="$2"; shift 2 ;;
      --verbose)       VERBOSE=true; shift ;;
      --reset-config)  RESET_CONFIG=true; shift ;;
      --help|-h)       show_help; exit 0 ;;
      *)               arg_error "Unknown option $1" ;;
    esac
  done
}

# === Module selection ========================================================

# Modules to run, in registry order.  Filled by resolve_modules (main shell,
# so that die on an unknown name really stops the run).
declare -a SELECTED_MODULES=()

resolve_modules() {
  local -A known=() wanted=() skipped=()
  local -a only_list=() skip_list=()
  local reg name

  for reg in "${MODULE_ORDER[@]}"; do known["$reg"]=1; done

  if [[ -n "$ONLY_MODULES" ]]; then
    IFS=',' read -ra only_list <<< "$ONLY_MODULES"
    for name in "${only_list[@]}"; do
      name="${name// /}"
      [[ -z "$name" ]] && continue
      [[ -n "${known[$name]:-}" ]] || die "Unknown module in --only: $name (see --list)"
      wanted["$name"]=1
    done
  fi

  if [[ -n "$SKIP_MODULES" ]]; then
    IFS=',' read -ra skip_list <<< "$SKIP_MODULES"
    for name in "${skip_list[@]}"; do
      name="${name// /}"
      [[ -z "$name" ]] && continue
      skipped["$name"]=1
    done
  fi

  # Walk the registry so execution always follows registry order.
  SELECTED_MODULES=()
  for reg in "${MODULE_ORDER[@]}"; do
    if [[ -n "$ONLY_MODULES" && -z "${wanted[$reg]:-}" ]]; then continue; fi
    if [[ -n "${skipped[$reg]:-}" ]]; then continue; fi
    SELECTED_MODULES+=("$reg")
  done

  [[ ${#SELECTED_MODULES[@]} -gt 0 ]] || die "No modules selected. Use --list to see available modules."
}

# === Dependency validation ====================================================

# A dependency that is not scheduled may already be satisfied on this machine
# (hard to detect), so only warn: the user chose the module set explicitly.
validate_deps() {
  local m d deps
  local -A scheduled=()
  for m in "${SELECTED_MODULES[@]}"; do scheduled["$m"]=1; done

  for m in "${SELECTED_MODULES[@]}"; do
    deps="${MODULE_DEPS[$m]:-}"
    [[ -z "$deps" ]] && continue
    local -a dep_list=()
    read -ra dep_list <<< "$deps"
    for d in "${dep_list[@]}"; do
      if [[ -z "${scheduled[$d]:-}" ]]; then
        log_warning "Module '$m' depends on '$d', which is not scheduled (skipped or not in --only); continuing"
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

  echo "The following modules will be executed:"
  local i=1 m
  for m in "${SELECTED_MODULES[@]}"; do
    printf "  %2d. %s\n" "$i" "$m"
    ((i++))
  done
  echo ""
  confirm_yes "Proceed with installation?" || { log "Installation cancelled by user"; exit 0; }
}

# === Execute modules ==========================================================

# Progress tracking for the ERR trap: which module is running right now.
CURRENT_MODULE=""
CURRENT_MODULE_POS=""

execute_modules() {
  local total=${#SELECTED_MODULES[@]} current=1 name fn

  for name in "${SELECTED_MODULES[@]}"; do
    CURRENT_MODULE="$name"
    CURRENT_MODULE_POS="$current/$total"
    log "[$CURRENT_MODULE_POS] Executing module: $name"

    # Resolve function name: mod::name  (hyphens kept as-is; bash allows them in function names).
    fn="mod::${name}"
    if ! declare -f "$fn" &>/dev/null; then
      die "Module function $fn not defined"
    fi

    # Run as a plain command in the main shell (no subshell: modules export
    # PATH, NVM_DIR, ...) and never inside a condition (if/||/&&), which would
    # disable errexit for the whole module body.  A failing command inside the
    # module fires the ERR trap (_on_error), which reports and exits.
    "$fn"
    log_success "[$CURRENT_MODULE_POS] Module $name completed"

    current=$((current + 1))
  done

  CURRENT_MODULE=""
  CURRENT_MODULE_POS=""
}

# === Error / interrupt traps ==================================================

# Called from the ERR trap with: exit status, failed command, file:line.
_on_error() {
  local rc="$1" cmd="${2:-?}" where="${3:-?}"
  trap - ERR
  # Subshells ($(...), pipelines) inherit the trap via -E: leave quietly and
  # let the parent shell report the failure.
  [[ "${BASHPID:-$$}" == "$$" ]] || exit "$rc"

  echo
  log_error "==========================================="
  if [[ -n "$CURRENT_MODULE" ]]; then
    log_error "[$CURRENT_MODULE_POS] Module $CURRENT_MODULE failed (exit code $rc)"
  else
    log_error "Script failed with exit code: $rc"
  fi
  log_error "Failed command: $cmd ($where)"
  log_error "Log file: $LOG_FILE"
  if [[ -d "$BACKUP_DIR" ]]; then log_error "Backup dir: $BACKUP_DIR"; fi
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

  # Resolve --only/--skip first so a typo stops the run before any work.
  resolve_modules

  # User config.
  load_user_config

  # Traps.
  # shellcheck disable=SC2016
  trap '_on_error "$?" "$BASH_COMMAND" "${BASH_SOURCE[0]}:${LINENO}"' ERR
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
  if [[ -d "$BACKUP_DIR" ]]; then log "Backup dir: $BACKUP_DIR"; fi
}

main "$@"
