#!/usr/bin/env bash
# Module: shell — shell aliases, prompt, and environment configuration.

mod::shell() {
  begin_section "Shell Enhancement"

  source "$WS_ROOT/config/bashrc.conf"

  # Check if already configured
  if grep -q "=== ws-setup Development Environment ===" "$HOME/.bashrc" 2>/dev/null; then
    log_skip "Shell enhancements"; end_section "Shell Enhancement"; return 0
  fi

  log "Configuring shell with custom prompt, aliases, and PATH..."

  # shellcheck disable=SC2016
  cat >> "$HOME/.bashrc" <<'SHELL_CONFIG'

# === ws-setup Development Environment ===

# History Configuration
HISTCONTROL=ignoreboth
HISTSIZE=1000
HISTFILESIZE=2000
shopt -s histappend
shopt -s checkwinsize

# Custom Prompt with Git Integration
short_pwd() {
    local dir root leaf
    if [[ "$PWD" == "$HOME" ]]; then
        dir="~"
    elif [[ "$PWD" == "$HOME"/* ]]; then
        dir="~${PWD#$HOME}"
    else
        dir="$PWD"
    fi
    if [[ "$dir" == "~" || "$dir" == "/" || "$dir" != */* ]]; then
        printf '%s' "$dir"
        return
    fi
    if [[ "$dir" == "~/"*"/"*"/"* ]]; then
        root="${dir#\~/}"
        root="${root%%/*}"
        leaf="${dir##*/}"
        printf '%s' "~/${root}/.../${leaf}"
    elif [[ "$dir" == /*/*/*/* ]]; then
        root="${dir#/}"
        root="${root%%/*}"
        leaf="${dir##*/}"
        printf '%s' "/${root}/.../${leaf}"
    else
        printf '%s' "$dir"
    fi
}

git_prompt_info() {
    git rev-parse --is-inside-work-tree >/dev/null 2>&1 || return
    local branch staged unstaged conflicts
    branch=$(git symbolic-ref --short HEAD 2>/dev/null || git rev-parse --short HEAD 2>/dev/null) || return
    git diff --cached --quiet --ignore-submodules -- 2>/dev/null || staged="+"
    git diff --quiet --ignore-submodules -- 2>/dev/null || unstaged="*"
    if git diff --name-only --diff-filter=U | grep -q .; then
        conflicts="!"
    fi
    if [[ -n "$conflicts" ]]; then
        printf 'conflict|%s%s%s' "$branch" "$staged$unstaged" "$conflicts"
    else
        printf 'clean|%s%s' "$branch" "$staged$unstaged"
    fi
}

set_bash_prompt() {
    local path_info path_prefix path_leaf path_segment git_info git_state git_payload git_segment="" title_prefix=""
    local c_reset='\[\033[00m\]'
    local c_user_host='\[\033[01;32m\]'
    local c_path_prefix='\[\033[38;5;250m\]'
    local c_path_leaf='\[\033[38;5;117m\]'
    local c_git_amber='\[\033[38;5;214m\]'
    local c_git_red='\[\033[01;31m\]'

    path_info="$(prompt_path_parts)"
    path_prefix="${path_info%%|*}"
    path_leaf="${path_info#*|}"
    if [[ -n "$path_leaf" ]]; then
        path_segment="${c_path_prefix}${path_prefix}${c_path_leaf}${path_leaf}${c_reset}"
    else
        path_segment="${c_path_leaf}${path_prefix}${c_reset}"
    fi
    git_info="$(git_prompt_info)"
    if [[ -n "$git_info" ]]; then
        git_state="${git_info%%|*}"
        git_payload="${git_info#*|}"
        if [[ "$git_state" == "conflict" ]]; then
            git_segment=" ${c_git_red}[${git_payload}]${c_reset}"
        else
            git_segment=" ${c_git_amber}[${git_payload}]${c_reset}"
        fi
    fi
    case "$TERM" in
    xterm*|rxvt*)
        title_prefix="\[\e]0;${debian_chroot:+($debian_chroot)}\u@\h: $(short_pwd)\a\]"
        ;;
    esac
    PS1="${title_prefix}"'${debian_chroot:+($debian_chroot)}'"${c_user_host}"'\u@\h'"${c_reset}"':'"${path_segment}${git_segment}"'\$ '
}

prompt_path_parts() {
    local path leaf prefix
    path="$(short_pwd)"
    if [[ "$path" == "~" || "$path" == "/" ]]; then
        printf '%s|' "$path"
        return
    fi
    leaf="${path##*/}"
    prefix="${path%$leaf}"
    printf '%s|%s' "$prefix" "$leaf"
}

PROMPT_COMMAND=set_bash_prompt

# PATH Configuration
export PATH="$HOME/.lando/bin:$PATH"
export PATH="$HOME/.config/composer/vendor/bin:$PATH"
export PATH="$HOME/.opencode/bin:$PATH"
export PATH="$HOME/.local/bin:$PATH"

# Environment Variables
export NVM_DIR="$HOME/.nvm"
export WF_DIR="$HOME/Projects/Workspace/ws-knowledge/workflows"

# NVM Initialization
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

# Homebrew (Linux)
if [ -x /home/linuxbrew/.linuxbrew/bin/brew ]; then
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
fi

# Color Support
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls --color=auto'
    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
fi

# === Aliases ===

# ls aliases
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'

# Git aliases
alias gs='git status'
alias gl='git log --oneline'
alias gp='git pull'

# Dev environment aliases
alias ddev-up='ddev start && ddev ssh'
alias lando-up='lando start && lando ssh'

# Workflow aliases (ws-knowledge)
alias wf-start="$WF_DIR/feature-start.sh"
alias wf-sync="$WF_DIR/sync-main.sh"
alias wf-deploy="$WF_DIR/drupal-deploy.sh"
alias wf-cex="$WF_DIR/config-export.sh"
alias wf-build="$WF_DIR/theme-build.sh"
alias wf-core="$WF_DIR/core-update.sh"
alias wf-push="$WF_DIR/feature-push.sh"
alias wf-phpcs="$WF_DIR/phpcs-check.sh"
alias wf-audit="$WF_DIR/security-audit.sh"
alias wf-dbreset="$WF_DIR/db-reset.sh"

# Bash Completion
if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
  fi
fi

SHELL_CONFIG

  log_success "Shell enhancements added to .bashrc"
  end_section "Shell Enhancement"
}
