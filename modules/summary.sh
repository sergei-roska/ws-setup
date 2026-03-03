#!/usr/bin/env bash
# Module: summary — display installation summary.

mod::summary() {
  begin_section "Installation Summary"

  echo
  echo "=============================================="
  echo " Web Development Environment Setup Complete"
  echo "=============================================="
  echo
  echo "Next Steps:"
  echo "  1. Restart your terminal or run: source ~/.bashrc"
  echo "  2. Log out and back in for Docker group membership"
  echo "  3. Add your SSH keys to GitHub/Bitbucket/Pantheon:"
  echo "     - GitHub:    https://github.com/settings/ssh/new"
  echo "     - Bitbucket: https://bitbucket.org/account/settings/ssh-keys/"
  echo "     - Pantheon:  https://dashboard.pantheon.io/personal-settings/ssh-keys"
  echo "  4. Test Docker:  docker run hello-world"
  echo "  5. Test Lando:   lando version"
  echo "  6. Test DDEV:    ddev version"
  echo
  echo "Log file: $LOG_FILE"
  echo "=============================================="
  echo

  log_success "Web development environment setup completed!"
  end_section "Installation Summary"
}
