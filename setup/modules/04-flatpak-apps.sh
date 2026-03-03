#!/usr/bin/env bash

# Flatpak Applications Module
# Installs Flatpak applications based on configuration

# === Load Common Library ===
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source the common library first
# Expecting begin_section, end_section, log, log_error, log_success, LOG_FILE, etc.
source "$WORKSPACE_ROOT/lib/common.sh"

begin_section "Flatpak Applications"
log "🌐 Installing Flatpak applications..."

# Configure app groups to install (default: all)
# Supported values: "all", or a comma-separated list of groups like "essential,development", "dev,optional", etc.
APP_GROUPS="${APP_GROUPS:-all}"
log "Installing app groups: $APP_GROUPS"

# === Embedded application configuration (human-friendly) ===
# Each element is the Flatpak app ID with a trailing inline comment for a human-readable description.

ESSENTIAL_APPS=(
  "org.videolan.VLC"              # Media Player
)

DEV_APPS=(
  "com.slack.Slack"               # Slack
  "com.axosoft.GitKraken"         # Git GUI
  "md.obsidian.Obsidian"          # Notes
  "io.github.shiftey.Desktop"     # GitHub Desktop
)

OPTIONAL_APPS=(
  "com.discordapp.Discord"             # Discord
  "com.obsproject.Studio"              # OBS Studio
  "org.gimp.GIMP"                      # Image editor
  "org.kde.kdenlive"                   # Video editor
  "net.nokyan.Resources"               # System monitor
  "org.gnome.Calendar"                 # Calendar
  "org.kde.labplot"                    # Data analysis
  "com.protonvpn.www"                  # ProtonVPN
  "me.proton.Mail"                     # ProtonMail
  "io.github.amit9838.mousam"          # Weather app
)

# === Helper to check if a group should be installed ===
should_install_group() {
  local group="$1"
  [[ "$APP_GROUPS" == "all" ]] || [[ "$APP_GROUPS" =~ (^|,)$group($|,) ]]
}

# === Installation helper ===
install_apps() {
  local label="$1"; shift
  local -a apps=("$@")

  log "Installing $label applications..."
  for app_id in "${apps[@]}"; do
    log "Installing $app_id..."
    # Suppress ANSI escape sequences and empty lines in logs
    # Use --user to avoid conflicts with duplicate flathub remotes
    if flatpak install --user flathub -y "$app_id" --noninteractive 2>&1 \
      | sed 's/\x1b\[[0-9;]*[a-zA-Z]//g' \
      | grep -v '^$' >> "$LOG_FILE"; then
      log "Successfully installed $app_id"
    else
      log_error "Failed to install $app_id"
    fi
  done
}

# === Install groups based on APP_GROUPS configuration ===
if should_install_group "essential"; then
  install_apps "Essential" "${ESSENTIAL_APPS[@]}"
fi

if should_install_group "development" || should_install_group "dev"; then
  install_apps "Development" "${DEV_APPS[@]}"
fi

if should_install_group "optional"; then
  install_apps "Optional" "${OPTIONAL_APPS[@]}"
fi

log_success "Flatpak applications installation completed"
end_section "Flatpak Applications"
