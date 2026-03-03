#!/usr/bin/env bash

# Web Development Environment Setup - Main Orchestrator
# Coordinates all setup modules in a logical order with advanced options
# Version: 2.0

# === CLI Flags and Variables ===
NON_INTERACTIVE=${NON_INTERACTIVE:-false}
SKIP_MODULES=${SKIP_MODULES:-}
ONLY_MODULES=${ONLY_MODULES:-}
LIST_ONLY=${LIST_ONLY:-false}
CUSTOM_LOG_FILE=${CUSTOM_LOG_FILE:-}
VERBOSE=${VERBOSE:-false}
RESET_CONFIG=${RESET_CONFIG:-false}

# === Load Common Library ===
INSTALL_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "$INSTALL_SCRIPT_DIR/.." && pwd)"

# Source the common library first - this sets strict mode and IFS
source "$WORKSPACE_ROOT/lib/common.sh"
MODULES_DIR="$INSTALL_SCRIPT_DIR/modules"

# === Help Function ===
show_help() {
  cat << 'EOF'
Web Development Environment Setup - Main Orchestrator

USAGE:
  install.sh [OPTIONS]

OPTIONS:
  --yes                    Non-interactive mode (skip all prompts)
  --only MODULE1,MODULE2   Execute only specified modules
  --skip MODULE1,MODULE2   Skip specified modules
  --list                   List available modules and exit
  --log-file PATH          Override default log file path
  --verbose                Enable verbose output
  --reset-config           Reset saved user configuration
  --help                   Show this help message

ENVIRONMENT VARIABLES:
  For non-interactive Git and SSH setup:
    GIT_NAME                Git user name
    GIT_EMAIL               Git user email
    SSH_PASSPHRASE          SSH key passphrase (leave empty for no passphrase)
    PANTHEON_ENV_ID         Pantheon environment ID
  
  For Flatpak app groups:
    APP_GROUPS              Comma-separated list: essential,dev,optional
                           Defaults to "essential" only

EXAMPLES:
  # Interactive mode (default)
  ./install.sh
  
  # Non-interactive mode
  ./install.sh --yes
  
  # Install only specific modules
  ./install.sh --only 00-prereqs,03-flatpak,05-git-ssh
  
  # Skip certain modules
  ./install.sh --skip 02-snap-remove,13-brew
  
  # Custom log file
  ./install.sh --log-file /tmp/my-setup.log
  
  # Non-interactive with environment variables
  GIT_NAME="John Doe" GIT_EMAIL="john@example.com" ./install.sh --yes
  
  # Non-interactive with SSH passphrase
  SSH_PASSPHRASE="mySecretPassword" ./install.sh --yes
  
  # Complete non-interactive setup
  GIT_NAME="John Doe" GIT_EMAIL="john@example.com" SSH_PASSPHRASE="" ./install.sh --yes

EOF
}

# === Parse Command Line Arguments ===
parse_args() {
  while [[ $# -gt 0 ]]; do
    case $1 in
      --yes)
        NON_INTERACTIVE=true
        export DEBIAN_FRONTEND=noninteractive
        shift
        ;;
      --only)
        ONLY_MODULES="$2"
        shift 2
        ;;
      --skip)
        SKIP_MODULES="$2"
        shift 2
        ;;
      --list)
        LIST_ONLY=true
        shift
        ;;
      --log-file)
        CUSTOM_LOG_FILE="$2"
        shift 2
        ;;
      --verbose)
        VERBOSE=true
        shift
        ;;
      --reset-config)
        RESET_CONFIG=true
        shift
        ;;
      --help|-h)
        show_help
        exit 0
        ;;
      *)
        echo "Error: Unknown option $1" >&2
        echo "Use --help for usage information" >&2
        exit 1
        ;;
    esac
  done
}

# === Module Discovery ===
discover_modules() {
  local modules=()
  # Find all .sh files in modules directory and sort numerically
  while IFS= read -r -d '' module; do
    modules+=("$(basename "$module")")
  done < <(find "$MODULES_DIR" -name "*.sh" -type f -print0 | sort -z -V)
  printf '%s\n' "${modules[@]}"
}

