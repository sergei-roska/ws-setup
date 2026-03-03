#!/usr/bin/env bash

# Common library for workspace scripts
# Provides shared logging, error handling, and helper functions
# This library must be sourced first by all modules and scripts

# === Strict Error Handling ===
set -euo pipefail
IFS=$'\n\t'

# === Configuration ===
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Logging configuration with timestamped filenames
# Use WS_LOG_DIR environment variable or default to /tmp/workspace-scripts/
LOG_DIR="${WS_LOG_DIR:-/tmp/workspace-scripts}"
[[ ! -d "$LOG_DIR" ]] && mkdir -p "$LOG_DIR"
LOG_FILE="${LOG_FILE:-$LOG_DIR/workspace-script-$(date +%Y%m%d_%H%M%S).log}"
BACKUP_DIR="${BACKUP_DIR:-$HOME/.config-backup-$(date +%Y%m%d_%H%M%S)}"

# === Logging Functions ===
log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

log_error() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') - ERROR: $1" | tee -a "$LOG_FILE" >&2
}

log_success() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') - SUCCESS: $1" | tee -a "$LOG_FILE"
}

log_warning() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') - WARNING: $1" | tee -a "$LOG_FILE"
}

# Section logging functions
begin_section() {
  local section_name="$1"
  log "\n=== BEGIN: $section_name ==="
}

end_section() {
  local section_name="$1"
  log "=== END: $section_name ===\n"
}

# Fatal error function
die() {
  local message="$1"
  local exit_code="${2:-1}"
  log_error "$message"
  log_error "Script terminated. Check log file: $LOG_FILE"
  exit "$exit_code"
}

# === Utility Functions ===
check_command() {
  if ! command -v "$1" &> /dev/null; then
    log_error "Command $1 not found, please install it first."
    return 1
  fi
}

# Command requirement function (renamed from check_command for consistency)
require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" &> /dev/null; then
    die "Required command '$cmd' not found. Please install it first."
  fi
}

# OS compatibility check
check_os() {
  if [[ ! -f /etc/debian_version ]]; then
    die "This script is designed for Debian/Ubuntu systems only."
  fi
  log "Detected Debian/Ubuntu system"
}

# Root user checks
require_not_root() {
  if [[ $EUID -eq 0 ]]; then
    die "This script should not be run as root. Please run as a regular user."
  fi
}

require_sudo() {
  if ! sudo -n true 2>/dev/null; then
    log_error "This script requires sudo privileges"
    sudo -v || die "Failed to obtain sudo privileges"
  fi
}

# Keep sudo session alive during long-running operations
start_sudo_keepalive() {
  # Only start if not already running
  if [[ -z "${SUDO_KEEPALIVE_PID:-}" ]]; then
    log "Starting sudo keepalive background process..."
    
    # Background process to refresh sudo every 5 minutes
    (
      while true; do
        sleep 300  # 5 minutes
        if ! sudo -n true 2>/dev/null; then
          # If sudo fails, exit the background process
          exit 1
        fi
        sudo -v 2>/dev/null || exit 1
      done
    ) &
    
    export SUDO_KEEPALIVE_PID=$!
    log "Sudo keepalive started (PID: $SUDO_KEEPALIVE_PID)"
  fi
}

# Stop sudo keepalive process
stop_sudo_keepalive() {
  if [[ -n "${SUDO_KEEPALIVE_PID:-}" ]]; then
    log "Stopping sudo keepalive process..."
    kill "$SUDO_KEEPALIVE_PID" 2>/dev/null || true
    unset SUDO_KEEPALIVE_PID
  fi
}

backup_file() {
  local file="$1"
  if [[ -f "$file" ]]; then
    mkdir -p "$BACKUP_DIR"
    cp "$file" "$BACKUP_DIR/$(basename "$file")"
    log "Backed up $file to $BACKUP_DIR"
  fi
}

# === Interactive Functions ===
confirm_yes() {
  local prompt="${1:-Do you want to continue?}"
  local response
  
  while true; do
    read -p "$prompt [y/N]: " -r response
    case "$response" in
      [yY][eE][sS]|[yY])
        return 0
        ;;
      [nN][oO]|[nN]|"")
        return 1
        ;;
      *)
        echo "Please answer yes or no."
        ;;
    esac
  done
}

