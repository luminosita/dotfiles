# Bash configuration for Linux/cross-platform use
# This file is primarily used on Linux systems

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

# History configuration
HISTCONTROL=ignoreboth
HISTSIZE=10000
HISTFILESIZE=20000
shopt -s histappend

# Check window size after each command
shopt -s checkwinsize

# Enable programmable completion features
if ! shopt -oq posix; then
    if [ -f /usr/share/bash-completion/bash_completion ]; then
        . /usr/share/bash-completion/bash_completion
    elif [ -f /etc/bash_completion ]; then
        . /etc/bash_completion
    fi
fi

# Bat CLI Linux hack: apt installs bat as batcat
if command -v batcat &> /dev/null && [[ ! -f "$HOME/.local/bin/bat" ]]; then
    mkdir -p $HOME/.local/bin
    ln -s /usr/bin/batcat $HOME/.local/bin/bat
fi

# Enable en_US locale
if grep -q "^# en_US.UTF-8 UTF-8" /etc/locale.gen; then
    sudo sed -i 's/^# \(en_US\.UTF-8 UTF-8\)/\1/' /etc/locale.gen
    sudo locale-gen
    echo "✓ Locale enabled"
elif ! grep -q "^en_US.UTF-8 UTF-8" /etc/locale.gen; then
    echo "en_US.UTF-8 UTF-8" | sudo tee -a /etc/locale.gen
    sudo locale-gen
    echo "✓ Locale added"
fi

# Load common shell configuration
if [[ -f "$HOME/.config/shell/common.sh" ]]; then
    source "$HOME/.config/shell/common.sh"
fi

# Bash-specific key bindings
bind '"\e[A": history-search-backward'
bind '"\e[B": history-search-forward'

# Enable color support
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls --color=auto'
    alias dir='dir --color=auto'
    alias vdir='vdir --color=auto'
fi
