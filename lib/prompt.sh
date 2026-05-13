#!/usr/bin/env bash
# Interactive prompts and user-configuration persistence.
# Sourced by install.sh; do not execute directly.

# --- Configuration file location ---------------------------------------------

USER_CONFIG_DIR="$HOME/.config/workspace-scripts"
USER_CONFIG_FILE="$USER_CONFIG_DIR/user.conf"

# --- Simple prompts ----------------------------------------------------------

confirm_yes() {
  local prompt="${1:-Do you want to continue?}"
  local response

  while true; do
    read -p "$prompt [y/N]: " -r response
    case "$response" in
      [yY][eE][sS]|[yY]) return 0 ;;
      [nN][oO]|[nN]|"")  return 1 ;;
      *) echo "Please answer yes or no." ;;
    esac
  done
}

# Prompt for input with environment-variable fallback.
prompt_or_env() {
  local env_var="$1" prompt="$2" default_value="${3:-}"

  if [[ -n "${!env_var:-}" ]]; then
    echo "${!env_var}"
    return 0
  fi

  local response
  if [[ -n "$default_value" ]]; then
    read -p "$prompt [$default_value]: " -r response
    echo "${response:-$default_value}"
  else
    read -p "$prompt: " -r response
    echo "$response"
  fi
}

# --- User config persistence -------------------------------------------------

load_user_config() {
  if [[ -f "$USER_CONFIG_FILE" ]]; then
    log "Loading saved user configuration from $USER_CONFIG_FILE"
    while IFS='=' read -r key value; do
      [[ "$key" =~ ^[[:space:]]*# ]] && continue
      [[ -z "$key" ]] && continue
      # Only set if not already provided by the environment.
      if [[ -z "${!key:-}" ]]; then
        export "$key"="$value"
      fi
    done < "$USER_CONFIG_FILE"
  fi
}

save_user_config() {
  mkdir -p "$USER_CONFIG_DIR"

  cat > "$USER_CONFIG_FILE" <<EOF
# Workspace Scripts User Configuration
# Generated: $(date)

GIT_NAME=${GIT_NAME:-}
GIT_EMAIL=${GIT_EMAIL:-}
PANTHEON_ENV_ID=${PANTHEON_ENV_ID:-}
APP_GROUPS=${APP_GROUPS:-essential}
SNAP_APPS=${SNAP_APPS:-essential}
DEFAULT_BROWSER=${DEFAULT_BROWSER:-auto}
EOF

  chmod 600 "$USER_CONFIG_FILE"
  log_success "User configuration saved to $USER_CONFIG_FILE"
}

# Prompt, export, and optionally persist the value.
prompt_and_save() {
  local env_var="$1" prompt="$2" default_value="${3:-}" save_config="${4:-true}"

  # Environment variable already set?
  if [[ -n "${!env_var:-}" ]]; then
    echo "${!env_var}"
    return 0
  fi

  # Check for saved value.
  if [[ -f "$USER_CONFIG_FILE" ]]; then
    local saved
    saved=$(grep "^${env_var}=" "$USER_CONFIG_FILE" 2>/dev/null | cut -d'=' -f2- || true)
    [[ -n "$saved" ]] && default_value="$saved"
  fi

  local response
  if [[ -n "$default_value" ]]; then
    read -p "$prompt [$default_value]: " -r response
    response="${response:-$default_value}"
  else
    read -p "$prompt: " -r response
  fi

  export "$env_var"="$response"

  # Offer to save (skip sensitive values).
  if [[ "$save_config" == "true" && ! "$env_var" =~ (PASSPHRASE|PASSWORD|TOKEN|SECRET) ]]; then
    if [[ "${NON_INTERACTIVE:-false}" != "true" ]]; then
      if confirm_yes "Save $env_var for future use?"; then
        mkdir -p "$USER_CONFIG_DIR"
        if [[ ! -f "$USER_CONFIG_FILE" ]]; then
          save_user_config
        elif grep -q "^${env_var}=" "$USER_CONFIG_FILE"; then
          sed -i "s/^${env_var}=.*/${env_var}=${response}/" "$USER_CONFIG_FILE"
        else
          echo "${env_var}=${response}" >> "$USER_CONFIG_FILE"
        fi
        log "Updated $env_var in user configuration"
      fi
    fi
  fi

  echo "$response"
}

show_user_config() {
  if [[ -f "$USER_CONFIG_FILE" ]]; then
    echo "Current saved configuration:"
    echo ""
    while IFS='=' read -r key value; do
      [[ "$key" =~ ^[[:space:]]*# ]] && continue
      [[ -z "$key" ]] && continue
      if [[ "$key" =~ (PASSPHRASE|PASSWORD|TOKEN|SECRET) ]]; then
        echo "  $key: [REDACTED]"
      else
        echo "  $key: $value"
      fi
    done < "$USER_CONFIG_FILE"
    echo ""
    echo "Configuration file: $USER_CONFIG_FILE"
  else
    echo "No saved configuration found."
  fi
}

reset_user_config() {
  if [[ -f "$USER_CONFIG_FILE" ]]; then
    rm "$USER_CONFIG_FILE"
    log_success "User configuration reset (file deleted)"
  else
    log "No user configuration file to reset"
  fi
}