# === Module Filtering ===
filter_modules() {
  local -a all_modules=()
  local -a filtered_modules=()
  
  # Read all modules into array
  while IFS= read -r module; do
    all_modules+=("$module")
  done < <(discover_modules)
  
  # Apply --only filter first
  if [[ -n "$ONLY_MODULES" ]]; then
    IFS=',' read -ra only_list <<< "$ONLY_MODULES"
    for module in "${all_modules[@]}"; do
      for only_item in "${only_list[@]}"; do
        # Support both with and without .sh extension
        if [[ "$module" == "$only_item" || "$module" == "${only_item}.sh" ]]; then
          filtered_modules+=("$module")
          break
        fi
      done
    done
  else
    filtered_modules=("${all_modules[@]}")
  fi
  
  # Apply --skip filter
  if [[ -n "$SKIP_MODULES" ]]; then
    IFS=',' read -ra skip_list <<< "$SKIP_MODULES"
    local -a final_modules=()
    for module in "${filtered_modules[@]}"; do
      local skip_module=false
      for skip_item in "${skip_list[@]}"; do
        # Support both with and without .sh extension
        if [[ "$module" == "$skip_item" || "$module" == "${skip_item}.sh" ]]; then
          skip_module=true
          break
        fi
      done
      if [[ "$skip_module" == "false" ]]; then
        final_modules+=("$module")
      fi
    done
    filtered_modules=("${final_modules[@]}")
  fi
  
  printf '%s\n' "${filtered_modules[@]}"
}

