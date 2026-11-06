# ws-setup

Web development environment setup for Ubuntu — single entry point, modular architecture.

## Quick Start

```bash
# Interactive (prompts for confirmation)
./install.sh

# Non-interactive
./install.sh --yes

# Selected modules only
./install.sh --only prereqs,docker,lando

# Skip specific modules
./install.sh --skip drivers,brew

# List all available modules
./install.sh --list
```

## Project Structure

```text
ws-setup/
├── install.sh              # Single entry point
├── config/                 # All package lists, versions, app IDs
│   ├── packages.conf       # APT base packages
│   ├── apps-flatpak.conf   # Flatpak apps by group
│   ├── apps-snap.conf      # Snap apps by group
│   ├── apps-ppa.conf       # PPA packages + repo mapping
│   ├── composer.conf       # Global Composer packages
│   ├── node.conf           # NVM version, global npm packages
│   ├── php.conf            # PHP version and extensions
│   └── ssh-hosts.conf      # SSH key definitions
├── lib/                    # Shared libraries (sourced by install.sh)
│   ├── log.sh              # Logging, die
│   ├── os.sh               # OS checks, apt helpers, version tracking
│   ├── prompt.sh           # Interactive prompts, user config persistence
│   ├── flatpak.sh          # Flatpak remote/GPG helpers
│   ├── backup.sh           # File backup and rollback
│   └── sudo.sh             # Sudo keepalive management
├── modules/                # Installation modules (mod::name functions)
│   ├── prereqs.sh
│   ├── drivers.sh
│   ├── snap.sh
│   ├── flatpak.sh
│   ├── flatpak-apps.sh
│   ├── git-ssh.sh
│   ├── docker.sh
│   ├── lando.sh
│   ├── ddev.sh
│   ├── php.sh
│   ├── composer.sh
│   ├── phpcs.sh
│   ├── node.sh
│   ├── brew.sh
│   ├── terminus.sh
│   ├── shell.sh
│   ├── apps-apt.sh
│   └── summary.sh
└── README.md
```

## Architecture

### Module Contract

Each module defines a single function `mod::<name>` — no top-level executable code, no library sourcing. All libraries are loaded once by `install.sh`.

```bash
# modules/docker.sh
mod::docker() {
    begin_section "Docker"
    if cmd_exists docker; then log_skip "Docker"; return 0; fi
    # ... installation logic ...
    end_section "Docker"
}
```

### Module Registry

Execution order and dependencies are declared in `install.sh`:

```bash
register_module  prereqs      ""
register_module  docker       "prereqs"
register_module  lando        "docker"
register_module  composer     "php"
register_module  terminus     "php composer"
```

If you `--skip` a dependency (or leave it out of `--only`), the orchestrator logs a warning and continues: it assumes the dependency is already installed. Modules always run in registry order, whatever order `--only` lists them in. A failing command inside a module stops the run and reports the module and the command. The exceptions are per-item installs (global Composer packages, snap, Flatpak and PPA apps): a failed item is logged and listed in a warning, and the run continues.

### Config Files

All package lists, versions, and app IDs live in `config/*.conf`. To change PHP version:

```bash
# config/php.conf
PHP_VERSION="8.5"
```

To add a global npm package:

```bash
# config/node.conf
NPM_GLOBAL_PACKAGES=(
  yarn
  pnpm
  my-new-tool   # just add here
)
```

### Git Configuration (Work vs. Personal)

The setup supports a hybrid Git configuration to keep work and personal identities separate:

1.  **Global Identity (Work):** Defined in `~/.gitconfig` (typically using your company email).
2.  **Contextual Identity (Personal):** Automatically switches to your personal email when working inside `/path/to/directory/**` using Git's `includeIf` feature.

This is managed via:
- `~/.gitconfig`: Contains the `[includeIf "gitdir:/path/to/directory/**"]` directive.
- `~/.gitconfig-personal`: Stores your personal `[user]` settings.

## CLI Reference

```text
OPTIONS:
  --yes                    Non-interactive mode
  --only MOD1,MOD2         Execute only specified modules
  --skip MOD1,MOD2         Skip specified modules
  --list                   List available modules and exit
  --log-file PATH          Override default log file path
  --verbose                Enable verbose output
  --reset-config           Reset saved user configuration
  --help                   Show help

ENVIRONMENT VARIABLES:
  GIT_NAME                 Git user name
  GIT_EMAIL                Git user email
  SSH_PASSPHRASE           SSH key passphrase
  PANTHEON_ENV_ID          Pantheon environment ID
  APP_GROUPS               essential,dev,optional (default: essential)
  SNAP_APPS                essential | all | none | app1,app2
  APT_PPA_PACKAGES         essential | all | none | pkg1,pkg2
```

## Adding a New Module

1. Create `modules/my-module.sh` with a `mod::my-module()` function.
2. Register it in `install.sh`: `register_module my-module "prereqs"`.
3. If it needs config, create `config/my-module.conf` and `source "$WS_ROOT/config/my-module.conf"` inside the function.
