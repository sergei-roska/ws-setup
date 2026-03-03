#!/usr/bin/env bash

# DEB Applications Module
# Installs applications from .deb packages and other binary installers
# Description: Install user applications from various sources

# === Load Common Library ===
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source the common library first
source "$WORKSPACE_ROOT/lib/common.sh"

begin_section "DEB Applications"
log "📦 Installing applications from various sources..."

# Configure app groups to install (default: none - explicit opt-in required)
# Supported values: comma-separated list like "dev-tools,office,media"
APP_GROUPS="${APP_GROUPS:-}"
log "Installing app groups: ${APP_GROUPS:-none}"

# Exit early if no groups specified
if [[ -z "$APP_GROUPS" ]]; then
  log "No APP_GROUPS specified, skipping DEB applications installation"
  log "To install apps, set APP_GROUPS environment variable, e.g.:"
  log "  APP_GROUPS=\"dev-tools,office\" ./install.sh"
  end_section "DEB Applications"
  exit 0
fi

# === Application Categories Configuration ===
declare -A APP_CATEGORIES

# TODO: All deb packages should be installed via wget.
# libreoffice, thunderbird, VS Code.

# Example:
#    wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
#    sudo dpkg -i google-chrome-stable_current_amd64.deb
#    sudo apt -f install

# Development Tools  
APP_CATEGORIES[dev-tools]="jetbrains-toolbox"

# Office & Communication
APP_CATEGORIES[office]="libreoffice thunderbird"

# Media & Communication
APP_CATEGORIES[media]="zoom"

# === Helper Functions ===

# Check if a group should be installed
should_install_group() {
  local group="$1"
  [[ "$APP_GROUPS" =~ (^|,)$group($|,) ]]
}

# Check if a binary already exists (skip installation)
app_exists() {
  local app_name="$1"
  case "$app_name" in
    "jetbrains-toolbox") [[ -x /opt/jetbrains-toolbox/jetbrains-toolbox ]] ;;
    "libreoffice") command -v libreoffice >/dev/null 2>&1 ;;
    "thunderbird") command -v thunderbird >/dev/null 2>&1 ;;
    "zoom") command -v zoom >/dev/null 2>&1 ;;
    *) false ;;
  esac
}

# Install a single application
install_app() {
  local category="$1"
  local app_name="$2"
  local script_path="$WORKSPACE_ROOT/tools/apps/$category/$app_name.sh"
  
  if app_exists "$app_name"; then
    log "$app_name already installed, skipping..."
    return 0
  fi
  
  if [[ ! -f "$script_path" ]]; then
    log_error "Installer script not found: $script_path"
    return 1
  fi
  
  if [[ ! -x "$script_path" ]]; then
    log "Making installer script executable: $script_path"
    chmod +x "$script_path" || {
      log_error "Failed to make $script_path executable"
      return 1
    }
  fi
  
  log "Installing $app_name..."
  if "$script_path"; then
    log_success "$app_name installed successfully"
  else
    log_error "Failed to install $app_name"
    return 1
  fi
}

# Install all apps in a category
install_category() {
  local category="$1"
  if [[ -z "${APP_CATEGORIES[$category]:-}" ]]; then
    log_warning "Unknown app category: $category"
    return 0
  fi
  
  log "Installing $category applications..."
  local apps="${APP_CATEGORIES[$category]}"
  local failed_apps=()

  # Temporarily set IFS to split on spaces to avoid common.sh newline/tab IFS
  local IFS_OLD="$IFS"
  IFS=' '
  local app_list=()
  read -r -a app_list <<< "$apps"
  IFS="$IFS_OLD"
  
  for app in "${app_list[@]}"; do
    if [[ -n "$app" ]]; then
      if ! install_app "$category" "$app"; then
        failed_apps+=("$app")
      fi
    fi
  done
  
  if [[ ${#failed_apps[@]} -gt 0 ]]; then
    log_warning "Failed to install some $category apps: ${failed_apps[*]}"
    return 1
  else
    log_success "All $category applications installed successfully"
    return 0
  fi
}

# === Main Installation Logic ===

# Parse and install requested categories
IFS=',' read -ra groups <<< "$APP_GROUPS"
total_categories=${#groups[@]}
failed_categories=()

for group in "${groups[@]}"; do
  group=$(echo "$group" | xargs) # trim whitespace
  if [[ -n "$group" ]]; then
    log "Processing category: $group"
    if ! install_category "$group"; then
      failed_categories+=("$group")
    fi
  fi
done

# === Summary ===
if [[ ${#failed_categories[@]} -gt 0 ]]; then
  log_warning "Some application categories failed to install completely: ${failed_categories[*]}"
  log_warning "Check the log file for details: $LOG_FILE"
else
  log_success "All requested application categories installed successfully!"
fi

log_success "DEB applications installation completed"
end_section "DEB Applications"
