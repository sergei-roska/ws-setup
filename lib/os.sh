#!/usr/bin/env bash
# OS detection, command checks, and package-management helpers.
# Sourced by install.sh; do not execute directly.

# --- Command checks ----------------------------------------------------------

cmd_exists() {
  command -v "$1" &>/dev/null
}

require_cmd() {
  cmd_exists "$1" || die "Required command '$1' not found. Please install it first."
}

# --- OS checks ---------------------------------------------------------------

check_os() {
  if [[ ! -f /etc/debian_version ]]; then
    die "This script is designed for Debian/Ubuntu systems only."
  fi
  log "Detected Debian/Ubuntu system"
}

is_root() {
  [[ $EUID -eq 0 ]]
}

require_not_root() {
  is_root && die "This script should not be run as root. Please run as a regular user."
  return 0
}

check_internet() {
  if cmd_exists curl; then
    curl -fsS --max-time 5 --head https://google.com >/dev/null 2>&1
    return $?
  fi

  if cmd_exists wget; then
    wget -q --spider --timeout=5 https://google.com >/dev/null 2>&1
    return $?
  fi

  if cmd_exists ping; then
    ping -c 1 -W 5 google.com >/dev/null 2>&1
    return $?
  fi

  timeout 5 bash -c 'exec 3<>/dev/tcp/google.com/443' >/dev/null 2>&1
}

# --- APT helpers -------------------------------------------------------------

# Runs apt-get update unless the package cache is fresh (under an hour old).
# Returns the status of apt-get update, so callers can react to a failure.
apt_update_if_needed() {
  if [[ -f /var/cache/apt/pkgcache.bin ]]; then
    local last_update now
    last_update=$(stat -c %Y /var/cache/apt/pkgcache.bin)
    now=$(date +%s)
    if (( now - last_update <= 3600 )); then
      return 0
    fi
  fi
  sudo apt-get update -y
}

# Returns non-zero (and logs an error) when the package cannot be installed.
install_apt_package() {
  local package="$1"
  if dpkg-query -W -f='${Status}' "$package" 2>/dev/null | grep -q "install ok installed"; then
    log "$package already installed, skipping"
    return 0
  fi

  log "Installing $package..."
  if ! apt_update_if_needed; then
    log_error "apt-get update failed, cannot install $package"
    return 1
  fi
  if ! sudo apt-get install -y "$package"; then
    log_error "Failed to install $package"
    return 1
  fi
  log_success "$package installed"
}

# --- Version tracking --------------------------------------------------------

record_tool_versions() {
  begin_section "Tool Versions"

  local -a VERSION_CMDS=(
    "bash:--version" "git:--version" "curl:--version" "wget:--version"
    "docker:--version" "docker-compose:--version"
    "node:--version" "npm:--version"
    "php:--version" "composer:--version"
    "python3:--version" "pip3:--version"
  )

  for entry in "${VERSION_CMDS[@]}"; do
    local cmd="${entry%%:*}" flag="${entry#*:}"
    if cmd_exists "$cmd"; then
      log "$cmd: $($cmd "$flag" 2>/dev/null | head -1)"
    fi
  done

  # System info
  if cmd_exists lsb_release; then
    log "OS: $(lsb_release -d -s)"
  elif [[ -f /etc/os-release ]]; then
    log "OS: $(grep PRETTY_NAME /etc/os-release | cut -d'"' -f2)"
  fi
  log "Kernel: $(uname -r)"
  log "Architecture: $(uname -m)"

  end_section "Tool Versions"
}
