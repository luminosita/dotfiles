# Local Homebrew
mkdir ~/homebrew
curl -L https://github.com/Homebrew/brew/tarball/master | tar xz --strip 1 -C ~/homebrew

export PATH="$HOME/homebrew/bin:$PATH"
export MANPATH="$HOME/homebrew/share/man:$MANPATH"
export INFOPATH="$HOME/homebrew/share/info:$INFOPATH"
export HOMEBREW_PREFIX="$HOME/homebrew"
export HOMEBREW_REPOSITORY="$HOME/homebrew"
export HOMEBREW_CACHE="$HOME/.cache/homebrew"
export HOMEBREW_TEMP="$HOME/tmp/homebrew"
export HOMEBREW_LOGS="$HOME/.cache/homebrew/Logs"
#export HOMEBREW_BOTTLE_DOMAIN=""  # Optional: avoid shared precompiled binaries

mkdir -p "$HOMEBREW_CACHE" "$HOMEBREW_TEMP" "$HOMEBREW_LOGS"

brew analytics off

# Nerd Fonts
curl -sL https://github.com/ryanoasis/nerd-fonts/releases/latest/download/FiraCode.tar.xz | tar -xvf - -C ~/Library/Fonts

# https://github.com/zdharma-continuum/zinit?tab=readme-ov-file#install
bash -c "$(curl --fail --show-error --silent \
    --location https://raw.githubusercontent.com/zdharma-continuum/zinit/HEAD/scripts/install.sh)"

# local single-user Nix install 
# add ` --yes --quiet` to command line if too many questions
sh <(curl -L https://nixos.org/nix/install) --no-daemon

# Required for pulling secrets for Fabric AI
brew install bitwarden-cli
