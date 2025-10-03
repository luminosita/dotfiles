#!/usr/bin/env bash
# Bootstrap script - Master installation orchestrator
# Cross-platform: Works on both macOS and Linux

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Header
echo -e "${BLUE}"
echo "╔════════════════════════════════════════════╗"
echo "║   Cross-Platform Dotfiles Bootstrap       ║"
echo "║   macOS & Linux Compatible                 ║"
echo "╚════════════════════════════════════════════╝"
echo -e "${NC}"

# Check if running on supported OS
if [[ "$OSTYPE" == "darwin"* ]]; then
    OS="macOS"
    DEFAULT_SHELL="zsh"
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    OS="Linux"
    DEFAULT_SHELL="bash"
else
    echo -e "${RED}Error: Unsupported operating system${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Detected OS: $OS${NC}"
echo -e "${GREEN}✓ Default shell: $DEFAULT_SHELL${NC}"
echo ""

if [[ $EUID -eq 0 ]]; then
    echo -e "${RED}✗ Script cannot be run as root${NC}"
    exit 1
fi

# Check for package manager
if [[ "$OS" == "macOS" ]]; then
    if [[! -d "$HOME/homebrew"]]; then
        echo -e "${YELLOW}✗ Homebrew not found${NC}"
        MISSING_BREW=true
    else
        echo -e "${GREEN}✓ Homebrew installed${NC}"
    fi
elif [[ "$OS" == "Linux" ]]; then
    if ! command -v sudo &> /dev/null; then
        echo -e "${RED}✗ Sudo not found${NC}"
        echo -e "${RED}Please install and configure sudo first${NC}"
        exit 1
    fi

    PKG_MGR_FOUND=false
    if command -v apt-get &> /dev/null; then
        echo -e "${GREEN}✓ apt package manager found${NC}"
        PKG_MGR_FOUND=true
    elif command -v dnf &> /dev/null; then
        echo -e "${GREEN}✓ dnf package manager found${NC}"
        PKG_MGR_FOUND=true
    elif command -v pacman &> /dev/null; then
        echo -e "${GREEN}✓ pacman package manager found${NC}"
        PKG_MGR_FOUND=true
    fi

    if [ "$PKG_MGR_FOUND" = false ]; then
        echo -e "${RED}✗ No supported package manager found (apt/dnf/pacman)${NC}"
        echo -e "${RED}Please install a supported package manager first${NC}"
        exit 1
    fi
fi

# Install Homebrew if needed on macOS
if [ "$MISSING_BREW" = true ]; then
    echo ""
    echo -e "${BLUE}Installing Homebrew (local user installation)...${NC}"

    # Install Homebrew locally in ~/homebrew
    mkdir -p ~/homebrew
    curl -L https://github.com/Homebrew/brew/tarball/master | tar xz --strip 1 -C ~/homebrew

    echo -e "${GREEN}✓ Homebrew installed (local user installation in ~/homebrew)${NC}"
fi

if [[ "$OS" == "macOS" ]]; then
    # Add Homebrew to PATH for this session
    export PATH="$HOME/homebrew/bin:$PATH"
    export MANPATH="$HOME/homebrew/share/man:$MANPATH"
    export INFOPATH="$HOME/homebrew/share/info:$INFOPATH"
    export HOMEBREW_PREFIX="$HOME/homebrew"
    export HOMEBREW_REPOSITORY="$HOME/homebrew"
    export HOMEBREW_CACHE="$HOME/.cache/homebrew"
    export HOMEBREW_TEMP="$HOME/tmp/homebrew"
    export HOMEBREW_LOGS="$HOME/.cache/homebrew/Logs"

    mkdir -p "$HOMEBREW_CACHE" "$HOMEBREW_TEMP" "$HOMEBREW_LOGS"
    brew analytics off
fi

required_major=4
required_minor=3

# Extract major and minor version from $BASH_VERSION
current_major=$(echo "$BASH_VERSION" | cut -d'.' -f1)
current_minor=$(echo "$BASH_VERSION" | cut -d'.' -f2)

if (( current_major > required_major )) || \
   (( current_major == required_major && current_minor >= required_minor )); then
    echo -e "${GREEN}✓ Bash version $BASH_VERSION meets or exceeds the required version ($required_major.$required_minor)${NC}"
