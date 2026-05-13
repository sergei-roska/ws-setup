#!/usr/bin/env bash
# Module: apps-deb — install applications from .deb packages / binary installers.

mod::apps-deb() {
  begin_section "DEB Applications"

  local groups="${APP_GROUPS:-}"
  log "DEB app groups: ${groups:-none}"

  if [[ -z "$groups" ]]; then
    log "No APP_GROUPS specified, skipping DEB applications"
    end_section "DEB Applications"
    return 0
  fi

  source "$WS_ROOT/config/apps-deb.conf"

  _deb_app_exists() {
    local app="$1"
    case "$app" in
      jetbrains-toolbox) [[ -x /opt/jetbrains-toolbox/jetbrains-toolbox ]] ;;
      libreoffice)       cmd_exists libreoffice ;;
      zoom)              cmd_exists zoom ;;
      *)                 false ;;
    esac
  }

  local -a failed_categories=()
  IFS=',' read -ra requested <<< "$groups"
  for group in "${requested[@]}"; do
    group="${group// /}"
    [[ -z "$group" ]] && continue

    local apps="${DEB_APP_CATEGORIES[$group]:-}"
    if [[ -z "$apps" ]]; then
      log_warning "Unknown DEB app category: $group"
      continue
    fi

    log "Installing $group applications..."
    local -a failed_apps=()
    read -ra app_list <<< "$apps"
    for app in "${app_list[@]}"; do
      if _deb_app_exists "$app"; then
        log "$app already installed, skipping"
        continue
      fi
      local script="$WS_ROOT/tools/apps/$group/$app.sh"
      if [[ -f "$script" ]]; then
        [[ -x "$script" ]] || chmod +x "$script"
        if "$script"; then
          log_success "$app installed"
        else
          log_error "Failed to install $app"
          failed_apps+=("$app")
        fi
      else
        log_error "Installer script not found: $script"
        failed_apps+=("$app")
      fi
    done
    [[ ${#failed_apps[@]} -gt 0 ]] && failed_categories+=("$group")
  done

  if [[ ${#failed_categories[@]} -gt 0 ]]; then
    log_warning "Some DEB categories had failures: ${failed_categories[*]}"
  else
    log_success "DEB applications installation completed"
  fi

  end_section "DEB Applications"
}
