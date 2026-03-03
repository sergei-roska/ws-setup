#!/usr/bin/env bash

# Snap Applications Module
# Installs useful applications via Snap package manager
# Description: Install applications that work best via Snap

# === Load Common Library ===
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source the common library first
source "$WORKSPACE_ROOT/lib/common.sh"

begin_section "Snap Applications"

# Configure snap apps to install (default: essential only)
# Supported values: "none", "essential", "all", or comma-separated list like "firefox,spotify"
SNAP_APPS="${SNAP_APPS:-essential}"
log "Installing snap apps: $SNAP_APPS"

# Exit early if SNAP_APPS is "none"
if [[ "$SNAP_APPS" == "none" ]]; then
  log "SNAP_APPS set to 'none', skipping snap applications installation"
  end_section "Snap Applications"
  exit 0
fi

# Ensure Snap is installed
if ! command -v snap &> /dev/null; then
  log "Installing snapd..."
  install_apt_package snapd
  
  # Start snap services
  if command -v systemctl &> /dev/null; then
    sudo systemctl enable --now snapd.service
    sudo systemctl enable --now snapd.socket
  fi
  
  # Create symlink for classic snap support
  if [[ ! -L /snap ]]; then
    sudo ln -sf /var/lib/snapd/snap /snap
  fi
else
  log "Snap already installed"
fi

# === Snap Applications Configuration ===

# Essential snap apps (work better via snap than other sources)
ESSENTIAL_SNAP_APPS=(
  "spotify"          # Music streaming
)

# Optional snap apps
OPTIONAL_SNAP_APPS=(
  "firefox"          # Web browser
# "libreoffice"      # Office suite (if not installed via .deb)
# "thunderbird"      # Email client (if not installed via .deb)
#  "code"             # VS Code (if not installed via .deb)
)

# === Helper Functions ===

# Check if a snap app should be installed
should_install_snap() {
  local app="$1"
  case "$SNAP_APPS" in
    "all") return 0 ;;
    "essential") 
      for essential_app in "${ESSENTIAL_SNAP_APPS[@]}"; do
        [[ "$app" == "$essential_app" ]] && return 0
      done
      return 1
      ;;
    *) [[ "$SNAP_APPS" =~ (^|,)$app($|,) ]] ;;
  esac
}

# Check if snap app is already installed
snap_app_exists() {
  local app="$1"
  snap list "$app" &>/dev/null
}

# Install a snap application
install_snap_app() {
  local app="$1"
  local install_args="${2:-}"
  
  if snap_app_exists "$app"; then
    log "$app already installed via snap, skipping..."
    return 0
  fi
  
  log "Installing $app via snap..."
  if sudo snap install $install_args "$app"; then
    log_success "$app installed successfully"
  else
    log_error "Failed to install $app"
    return 1
  fi
}

# === Install Snap Applications ===

failed_apps=()

# Install essential apps
for app in "${ESSENTIAL_SNAP_APPS[@]}"; do
  if should_install_snap "$app"; then
    if ! install_snap_app "$app"; then
      failed_apps+=("$app")
    fi
  fi
done

# Install optional apps if requested
if [[ "$SNAP_APPS" == "all" ]]; then
  for app in "${OPTIONAL_SNAP_APPS[@]}"; do
    if ! install_snap_app "$app"; then
      failed_apps+=("$app")
    fi
  done
fi

# Install explicitly requested apps
if [[ "$SNAP_APPS" != "essential" && "$SNAP_APPS" != "all" && "$SNAP_APPS" != "none" ]]; then
  IFS=',' read -ra requested_apps <<< "$SNAP_APPS"
  for app in "${requested_apps[@]}"; do
    app=$(echo "$app" | xargs) # trim whitespace
    if [[ -n "$app" ]]; then
      if ! install_snap_app "$app"; then
        failed_apps+=("$app")
      fi
    fi
  done
fi

# === Summary ===
if [[ ${#failed_apps[@]} -gt 0 ]]; then
  log_warning "Some snap applications failed to install: ${failed_apps[*]}"
else
  log_success "All requested snap applications installed successfully!"
fi

log_success "Snap applications installation completed"
end_section "Snap Applications"
