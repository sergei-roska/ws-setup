#!/usr/bin/env bash

# Git and SSH Setup Module
# Configures Git and generates SSH keys

# === Load Common Library ===
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source the common library first
source "$WORKSPACE_ROOT/lib/common.sh"

begin_section "Git and SSH Setup"
log "🔐 Setting up Git and SSH..."

# Git configuration using saved settings, environment variables or interactive prompts
git_name=$(prompt_and_save "GIT_NAME" "🧑 Enter your Git name")
git_email=$(prompt_and_save "GIT_EMAIL" "📧 Enter your Git email")

if ! validate_email "$git_email"; then
  die "Invalid email format: $git_email"
fi

setup_git_config "$git_name" "$git_email"

# SSH setup - check environment variable first, then prompt
if [[ -n "${SSH_PASSPHRASE:-}" ]]; then
  ssh_passphrase="$SSH_PASSPHRASE"
  log "Using SSH passphrase from environment variable"
else
  # In non-interactive mode, use empty passphrase
  if [[ "${NON_INTERACTIVE:-false}" == "true" ]]; then
    ssh_passphrase=""
    log_warning "Non-interactive mode: SSH keys will be generated without passphrase"
  else
    # Interactive prompt (passphrases are never saved for security)
    read -s -p "🔐 Enter passphrase for SSH keys (recommended, press Enter for no passphrase): " ssh_passphrase
    echo
  fi
fi

if [[ -z "$ssh_passphrase" ]]; then
  log_warning "SSH keys will be generated without passphrase"
  if [[ "${NON_INTERACTIVE:-false}" != "true" ]]; then
    if ! confirm_yes "Continue without passphrase?"; then
      log "SSH setup cancelled"
      exit 1
    fi
  fi
fi

# Create SSH directory
log "📂 Setting up SSH directory..."
mkdir -p ~/.ssh
chmod 700 ~/.ssh

# Generate SSH keys
declare -A ssh_keys=(
  ["github"]="ed25519"
  ["bitbucket"]="rsa"
  ["pantheon"]="rsa"
)

for service in "${!ssh_keys[@]}"; do
  generate_ssh_key "$service" "${ssh_keys[$service]}" "$git_email" "$ssh_passphrase"
done

# Add keys to ssh-agent
log "💡 Adding keys to ssh-agent..."
eval "$(ssh-agent -s)"
for service in "${!ssh_keys[@]}"; do
  key_file="$HOME/.ssh/id_${service}_${ssh_keys[$service]}"
  add_ssh_key_to_agent "$key_file"
done

# SSH config
if [[ ! -f "$HOME/.ssh/config" ]]; then
  log "⚙️ Creating SSH config..."

  pantheon_env_id=$(prompt_and_save "PANTHEON_ENV_ID" "🖥 Enter your Pantheon ENV ID (optional)" "")

  cat > ~/.ssh/config <<EOF
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
    cat >> ~/.ssh/config <<EOF

# Pantheon
Host pantheon
  HostName ssh.dev.pantheon.io
  User codeserver.dev.$pantheon_env_id
  IdentityFile ~/.ssh/id_pantheon_rsa
  IdentitiesOnly yes
EOF
  fi

  chmod 600 ~/.ssh/config
  log_success "SSH config created"
else
  log "SSH config already exists, skipping..."
fi

# Display public keys
log "📎 Your SSH public keys:"
for service in "${!ssh_keys[@]}"; do
  key_file="$HOME/.ssh/id_${service}_${ssh_keys[$service]}.pub"
  if [[ -f "$key_file" ]]; then
    echo "=== $service ==="
    cat "$key_file"
    echo
  fi
done

log_success "Git and SSH setup completed"
end_section "Git and SSH Setup"
