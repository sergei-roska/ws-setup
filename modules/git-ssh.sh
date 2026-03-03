#!/usr/bin/env bash
# Module: git-ssh — Git configuration and SSH key generation.

mod::git-ssh() {
  begin_section "Git and SSH Setup"

  source "$WS_ROOT/config/ssh-hosts.conf"

  # --- Git config -----------------------------------------------------------
  local git_name git_email
  git_name=$(prompt_and_save "GIT_NAME" "Enter your Git name")
  git_email=$(prompt_and_save "GIT_EMAIL" "Enter your Git email")

  if ! [[ "$git_email" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then
    die "Invalid email format: $git_email"
  fi

  git config --global user.name "$git_name"
  git config --global user.email "$git_email"
  # Only set defaults if not already configured (preserve existing preferences).
  git config --global init.defaultBranch 2>/dev/null || git config --global init.defaultBranch main
  git config --global pull.rebase 2>/dev/null       || git config --global pull.rebase false
  git config --global core.autocrlf 2>/dev/null      || git config --global core.autocrlf input
  log "Git configured for $git_name <$git_email>"

  # --- SSH passphrase -------------------------------------------------------
  local ssh_passphrase=""
  if [[ -n "${SSH_PASSPHRASE:-}" ]]; then
    ssh_passphrase="$SSH_PASSPHRASE"
    log "Using SSH passphrase from environment variable"
  elif [[ "${NON_INTERACTIVE:-false}" == "true" ]]; then
    log_warning "Non-interactive mode: SSH keys will be generated without passphrase"
  else
    read -rs -p "Enter passphrase for SSH keys (Enter for none): " ssh_passphrase
    echo
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
      ed25519) ssh-keygen -t ed25519 -C "$git_email" -f "$key_file" -N "$ssh_passphrase" ;;
      rsa)
        if [[ "$service" == "pantheon" ]]; then
          ssh-keygen -t rsa -b 4096 -m PEM -C "$git_email" -f "$key_file" -N "$ssh_passphrase"
        else
          ssh-keygen -t rsa -b 4096 -C "$git_email" -f "$key_file" -N "$ssh_passphrase"
        fi
        ;;
    esac
    log_success "SSH key generated for $service"
  done

  # --- SSH agent ------------------------------------------------------------
  eval "$(ssh-agent -s)"
  for service in "${!SSH_KEYS[@]}"; do
    local key_file="$HOME/.ssh/id_${service}_${SSH_KEYS[$service]}"
    if [[ -f "$key_file" ]]; then
      ssh-add "$key_file" 2>/dev/null || true
    fi
  done

  # --- SSH config -----------------------------------------------------------
  if [[ ! -f "$HOME/.ssh/config" ]]; then
    log "Creating SSH config..."

    local pantheon_env_id
    pantheon_env_id=$(prompt_and_save "PANTHEON_ENV_ID" "Enter your Pantheon ENV ID (optional)" "")

    cat > "$HOME/.ssh/config" <<EOF
# GitHub
Host github.com
  HostName github.com
  User git
  IdentityFile ~/.ssh/id_github_ed25519
  IdentitiesOnly yes

# Bitbucket
Host bitbucket.org
  HostName bitbucket.org
  User git
  IdentityFile ~/.ssh/id_bitbucket_rsa
  IdentitiesOnly yes
EOF

    if [[ -n "$pantheon_env_id" ]]; then
      cat >> "$HOME/.ssh/config" <<EOF

# Pantheon
Host pantheon
  HostName ssh.dev.pantheon.io
  User codeserver.dev.$pantheon_env_id
  IdentityFile ~/.ssh/id_pantheon_rsa
  IdentitiesOnly yes
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
