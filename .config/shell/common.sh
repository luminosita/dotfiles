# Common shell configuration for both bash and zsh
# Source this file from .bashrc or .zshrc

# History settings
export HISTSIZE=10000
export SAVEHIST=10000
export HISTFILESIZE=20000

# Git settings
export LANG=en_US.UTF-8

# PATH setup (common for both macOS and Linux)
export PATH="$HOME/go/bin:$PATH"
export PATH="/usr/local/bin:$PATH"
export PATH="$HOME/.local/bin:$PATH"
export PATH="/nix/var/nix/profiles/default/bin:$PATH"

# Homebrew PATH (for local user installation on both macOS and Linux)
if [[ -d "$HOME/homebrew/bin" ]]; then
    export PATH="$HOME/homebrew/bin:$PATH"
    export MANPATH="$HOME/homebrew/share/man:$MANPATH"
    export INFOPATH="$HOME/homebrew/share/info:$INFOPATH"
    export HOMEBREW_PREFIX="$HOME/homebrew"
    export HOMEBREW_REPOSITORY="$HOME/homebrew"
    export HOMEBREW_CACHE="$HOME/.cache/homebrew"
    export HOMEBREW_TEMP="$HOME/tmp/homebrew"
    export HOMEBREW_LOGS="$HOME/.cache/homebrew/Logs"
fi

# Starship prompt (if installed)
if command -v starship &> /dev/null; then
    if [[ -n "$ZSH_VERSION" ]]; then
        eval "$(starship init zsh)"
    elif [[ -n "$BASH_VERSION" ]]; then
        eval "$(starship init bash)"
    fi
fi

# Thefuck (if installed)
if command -v thefuck &> /dev/null; then
    eval "$(thefuck --alias)"
fi

# Zoxide (if installed)
if command -v zoxide &> /dev/null; then
    if [[ -n "$ZSH_VERSION" ]]; then
        eval "$(zoxide init --cmd cd zsh)"
    elif [[ -n "$BASH_VERSION" ]]; then
        eval "$(zoxide init --cmd cd bash)"
    fi
fi

# Kubectl completion and kubecolor
if command -v kubectl &> /dev/null; then
    if [[ -n "$ZSH_VERSION" ]]; then
        source <(kubectl completion zsh)
        if command -v kubecolor &> /dev/null; then
            compdef kubecolor=kubectl
        fi
    elif [[ -n "$BASH_VERSION" ]]; then
        source <(kubectl completion bash)
        if command -v kubecolor &> /dev/null; then
            complete -o default -F __start_kubectl kubecolor
        fi
    fi
fi

# Aliases (common for both bash and zsh)
if command -v eza &> /dev/null; then
    alias lsa='eza --long --all --no-permissions --no-filesize --no-user --no-time --git'
    alias lst='eza --long --all --no-permissions --no-filesize --no-user --git --sort modified'
else
    alias lsa='ls -lah'
    alias lst='ls -laht'
fi

#TODO: Fix theme on Linux
if command -v bat &> /dev/null; then
    alias cat='bat --paging never --theme-dark DarkNeon --theme-light GitHub --style changes,header-filename,snip'
fi

if command -v fzf &> /dev/null && command -v bat &> /dev/null; then
    alias fzfp='fzf --preview "bat --style numbers --color always {}"'
fi

if command -v kubecolor &> /dev/null; then
    alias kubectl='kubecolor'
fi

# Nix with unfree packages
if command -v nix &> /dev/null; then
    alias nixd='nix develop --impure'
fi

# Additional common aliases
alias grep='grep --color=auto'
