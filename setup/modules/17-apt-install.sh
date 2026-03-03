#!/usr/bin/env bash

# APT PPA Applications Module
# Installs applications from PPA repositories
# Description: Install APT packages from PPAs (KeePassXC and future PPA-based apps)

# === Load Common Library ===
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source the common library first
source "$WORKSPACE_ROOT/lib/common.sh"

begin_section "APT PPA Applications"

# Configure packages to install (default: essential only)
# Supported values: "none", "essential", "all", or comma-separated list like "keepassxc"
APT_PPA_PACKAGES="${APT_PPA_PACKAGES:-essential}"
log "Installing APT PPA packages: $APT_PPA_PACKAGES"

# Exit early if APT_PPA_PACKAGES is "none"
if [[ "$APT_PPA_PACKAGES" == "none" ]]; then
  log "APT_PPA_PACKAGES set to 'none', skipping PPA packages installation"
  end_section "APT PPA Applications"
  exit 0
fi

# === PPA Repository Configuration ===
# Map package names to their PPA repositories
declare -A PPA_REPOS=(
  ["keepassxc"]="ppa:phoerious/keepassxc"
  # Add more PPAs here as needed:
  # ["inkscape"]="ppa:inkscape.dev/stable"
  # ["obs-studio"]="ppa:obsproject/obs-studio"
)

# === Package Groups Configuration ===

# Essential packages (installed by default)
ESSENTIAL_PACKAGES=(
  "keepassxc"        # Password manager
)

# Optional packages (installed when APT_PPA_PACKAGES="all")
OPTIONAL_PACKAGES=(
  # Examples for future use:
  # "inkscape"       # Vector graphics editor
  # "obs-studio"     # Video recording/streaming
)

# === Helper Functions ===

# Check if a package should be installed
should_install_package() {
  local pkg="$1"
  case "$APT_PPA_PACKAGES" in
    "all") return 0 ;;
    "essential") 
      for essential_pkg in "${ESSENTIAL_PACKAGES[@]}"; do
        [[ "$pkg" == "$essential_pkg" ]] && return 0
      done
      return 1
      ;;
    *) [[ "$APT_PPA_PACKAGES" =~ (^|,)$pkg($|,) ]] ;;
  esac
}

# Check if package is already installed
package_exists() {
  local pkg="$1"
  
  # Check via dpkg
  if dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q "install ok installed"; then
    return 0
  fi
  
  # Check via command
  if command -v "$pkg" >/dev/null 2>&1; then
    return 0
  fi
  
  return 1
}

# Add PPA repository if not already present
add_ppa_if_needed() {
  local pkg="$1"
  local repo="${PPA_REPOS[$pkg]:-}"
  
  if [[ -z "$repo" ]]; then
    log_error "No PPA repository configured for package '$pkg'"
    return 1
  fi
  
  if [[ "$repo" == ppa:* ]]; then
    # Extract PPA details (format: ppa:owner/name)
    local slug="${repo#ppa:}"
    local owner="${slug%/*}"
    local name="${slug#*/}"
    local pattern="ppa.launchpad.net/${owner}/${name}"
    
    # Check if PPA already added
    if grep -R "$pattern" /etc/apt/sources.list.d /etc/apt/sources.list >/dev/null 2>&1; then
      log "PPA $repo already present"
      return 0
    fi
    
    log "Adding PPA $repo for '$pkg'..."
    require_cmd add-apt-repository
    
    if sudo add-apt-repository -y "$repo" 2>&1 | tee -a "$LOG_FILE"; then
      log "Updating package lists..."
      sudo apt-get update -y 2>&1 | tee -a "$LOG_FILE"
      return 0
    fi
    
    log_error "Failed to add PPA $repo"
    return 1
  else
    log_error "Unsupported repository format for '$pkg': $repo"
    return 1
  fi
}

# Install a package from PPA
install_ppa_package() {
  local pkg="$1"
  
  if package_exists "$pkg"; then
    log "$pkg already installed, skipping..."
    return 0
  fi
  
  log "Installing $pkg from PPA..."
  
  # Add PPA if needed
  if ! add_ppa_if_needed "$pkg"; then
    return 1
  fi
  
  # Install package
  if install_apt_package "$pkg"; then
    log_success "$pkg installed successfully"
    return 0
  fi
  
  log_error "Failed to install $pkg"
  return 1
}

# === Install PPA Packages ===

failed_packages=()

# Install essential packages
for pkg in "${ESSENTIAL_PACKAGES[@]}"; do
  if should_install_package "$pkg"; then
    if ! install_ppa_package "$pkg"; then
      failed_packages+=("$pkg")
    fi
  fi
done

# Install optional packages if requested
if [[ "$APT_PPA_PACKAGES" == "all" ]]; then
  for pkg in "${OPTIONAL_PACKAGES[@]}"; do
    if ! install_ppa_package "$pkg"; then
      failed_packages+=("$pkg")
    fi
  done
fi

# Install explicitly requested packages
if [[ "$APT_PPA_PACKAGES" != "essential" && "$APT_PPA_PACKAGES" != "all" && "$APT_PPA_PACKAGES" != "none" ]]; then
  IFS=',' read -ra requested_packages <<< "$APT_PPA_PACKAGES"
  for pkg in "${requested_packages[@]}"; do
    pkg=$(echo "$pkg" | xargs) # trim whitespace
    if [[ -n "$pkg" ]]; then
      if [[ -z "${PPA_REPOS[$pkg]:-}" ]]; then
        log_error "Package '$pkg' is not mapped in PPA_REPOS. Add it to the configuration."
        failed_packages+=("$pkg")
        continue
      fi
      if ! install_ppa_package "$pkg"; then
        failed_packages+=("$pkg")
      fi
    fi
  done
fi

# === Summary ===
if [[ ${#failed_packages[@]} -gt 0 ]]; then
  log_warning "Some PPA packages failed to install: ${failed_packages[*]}"
else
  log_success "All requested PPA packages installed successfully!"
fi

log_success "APT PPA applications installation completed"
end_section "APT PPA Applications"
