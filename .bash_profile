# Bash profile - sources .bashrc for interactive shells
# This file is read by bash on login

# Source .bashrc if it exists and shell is interactive
if [[ -f ~/.bashrc ]] && [[ $- == *i* ]]; then
    source ~/.bashrc
fi
