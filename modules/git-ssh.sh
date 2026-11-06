#!/usr/bin/env bash
# Module: git-ssh - Git configuration and SSH key generation.

mod::git-ssh() {
  begin_section "Git and SSH Setup"

  source "$WS_ROOT/config/ssh-hosts.conf"

  # --- Git config -----------------------------------------------------------
  local git_name git_email
  git_name=$(prompt_and_save "GIT_NAME" "Enter your Git name") || die "GIT_NAME is required"
  git_email=$(prompt_and_save "GIT_EMAIL" "Enter your Git email") || die "GIT_EMAIL is required"

  if ! [[ "$git_email" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then
    die "Invalid email format: $git_email"
  fi

  git config --global user.name "$git_name" || die "Failed to set git user.name"
  git config --global user.email "$git_email" || die "Failed to set git user.email"
  # Only set defaults if not already configured (preserve existing preferences).
  git config --global init.defaultBranch >/dev/null 2>&1 || git config --global init.defaultBranch main
  git config --global pull.rebase >/dev/null 2>&1       || git config --global pull.rebase false
  git config --global core.autocrlf >/dev/null 2>&1      || git config --global core.autocrlf input
  log "Git configured for $git_name <$git_email>"

  # --- SSH passphrase -------------------------------------------------------
  # Validated before any key is generated: ssh-keygen rejects passphrases
  # shorter than 5 characters, and that would fail after earlier keys exist.
  local ssh_passphrase="" min_passphrase=5
  if [[ -n "${SSH_PASSPHRASE:-}" ]]; then
    ssh_passphrase="$SSH_PASSPHRASE"
    if (( ${#ssh_passphrase} < min_passphrase )); then
      die "SSH_PASSPHRASE must be empty or at least $min_passphrase characters (ssh-keygen minimum)"
    fi
    log "Using SSH passphrase from environment variable"
  elif [[ "${NON_INTERACTIVE:-false}" == "true" ]]; then
    log_warning "Non-interactive mode: SSH keys will be generated without passphrase"
  else
    while true; do
      read -rs -p "Enter passphrase for SSH keys (Enter for none, min $min_passphrase characters): " ssh_passphrase || ssh_passphrase=""
      echo
      if [[ -z "$ssh_passphrase" ]] || (( ${#ssh_passphrase} >= min_passphrase )); then
        break
      fi
      log_warning "Passphrase is too short (minimum $min_passphrase characters); please try again"
    done
  fi

  if [[ -z "$ssh_passphrase" ]]; then
    log_warning "SSH keys will be generated without passphrase"
    if [[ "${NON_INTERACTIVE:-false}" != "true" ]]; then
      confirm_yes "Continue without passphrase?" || { log "SSH setup cancelled"; return 1; }
    fi
  fi

  # --- Generate keys --------------------------------------------------------
  mkdir -p "$HOME/.ssh"
  chmod 700 "$HOME/.ssh"

  for service in "${!SSH_KEYS[@]}"; do
    local key_type="${SSH_KEYS[$service]}"
    local key_file="$HOME/.ssh/id_${service}_${key_type}"

    if [[ -f "$key_file" ]]; then
      log "SSH key for $service already exists, skipping"
      continue
    fi

    log "Generating SSH key for $service..."
    case "$key_type" in
      ed25519)
        ssh-keygen -t ed25519 -C "$git_email" -f "$key_file" -N "$ssh_passphrase" \
          || die "ssh-keygen failed for $service"
        ;;
      rsa)
        if [[ "$service" == "pantheon" ]]; then
          ssh-keygen -t rsa -b 4096 -m PEM -C "$git_email" -f "$key_file" -N "$ssh_passphrase" \
            || die "ssh-keygen failed for $service"
        else
          ssh-keygen -t rsa -b 4096 -C "$git_email" -f "$key_file" -N "$ssh_passphrase" \
            || die "ssh-keygen failed for $service"
        fi
        ;;
    esac
    log_success "SSH key generated for $service"
  done

  # --- SSH config -----------------------------------------------------------
  # Keys are not loaded into an agent here (that would ask for the passphrase
  # during the install and leave a stray agent behind). AddKeysToAgent loads
  # each key into the desktop agent on first use instead.
  if [[ ! -f "$HOME/.ssh/config" ]]; then
    log "Creating SSH config..."

    local pantheon_env_id
    pantheon_env_id=$(prompt_and_save "PANTHEON_ENV_ID" "Enter your Pantheon ENV ID (optional)" "") \
      || die "PANTHEON_ENV_ID lookup failed"

    cat > "$HOME/.ssh/config" <<EOF
# GitHub
Host github.com
  HostName github.com
  User git
  IdentityFile ~/.ssh/id_github_ed25519
  IdentitiesOnly yes
  AddKeysToAgent yes

# Bitbucket
Host bitbucket.org
  HostName bitbucket.org
  User git
  IdentityFile ~/.ssh/id_bitbucket_rsa
  IdentitiesOnly yes
  AddKeysToAgent yes
EOF

    if [[ -n "$pantheon_env_id" ]]; then
      cat >> "$HOME/.ssh/config" <<EOF

# Pantheon
Host pantheon
  HostName ssh.dev.pantheon.io
  User codeserver.dev.$pantheon_env_id
  IdentityFile ~/.ssh/id_pantheon_rsa
  IdentitiesOnly yes
  AddKeysToAgent yes
EOF
    fi

    chmod 600 "$HOME/.ssh/config"
    log_success "SSH config created"
  else
    log "SSH config already exists, skipping"
  fi

  # --- Display public keys --------------------------------------------------
  log "Your SSH public keys:"
  for service in "${!SSH_KEYS[@]}"; do
    local pub="$HOME/.ssh/id_${service}_${SSH_KEYS[$service]}.pub"
    if [[ -f "$pub" ]]; then
      echo "=== $service ==="
      cat "$pub"
      echo
    fi
  done

  log_success "Git and SSH setup completed"
  end_section "Git and SSH Setup"
}
