#!/usr/bin/env bash
# Module: apps-apt — install packages from PPA repositories.

mod::apps-apt() {
  begin_section "APT PPA Applications"

  local mode="${APT_PPA_PACKAGES:-essential}"
  log "PPA packages mode: $mode"

  if [[ "$mode" == "none" ]]; then
    log "APT_PPA_PACKAGES=none, skipping"
    end_section "APT PPA Applications"
    return 0
  fi

  source "$WS_ROOT/config/apps-ppa.conf"

  _ppa_package_exists() {
    dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -q "install ok installed" \
      || cmd_exists "$1"
  }

  _add_ppa_if_needed() {
    local pkg="$1"
    local repo="${PPA_REPOS[$pkg]:-}"
    [[ -z "$repo" ]] && { log_error "No PPA configured for '$pkg'"; return 1; }

    if [[ "$repo" == ppa:* ]]; then
      local slug="${repo#ppa:}"
      local owner="${slug%/*}" name="${slug#*/}"
      local pattern="ppa.launchpad.net/${owner}/${name}"
      if grep -rq "$pattern" /etc/apt/sources.list.d /etc/apt/sources.list 2>/dev/null; then
        log "PPA $repo already present"
        return 0
      fi
      log "Adding PPA $repo..."
      require_cmd add-apt-repository
      sudo add-apt-repository -y "$repo" 2>&1 | tee -a "$LOG_FILE"
      sudo apt-get update -y 2>&1 | tee -a "$LOG_FILE"
    else
      log_error "Unsupported repo format for '$pkg': $repo"
      return 1
    fi
  }

  # Decide which packages to install.
  local -a pkgs_to_install=()
  case "$mode" in
    essential) pkgs_to_install=("${PPA_ESSENTIAL[@]}") ;;
    all)       pkgs_to_install=("${PPA_ESSENTIAL[@]}" "${PPA_OPTIONAL[@]}") ;;
    *)
      IFS=',' read -ra pkgs_to_install <<< "$mode"
      ;;
  esac

  local -a failed=()
  for pkg in "${pkgs_to_install[@]}"; do
    pkg="${pkg// /}"
    [[ -z "$pkg" ]] && continue
    if _ppa_package_exists "$pkg"; then
      log "$pkg already installed, skipping"
      continue
    fi
    if [[ -z "${PPA_REPOS[$pkg]:-}" ]]; then
      log_error "'$pkg' not mapped in PPA_REPOS"
      failed+=("$pkg"); continue
    fi
    _add_ppa_if_needed "$pkg" || { failed+=("$pkg"); continue; }
    install_apt_package "$pkg" || failed+=("$pkg")
  done

  if [[ ${#failed[@]} -gt 0 ]]; then
    log_warning "Failed PPA packages: ${failed[*]}"
  else
    log_success "All PPA packages installed"
  fi

  end_section "APT PPA Applications"
}