# Prompt for input with environment variable fallback
prompt_or_env() {
  local env_var="$1"
  local prompt="$2"
  local default_value="${3:-}"
  
  # Check if environment variable is set and non-empty
  if [[ -n "${!env_var:-}" ]]; then
    echo "${!env_var}"
    return 0
  fi
  
  # Interactive prompt
  local response
  if [[ -n "$default_value" ]]; then
    read -p "$prompt [$default_value]: " -r response
    echo "${response:-$default_value}"
  else
    read -p "$prompt: " -r response
    echo "$response"
  fi
}

# Debian package installation helper
deb_noninteractive() {
  export DEBIAN_FRONTEND=noninteractive
  log "Set DEBIAN_FRONTEND=noninteractive for automated installation"
}

# === Enhanced Error Handling with Helpful Messages ===
setup_error_handling() {
  # Enhanced cleanup function with helpful message
  cleanup() {
    local exit_code=$?
    echo
    log_error "==========================================="
    log_error "Script execution failed with exit code: $exit_code"
    log_error "==========================================="
    log_error "For debugging information, check the log file:"
    log_error "  Log file: $LOG_FILE"
    if [[ -d "$BACKUP_DIR" ]]; then
      log_error "  Backup directory: $BACKUP_DIR"
    fi
    log_error "==========================================="
    exit $exit_code
  }

  # Rollback function for configuration files
  rollback() {
    log "Attempting to rollback changes..."
    if [[ -d "$BACKUP_DIR" ]]; then
      for backup in "$BACKUP_DIR"/*; do
        if [[ -f "$backup" ]]; then
          original="$HOME/.$(basename "$backup")"
          cp "$backup" "$original" && log "Restored $original" || log_error "Failed to restore $original"
        fi
      done
    else
      log "No backup directory found, nothing to rollback"
    fi
  }

  # Interrupt handler
  interrupt_handler() {
    echo
    log "Script interrupted by user (Ctrl+C)"
    log "Performing cleanup..."
    rollback
    log "Script terminated by user. Log file: $LOG_FILE"
    exit 130
  }

  # Set up comprehensive error handling
  trap cleanup ERR
  trap interrupt_handler INT TERM
}

# === Validation Functions ===
is_root() {
  [[ $EUID -eq 0 ]]
}

check_internet() {
  curl -s --head http://google.com > /dev/null
}

validate_email() {
  local email="$1"
  [[ "$email" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]
}

# === Package Management Helpers ===
apt_update_if_needed() {
  local last_update
  if [[ -f /var/cache/apt/pkgcache.bin ]]; then
    last_update=$(stat -c %Y /var/cache/apt/pkgcache.bin)
    current_time=$(date +%s)
    # Update if cache is older than 1 hour
    if [[ $((current_time - last_update)) -gt 3600 ]]; then
      sudo apt update
    fi
  else
    sudo apt update
  fi
}

install_apt_package() {
  local package="$1"
  if ! dpkg -l "$package" &> /dev/null; then
    log "Installing $package..."
    apt_update_if_needed
    sudo apt install -y "$package"
    log_success "$package installed"
  else
    log "$package already installed, skipping..."
  fi
}

# === Flatpak Helpers ===
install_flatpak_app() {
  local app_id="$1"
  if ! flatpak list --app | grep -q "$app_id"; then
    log "Installing $app_id..."
    flatpak install flathub -y "$app_id" || log_error "Failed to install $app_id"
  else
    log "$app_id already installed, skipping..."
  fi
}

# === Git Configuration Helpers ===
setup_git_config() {
  local name="$1"
  local email="$2"
  
  git config --global user.name "$name"
  git config --global user.email "$email"
  git config --global init.defaultBranch main
  git config --global pull.rebase false
  git config --global core.autocrlf input
  
  log "Git configured for $name <$email>"
}

# === SSH Helpers ===
generate_ssh_key() {
  local service="$1"
  local key_type="$2"
  local email="$3"
  local passphrase="$4"
  local key_file="$HOME/.ssh/id_${service}_${key_type}"
  
  if [[ ! -f "$key_file" ]]; then
    log "Generating SSH key for $service..."
    case "$key_type" in
      "ed25519")
        ssh-keygen -t ed25519 -C "$email" -f "$key_file" -N "$passphrase"
        ;;
      "rsa")
        if [[ "$service" == "pantheon" ]]; then
          ssh-keygen -t rsa -b 4096 -m PEM -C "$email" -f "$key_file" -N "$passphrase"
        else
          ssh-keygen -t rsa -b 4096 -C "$email" -f "$key_file" -N "$passphrase"
        fi
        ;;
    esac
    log_success "SSH key generated for $service"
  else
    log "SSH key for $service already exists, skipping..."
  fi
}

add_ssh_key_to_agent() {
  local key_file="$1"
  if [[ -f "$key_file" ]]; then
    # Start ssh-agent if not running
    if ! pgrep -u "$USER" ssh-agent > /dev/null; then
      eval "$(ssh-agent -s)"
    fi
    ssh-add "$key_file" 2>/dev/null || log_error "Failed to add $key_file to ssh-agent"
  fi
}

# === Version Checks ===
get_latest_github_release() {
  local repo="$1"
  curl -s "https://api.github.com/repos/$repo/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/'
}

# === Module System ===
load_config() {
  local config_file="$1"
  if [[ -f "$config_file" ]]; then
    source "$config_file"
  else
    log_warning "Config file $config_file not found"
  fi
}

run_module() {
  local module_path="$1"
  if [[ -f "$module_path" && -x "$module_path" ]]; then
    log "Running module: $(basename "$module_path")"
    "$module_path"
  else
    log_error "Module not found or not executable: $module_path"
    return 1
  fi
}

# === Version Tracking Function ===
record_tool_versions() {
  begin_section "Tool Versions"
  
  local tools=("bash" "git" "curl" "wget" "docker" "docker-compose" "node" "npm" "php" "composer" "python3" "pip3")
  
  for tool in "${tools[@]}"; do
    if command -v "$tool" &>/dev/null; then
      local version
      case "$tool" in
        "bash")
          version="$($tool --version | head -n1)"
          ;;
        "git")
          version="$($tool --version)"
          ;;
        "docker")
          version="$($tool --version)"
          ;;
        "docker-compose")
          version="$($tool --version)"
          ;;
        "node")
          version="$($tool --version)"
          ;;
        "npm")
          version="$($tool --version)"
          ;;
        "php")
          version="$($tool --version | head -n1)"
          ;;
        "composer")
          version="$($tool --version)"
          ;;
        "python3")
          version="$($tool --version)"
          ;;
        "pip3")
          version="$($tool --version)"
          ;;
        *)
          version="$($tool --version 2>/dev/null || echo 'version unknown')"
          ;;
      esac
      log "$tool: $version"
    fi
  done
  
  # Record system information
  if command -v lsb_release &>/dev/null; then
    log "OS: $(lsb_release -d -s)"
  elif [[ -f /etc/os-release ]]; then
    log "OS: $(grep PRETTY_NAME /etc/os-release | cut -d'"' -f2)"
  fi
  
  log "Kernel: $(uname -r)"
  log "Architecture: $(uname -m)"
  
  end_section "Tool Versions"
}

# === User Configuration Management ===

# Configuration file location
USER_CONFIG_DIR="$HOME/.config/workspace-scripts"
USER_CONFIG_FILE="$USER_CONFIG_DIR/user.conf"

# Load user configuration if it exists
load_user_config() {
  if [[ -f "$USER_CONFIG_FILE" ]]; then
    log "Loading saved user configuration from $USER_CONFIG_FILE"
    # Source the config file in a safe way
    while IFS='=' read -r key value; do
      # Skip comments and empty lines
      [[ "$key" =~ ^[[:space:]]*# ]] && continue
      [[ -z "$key" ]] && continue
      
      # Export the variable if not already set by environment
      if [[ -z "${!key:-}" ]]; then
        export "$key"="$value"
      fi
    done < "$USER_CONFIG_FILE"
  else
    log "No saved user configuration found at $USER_CONFIG_FILE"
  fi
}

# Save user configuration to file
save_user_config() {
  mkdir -p "$USER_CONFIG_DIR"
  
  cat > "$USER_CONFIG_FILE" << EOF
# Workspace Scripts User Configuration
# Generated: $(date)
# This file stores your preferences to avoid re-entering them

# Git Configuration
GIT_NAME=${GIT_NAME:-}
GIT_EMAIL=${GIT_EMAIL:-}

# SSH Configuration (passphrase intentionally not saved for security)
# SSH_PASSPHRASE=  # Not saved for security reasons

# Pantheon Configuration
PANTHEON_ENV_ID=${PANTHEON_ENV_ID:-}

# Application Preferences
APP_GROUPS=${APP_GROUPS:-essential}
SNAP_APPS=${SNAP_APPS:-essential}

# Other Preferences
DEFAULT_BROWSER=${DEFAULT_BROWSER:-auto}
EOF

  chmod 600 "$USER_CONFIG_FILE"  # Restrict permissions
  log_success "User configuration saved to $USER_CONFIG_FILE"
}

# Enhanced prompt function that offers to save responses
prompt_and_save() {
  local env_var="$1"
  local prompt="$2"
  local default_value="${3:-}"
  local save_config="${4:-true}"  # Whether to offer saving
  
  # Check if environment variable is set and non-empty
  if [[ -n "${!env_var:-}" ]]; then
    echo "${!env_var}"
    return 0
  fi
  
  # Check for saved value in config
  if [[ -f "$USER_CONFIG_FILE" ]]; then
    local saved_value
    saved_value=$(grep "^$env_var=" "$USER_CONFIG_FILE" 2>/dev/null | cut -d'=' -f2- || echo "")
    if [[ -n "$saved_value" ]]; then
      default_value="$saved_value"
    fi
  fi
  
  # Interactive prompt
  local response
  if [[ -n "$default_value" ]]; then
    read -p "$prompt [$default_value]: " -r response
    response="${response:-$default_value}"
  else
    read -p "$prompt: " -r response
  fi
  
  # Export the variable
  export "$env_var"="$response"
  
  # Offer to save (except for sensitive data like passwords)
  if [[ "$save_config" == "true" && "$env_var" != *"PASSPHRASE"* && "$env_var" != *"PASSWORD"* ]]; then
    if [[ "${NON_INTERACTIVE:-false}" != "true" ]]; then
      if confirm_yes "Save $env_var for future use?"; then
        # Update or create config file
        mkdir -p "$USER_CONFIG_DIR"
        
        # Create config if it doesn't exist
        if [[ ! -f "$USER_CONFIG_FILE" ]]; then
          save_user_config
        else
          # Update existing config
          if grep -q "^$env_var=" "$USER_CONFIG_FILE"; then
            # Update existing entry
            sed -i "s/^$env_var=.*/$env_var=$response/" "$USER_CONFIG_FILE"
          else
            # Add new entry
            echo "$env_var=$response" >> "$USER_CONFIG_FILE"
          fi
          log "Updated $env_var in user configuration"
        fi
      fi
    fi
  fi
  
  echo "$response"
}

# Show current configuration
show_user_config() {
  if [[ -f "$USER_CONFIG_FILE" ]]; then
    echo "📋 Current saved configuration:"
    echo ""
    while IFS='=' read -r key value; do
      # Skip comments and empty lines
      [[ "$key" =~ ^[[:space:]]*# ]] && continue
      [[ -z "$key" ]] && continue
      
      # Mask sensitive values
      if [[ "$key" =~ (PASSPHRASE|PASSWORD|TOKEN|KEY) ]]; then
        echo "  $key: [REDACTED]"
      else
        echo "  $key: $value"
      fi
    done < "$USER_CONFIG_FILE"
    echo ""
    echo "Configuration file: $USER_CONFIG_FILE"
  else
    echo "❌ No saved configuration found"
    echo "Run the setup script to create one: ./setup/install.sh"
  fi
}

# Reset user configuration
reset_user_config() {
  if [[ -f "$USER_CONFIG_FILE" ]]; then
    rm "$USER_CONFIG_FILE"
    log_success "User configuration reset (file deleted)"
  else
    log "No user configuration file to reset"
  fi
}

# === Cleanup Function ===
cleanup_temp_files() {
  local temp_dir="${1:-/tmp}"
  find "$temp_dir" -name "workspace-script-*" -type f -mtime +1 -delete 2>/dev/null || true
}