# === List Modules Function ===
list_modules() {
  echo "📋 Available setup modules:"
  echo ""
  
  local modules
  modules=()
  while IFS= read -r module; do
    modules+=("$module")
  done < <(discover_modules)
  
  if [[ ${#modules[@]} -eq 0 ]]; then
    echo "❌ No modules found in $MODULES_DIR"
    return 1
  fi
  
  local i=1
  for module in "${modules[@]}"; do
    local module_path="$MODULES_DIR/$module"
    local description=""
    
    # Try to extract description from module file
    if [[ -f "$module_path" ]]; then
      description=$(grep -m1 "^# Description:" "$module_path" 2>/dev/null | sed 's/^# Description: *//' || echo "No description available")
    fi
    
    printf "%2d. %-20s - %s\n" "$i" "$module" "$description"
    ((i++))
  done
  
  echo ""
  echo "💡 Usage examples:"
  echo "  ./install.sh --only 00-prereqs,03-flatpak"
  echo "  ./install.sh --skip 02-snap-remove,13-brew"
  echo "  ./install.sh --yes  # Non-interactive mode"
}

# === Confirmation Function ===
confirm_execution() {
  if [[ "$NON_INTERACTIVE" == "true" ]]; then
    return 0
  fi
  
  local modules
  modules=()
  while IFS= read -r module; do
    if [[ -n "$module" ]]; then  # Only add non-empty modules
      modules+=("$module")
    fi
  done < <(filter_modules)
  
  if [[ ${#modules[@]} -eq 0 ]]; then
    echo "❌ No valid modules found matching your criteria."
    echo "Use --list to see available modules."
    exit 1
  fi
  
  echo "📋 The following modules will be executed:"
  local i=1
  for module in "${modules[@]}"; do
    printf "%2d. %s\n" "$i" "$module"
    ((i++))
  done
  echo ""
  
  if ! confirm_yes "Do you want to proceed with the installation?"; then
    log "Installation cancelled by user"
    exit 0
  fi
}

# === Environment Variables Setup ===
setup_environment() {
  # Set default APP_GROUPS if not specified
  export APP_GROUPS=${APP_GROUPS:-"essential"}
  
  if [[ "$VERBOSE" == "true" ]]; then
    echo "🔧 Environment configuration:"
    echo "  NON_INTERACTIVE: $NON_INTERACTIVE"
    echo "  APP_GROUPS: $APP_GROUPS"
    [[ -n "${GIT_NAME:-}" ]] && echo "  GIT_NAME: $GIT_NAME" || echo "  GIT_NAME: (not set)"
    [[ -n "${GIT_EMAIL:-}" ]] && echo "  GIT_EMAIL: $GIT_EMAIL" || echo "  GIT_EMAIL: (not set)"
    [[ -n "${SSH_PASSPHRASE:-}" ]] && echo "  SSH_PASSPHRASE: [REDACTED]" || echo "  SSH_PASSPHRASE: (not set)"
    [[ -n "${PANTHEON_ENV_ID:-}" ]] && echo "  PANTHEON_ENV_ID: $PANTHEON_ENV_ID" || echo "  PANTHEON_ENV_ID: (not set)"
    echo "  LOG_FILE: $LOG_FILE"
    echo ""
  fi
}

# === Module Execution ===
execute_modules() {
  local modules
  modules=()
  while IFS= read -r module; do
    if [[ -n "$module" ]]; then  # Only add non-empty modules
      modules+=("$module")
    fi
  done < <(filter_modules)
  
  if [[ ${#modules[@]} -eq 0 ]]; then
    log_error "No modules to execute after filtering"
    exit 1
  fi
  
  local total=${#modules[@]}
  local current=1
  
  for module in "${modules[@]}"; do
    local module_path="$MODULES_DIR/$module"
    
    log "🔧 [$current/$total] Executing module: $module"
    
    if [[ ! -f "$module_path" ]]; then
      log_error "Module file not found: $module_path"
      exit 1
    fi
    
    if [[ ! -x "$module_path" ]]; then
      log_warning "Module $module is not executable, making it executable..."
      chmod +x "$module_path" || {
        log_error "Failed to make $module executable"
        exit 1
      }
    fi
    
    # Source the module instead of executing it as subprocess
    # This allows modules to share environment variables and functions
    if source "$module_path"; then
      log_success "[$current/$total] Module $module completed successfully"
    else
      local exit_code=$?
      log_error "[$current/$total] Module $module failed with exit code $exit_code"
      log_error "Check the log file for details: $LOG_FILE"
      if [[ -d "$BACKUP_DIR" ]]; then
        log_error "Backup directory available for rollback: $BACKUP_DIR"
      fi
      exit $exit_code
    fi
    
    ((current++))
  done
}

# === Main Function ===
main() {
  # Parse command line arguments
  parse_args "$@"
  
  # Override LOG_FILE if custom path provided (must be done after parsing args but before error handling)
  if [[ -n "$CUSTOM_LOG_FILE" ]]; then
    LOG_FILE="$CUSTOM_LOG_FILE"
    # Ensure log directory exists
    mkdir -p "$(dirname "$LOG_FILE")"
  fi
  
  # Handle --list option early
  if [[ "$LIST_ONLY" == "true" ]]; then
    list_modules
    exit 0
  fi
  
  # Handle --reset-config option early
  if [[ "$RESET_CONFIG" == "true" ]]; then
    echo "🔄 Resetting user configuration..."
    reset_user_config
    echo "✅ User configuration reset. Run the script again to set new values."
    exit 0
  fi
  
  # Load saved user configuration
  load_user_config
  
  # Setup error handling after parsing args and setting log file
  setup_error_handling
  
  # Setup environment variables
  setup_environment
  
  # === Welcome Message ===
  log "🚀 Starting web development environment setup..."
  log "Version: 2.0 - Enhanced Orchestrator"
  log "Log file: $LOG_FILE"
  log "Modules directory: $MODULES_DIR"
  log "Non-interactive mode: $NON_INTERACTIVE"
  
  # === Pre-flight Checks ===
  log "🔍 Performing pre-flight checks..."
  check_os
  
  if is_root; then
    log_error "This script should not be run as root"
    exit 1
  fi
  
  # Ensure sudo access is available
  require_sudo
  
  # Start sudo keepalive to prevent repeated password prompts
  start_sudo_keepalive
  
  # Add cleanup for sudo keepalive process
  trap 'stop_sudo_keepalive' EXIT
  
  if ! check_internet; then
    log_error "No internet connection detected"
    exit 1
  fi
  
  # Check if modules directory exists
  if [[ ! -d "$MODULES_DIR" ]]; then
    log_error "Modules directory not found: $MODULES_DIR"
    exit 1
  fi
  
  # Confirm execution plan
  confirm_execution
  
  # === Backup Configuration Files ===
  log "📋 Backing up existing configuration files..."
  backup_file "$HOME/.bashrc"
  backup_file "$HOME/.ssh/config" 
  backup_file "$HOME/.gitconfig"
  backup_file "$HOME/.profile"
  
  # === Execute Modules ===
  log "🚀 Beginning module execution..."
  execute_modules
  
  # === Record Tool Versions ===
  record_tool_versions
  
  # === Final Summary ===
  log "✅ Installation completed successfully!"
  log "📋 Summary:"
  log "  - Log file: $LOG_FILE"
  log "  - Backup directory: $BACKUP_DIR"
  log "  - Modules executed: $(filter_modules | wc -l)"
  log ""
  log "🔄 Next steps:"
  log "  1. Reload your shell: source ~/.bashrc"
  log "  2. Add SSH keys to your Git providers (keys displayed during setup)"
  log "  3. Restart your session for Docker group membership"
  log "  4. Test your setup with: docker --version && git --version"
  if [[ -f "$WORKSPACE_ROOT/tools/flatpak/set-defaults.sh" ]]; then
    log "  5. Run the Flatpak defaults script: $WORKSPACE_ROOT/tools/flatpak/set-defaults.sh"
  fi
  
  # Cleanup trap
  trap - ERR INT
  
  echo ""
  echo "🎉 Environment setup complete! Check the log for details: $LOG_FILE"
}

# === Execute Main Function ===
main "$@"