else
    echo -e "${RED}Bash version $BASH_VERSION is older than the required version ($required_major.$required_minor)${NC}"
    if [[ "$OS" == "macOS" ]]; then
        echo ""
        echo -e "${BLUE}=== Bash Upgrade ===${NC}"
        echo ""
        read -p "Upgrade Bash shell now? [Y/n]: " install_base
        if [[ ! "$install_base" =~ ^[Nn] ]]; then
            brew install bash
            ln -s "$HOMEBREW_REPOSITORY/bin/bash" /usr/local/bin/bash
            echo -e "${GREEN}=== Bash Upgrade Complete ===${NC}"
            echo -e "${YELLOW}Please restart the bootstrap script${NC}"
        else
            echo -e "${RED}Cannot proceed without required packages${NC}"
        fi
    fi
    exit 1
fi

echo ""
echo -e "${BLUE}=== Base Installation ===${NC}"
echo -e "${YELLOW}This will install: fonts, zinit, nix, git, curl, stow, xz-utils, fontconfig, gnupg${NC}"
echo ""
read -p "Install base packages now? [Y/n]: " install_base

if [[ ! "$install_base" =~ ^[Nn] ]]; then
    bash "$SCRIPT_DIR/lib/install.sh" --base
else
    echo -e "${RED}Cannot proceed without required packages${NC}"
    exit 1
fi

# Continue with installation options
echo ""
echo -e "${BLUE}╔════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   Additional Installation Options         ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${GREEN}✓ Detected OS: $OS${NC}"
echo -e "${GREEN}✓ Default shell: $DEFAULT_SHELL${NC}"
echo ""

#TODO: mapfile requires Bash 4+
# Load package lists from config.yaml
mapfile -t DEV_PACKAGES < <(yq -r '.dev.packages[]' "$SCRIPT_DIR/config.yaml")
mapfile -t OPTIONAL_PACKAGES < <(yq -r '.optional.packages[]' "$SCRIPT_DIR/config.yaml")
mapfile -t DEV_CASKS < <(yq -r '.dev.macos_casks[]' "$SCRIPT_DIR/config.yaml")
mapfile -t OPTIONAL_CASKS < <(yq -r '.optional.macos_casks[]' "$SCRIPT_DIR/config.yaml")
mapfile -t VSCODE_EXTENSIONS < <(yq -r '.vscode.extensions[]' "$SCRIPT_DIR/config.yaml")

# Prompt for installation options
echo -e "${BLUE}What would you like to install?${NC}"
echo "1) Full installation (base + dev tools + optional)"
echo "2) Base installation only"
echo "3) Base + dev tools"
echo "4) Custom package selection"
echo ""
read -p "Enter your choice [1-4]: " choice_num

case "$choice_num" in
    1) choice="Full installation (base + dev tools + optional)" ;;
    2) choice="Base installation only" ;;
    3) choice="Base + dev tools" ;;
    4) choice="Custom package selection" ;;
    *) echo -e "${RED}Invalid choice${NC}"; exit 1 ;;
esac

case "$choice" in
    "Full installation (base + dev tools + optional)")
        INSTALL_DEV=true
        INSTALL_OPTIONAL=true
        INSTALL_VSCODE=true
        INSTALL_CLAUDE_CODE=true
        CUSTOM_PACKAGES=()
        ;;
    "Base installation only")
        INSTALL_DEV=false
        INSTALL_OPTIONAL=false
        INSTALL_VSCODE=false
        INSTALL_CLAUDE_CODE=false
        CUSTOM_PACKAGES=()
        ;;
    "Base + dev tools")
        INSTALL_DEV=true
        INSTALL_OPTIONAL=false
        INSTALL_VSCODE=true
        INSTALL_CLAUDE_CODE=true
        CUSTOM_PACKAGES=()
        ;;
    "Custom package selection")
        # Show dev packages and ask
        echo ""
        echo -e "${BLUE}Development packages:${NC}"
        printf '%s\n' "${DEV_PACKAGES[@]}"
        echo ""
        read -p "Install all development packages? [Y/n]: " install_dev
        INSTALL_DEV=$([ "$install_dev" != "n" ] && [ "$install_dev" != "N" ] && echo true || echo false)

        # Show optional packages and ask
        echo ""
        echo -e "${BLUE}Optional packages:${NC}"
        printf '%s\n' "${OPTIONAL_PACKAGES[@]}"
        echo ""
        read -p "Install all optional packages? [Y/n]: " install_opt
        INSTALL_OPTIONAL=$([ "$install_opt" != "n" ] && [ "$install_opt" != "N" ] && echo true || echo false)

        echo ""
        read -p "Install Visual Studio Code? [Y/n]: " install_vscode
        INSTALL_VSCODE=$([ "$install_vscode" != "n" ] && [ "$install_vscode" != "N" ] && echo true || echo false)

        read -p "Install Claude Code? [Y/n]: " install_claude
        INSTALL_CLAUDE_CODE=$([ "$install_claude" != "n" ] && [ "$install_claude" != "N" ] && echo true || echo false)

        CUSTOM_PACKAGES=()
        ;;
