#!/usr/bin/env bash

# Summary Module
# Prints installation summary and next steps

# === Load Common Library ===
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source the common library first
source "$WORKSPACE_ROOT/lib/common.sh"

begin_section "Installation Summary"
log "🎉 Installation completed!"

echo
echo "=============================================="
echo "🎉 Web Development Environment Setup Complete"
echo "=============================================="
echo
echo "✅ Installed Components:"
echo "   • System prerequisites and base packages"
echo "   • Hardware drivers (if applicable)"
echo "   • Flatpak and applications"
echo "   • Git and SSH keys"
echo "   • Docker CE with Compose"
echo "   • Lando development environment"
echo "   • DDEV development environment"  
echo "   • PHP 8.4 with common extensions"
echo "   • Composer with signature verification"
echo "   • PHP CodeSniffer with Drupal standards"
echo "   • Node.js LTS via NVM with global packages"
echo "   • Homebrew package manager"
echo "   • Terminus CLI for Pantheon"
echo "   • Shell enhancements and aliases"
echo
echo "🔧 Next Steps:"
echo "   1. Restart your terminal or run: source ~/.bashrc"
echo "   2. Log out and back in for Docker group membership"
echo "   3. Add your SSH keys to GitHub/Bitbucket/Pantheon:"
echo "      • GitHub: https://github.com/settings/ssh/new"
echo "      • Bitbucket: https://bitbucket.org/account/settings/ssh-keys/"
echo "      • Pantheon: https://dashboard.pantheon.io/personal-settings/ssh-keys"
echo "   4. Configure git if you haven't already:"
echo "      git config --global user.name 'Your Name'"
echo "      git config --global user.email 'your@email.com'"
echo "   5. Test Docker: docker run hello-world"
echo "   6. Test Lando: lando version"
echo "   7. Test DDEV: ddev version"
echo
echo "📚 Documentation & Resources:"
echo "   • Lando: https://docs.lando.dev/"
echo "   • DDEV: https://ddev.readthedocs.io/"
echo "   • Drupal Coding Standards: https://www.drupal.org/docs/develop/standards"
echo
echo "🐛 Issues? Check the log file:"
echo "   $LOG_FILE"
echo
echo "=============================================="
echo

log_success "Web development environment setup completed!"
end_section "Installation Summary"