esac

echo ""

# Display installation summary
echo ""
echo -e "${BLUE}=== Installation Summary ===${NC}"
[ "$INSTALL_VSCODE" = true ] && echo -e "${GREEN}✓ Visual Studio Code + extensions${NC}" || echo -e "${YELLOW}✗ Visual Studio Code${NC}"
[ "$INSTALL_CLAUDE_CODE" = true ] && echo -e "${GREEN}✓ Claude Code${NC}" || echo -e "${YELLOW}✗ Claude Code${NC}"

if [ "$INSTALL_DEV" = true ]; then
    echo -e "${GREEN}✓ Dev tools (${DEV_PACKAGES[*]})${NC}"
fi
if [ "$INSTALL_OPTIONAL" = true ]; then
    echo -e "${GREEN}✓ Optional packages (${OPTIONAL_PACKAGES[*]})${NC}"
fi
if [ ${#CUSTOM_PACKAGES[@]} -gt 0 ]; then
    echo -e "${GREEN}✓ Custom packages (${CUSTOM_PACKAGES[*]})${NC}"
fi

echo ""
read -p "Proceed with installation? [Y/n]: " proceed

if [[ "$proceed" =~ ^[Nn] ]]; then
    echo -e "${YELLOW}Installation cancelled${NC}"
    exit 0
fi

echo ""
echo -e "${BLUE}Starting installation...${NC}"

# Build combined package list based on selections
ALL_PACKAGES=()
ALL_CASKS=()

if [ "$INSTALL_DEV" = true ]; then
    ALL_PACKAGES+=("${DEV_PACKAGES[@]}")
    if [[ "$OS" == "macOS" ]]; then
        ALL_CASKS+=("${DEV_CASKS[@]}")
    fi
fi

if [ "$INSTALL_OPTIONAL" = true ]; then
    ALL_PACKAGES+=("${OPTIONAL_PACKAGES[@]}")
    if [[ "$OS" == "macOS" ]]; then
        ALL_CASKS+=("${OPTIONAL_CASKS[@]}")
    fi
fi

if [ ${#CUSTOM_PACKAGES[@]} -gt 0 ]; then
    ALL_PACKAGES+=("${CUSTOM_PACKAGES[@]}")
fi

# Build install.sh arguments
INSTALL_ARGS=()
[ ${#ALL_PACKAGES[@]} -gt 0 ] && INSTALL_ARGS+=("--packages" "${ALL_PACKAGES[@]}")

# Run unified installation script
if [ ${#INSTALL_ARGS[@]} -gt 0 ]; then
    echo -e "${BLUE}▶ Running installation...${NC}"
    bash "$SCRIPT_DIR/lib/install.sh" "${INSTALL_ARGS[@]}"
fi

# Install macOS casks if any
if [[ "$OS" == "macOS" ]] && [ ${#ALL_CASKS[@]} -gt 0 ]; then
    echo -e "${BLUE}▶ Installing macOS applications...${NC}"

    # Install Zinit plugin manager
    if [[ ! -d "$HOME/.local/share/zinit/zinit.git" ]]; then
        echo -e "${BLUE}Installing Zinit plugin manager...${NC}"
        bash -c "$(curl --fail --show-error --silent \
            --location https://raw.githubusercontent.com/zdharma-continuum/zinit/HEAD/scripts/install.sh)"
        echo -e "${GREEN}✓ Zinit installed${NC}"
    else
        echo -e "${GREEN}✓ Zinit already installed${NC}"
    fi

    for cask in "${ALL_CASKS[@]}"; do
        brew install --cask "$cask" || echo -e "${YELLOW}Warning: Failed to install cask $cask${NC}"
    done
fi

# Install VS Code if selected
if [[ "$INSTALL_VSCODE" == true ]]; then
    if [[ "$OS" == "macOS" ]]; then
        echo -e "${BLUE}▶ Installing Visual Studio Code...${NC}"
        brew install --cask visual-studio-code || echo -e "${YELLOW}Warning: Failed to install VS Code${NC}"
    elif [[ "$OS" == "Linux" ]] && ! command -v code &> /dev/null; then
        # Source os-detect to get package manager
        source "$SCRIPT_DIR/lib/os-detect.sh"

        if [[ "$PKG_MGR" == "apt" ]]; then
            echo -e "${BLUE}▶ Installing Visual Studio Code on Linux...${NC}"
            wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
            sudo install -D -o root -g root -m 644 packages.microsoft.gpg /etc/apt/keyrings/packages.microsoft.gpg
            sudo sh -c 'echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list'
            rm -f packages.microsoft.gpg
            sudo apt-get update
            sudo apt-get install -y code
            echo -e "${GREEN}✓ VS Code installed${NC}"
        fi
    fi

    # Install VS Code extensions if VS Code is now available
    if command -v code &> /dev/null; then
        echo -e "${BLUE}▶ Installing VS Code extensions...${NC}"
        for ext in "${VSCODE_EXTENSIONS[@]}"; do
            code --install-extension "$ext"
        done
        echo -e "${GREEN}✓ VS Code extensions installed${NC}"
    fi
fi

# Install Claude Code if selected
if [[ "$INSTALL_CLAUDE_CODE" == true ]]; then
    if [[ "$OS" == "macOS" ]]; then
        CLAUDE_CASK=$(yq -r '.claude_code.macos_cask' "$SCRIPT_DIR/config.yaml")
        echo -e "${BLUE}▶ Installing Claude Code...${NC}"
        brew install --cask "$CLAUDE_CASK" || echo -e "${YELLOW}Warning: Failed to install Claude Code${NC}"
    else
        echo -e "${BLUE}▶ Installing Claude Code...${NC}"
        curl -fsSL https://claude.ai/install.sh | bash -s latest
    fi
fi

# Ask about sync
echo ""
echo -e "${BLUE}=== Git Configuration ===${NC}"
read -p "Configure git and sync dotfiles now? [Y/n]: " sync_now

if [[ ! "$sync_now" =~ ^[Nn] ]]; then
    bash "$SCRIPT_DIR/lib/sync.sh"
fi

# Ask about default shell
echo ""
echo -e "${BLUE}=== Shell Configuration ===${NC}"

if [[ "$OS" == "macOS" ]]; then
    current_shell=$(dscl . -read ~/ UserShell | sed 's/UserShell: //')
    if [[ "$current_shell" != *"zsh"* ]]; then
        read -p "Set zsh as default shell? [Y/n]: " set_shell
        if [[ ! "$set_shell" =~ ^[Nn] ]]; then
            sudo chsh -s $(which zsh)
            echo -e "${GREEN}✓ Default shell set to zsh${NC}"
        fi
    else
        echo -e "${GREEN}✓ zsh is already the default shell${NC}"
    fi
elif [[ "$OS" == "Linux" ]]; then
    current_shell=$(getent passwd $USER | cut -d: -f7)
    if [[ "$current_shell" != *"bash"* ]]; then
        read -p "Set bash as default shell? [Y/n]: " set_shell
        if [[ ! "$set_shell" =~ ^[Nn] ]]; then
            sudo chsh -s $(which bash)
            echo -e "${GREEN}✓ Default shell set to bash${NC}"
        fi
    else
        echo -e "${GREEN}✓ bash is already the default shell${NC}"
    fi
fi

echo ""
echo -e "${GREEN}"
echo "╔════════════════════════════════════════════╗"
echo "║         Bootstrap Complete! 🎉             ║"
echo "╚════════════════════════════════════════════╝"
echo -e "${NC}"

echo ""
echo -e "${BLUE}Next Steps:${NC}"
if [[ "$OS" == "macOS" ]]; then
    echo "1. Restart your terminal or run: source ~/.zshrc"
else
    echo "1. Restart your terminal or run: source ~/.bashrc"
fi
echo "2. Configure VS Code to use Fira Code font"
echo "3. Verify all tools are working correctly"
echo ""
echo -e "${YELLOW}⚠ Note: Some changes may require a system restart${NC}"
