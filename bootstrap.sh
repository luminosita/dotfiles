#!/usr/bin/env bash
# Bootstrap script - Master installation orchestrator
# Cross-platform: Works on both macOS and Linux

set -e

# Colors (for initial setup before gum is available)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Initial header (before gum)
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
    REQUIRED_PKG_MGR="brew"
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    OS="Linux"
    DEFAULT_SHELL="bash"
    REQUIRED_PKG_MGR="apt/dnf/pacman"
else
    echo -e "${RED}Error: Unsupported operating system${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Detected OS: $OS${NC}"
echo -e "${GREEN}✓ Default shell: $DEFAULT_SHELL${NC}"
echo ""

# Check for required dependencies
echo -e "${BLUE}=== Checking Requirements ===${NC}"
MISSING_DEPS=()

# Check for curl
if ! command -v curl &> /dev/null; then
    echo -e "${YELLOW}✗ curl not found${NC}"
    MISSING_DEPS+=("curl")
else
    echo -e "${GREEN}✓ curl installed${NC}"
fi

# Check for gum
if ! command -v gum &> /dev/null; then
    echo -e "${YELLOW}✗ gum not found${NC}"
    MISSING_DEPS+=("gum")
else
    echo -e "${GREEN}✓ gum installed${NC}"
fi

# Check for yq
if ! command -v yq &> /dev/null; then
    echo -e "${YELLOW}✗ yq not found${NC}"
    MISSING_DEPS+=("yq")
else
    echo -e "${GREEN}✓ yq installed${NC}"
fi

# Check for package manager
if [[ "$OS" == "macOS" ]]; then
    if ! command -v brew &> /dev/null; then
        echo -e "${YELLOW}✗ Homebrew not found${NC}"
        MISSING_DEPS+=("brew")
    else
        echo -e "${GREEN}✓ Homebrew installed${NC}"
    fi
elif [[ "$OS" == "Linux" ]]; then
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

# Install missing dependencies if needed
if [ ${#MISSING_DEPS[@]} -gt 0 ]; then
    echo ""
    echo -e "${YELLOW}Missing required dependencies: ${MISSING_DEPS[*]}${NC}"
    echo ""
    read -p "Install missing dependencies now? [Y/n]: " install_deps

    if [[ ! "$install_deps" =~ ^[Nn] ]]; then
        for dep in "${MISSING_DEPS[@]}"; do
            case "$dep" in
                curl)
                    echo -e "${BLUE}Installing curl...${NC}"
                    if [[ "$OS" == "macOS" ]]; then
                        # curl should be pre-installed on macOS
                        echo -e "${RED}Error: curl is missing on macOS (should be pre-installed)${NC}"
                        exit 1
                    elif [[ "$OS" == "Linux" ]]; then
                        if command -v apt-get &> /dev/null; then
                            sudo apt-get update && sudo apt-get install -y curl
                        elif command -v dnf &> /dev/null; then
                            sudo dnf install -y curl
                        elif command -v pacman &> /dev/null; then
                            sudo pacman -S --noconfirm curl
                        fi
                    fi
                    echo -e "${GREEN}✓ curl installed${NC}"
                    ;;
                brew)
                    echo -e "${BLUE}Installing Homebrew (local user installation)...${NC}"

                    # Install Homebrew locally in ~/homebrew
                    mkdir -p ~/homebrew
                    curl -L https://github.com/Homebrew/brew/tarball/master | tar xz --strip 1 -C ~/homebrew

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

                    echo -e "${GREEN}✓ Homebrew installed (local user installation in ~/homebrew)${NC}"
                    ;;
                yq)
                    echo -e "${BLUE}Installing yq...${NC}"
                    if [[ "$OS" == "macOS" ]]; then
                        brew install yq
                    elif [[ "$OS" == "Linux" ]]; then
                        if command -v apt-get &> /dev/null; then
                            sudo apt-get update && sudo apt-get install -y yq
                        elif command -v dnf &> /dev/null; then
                            sudo dnf install -y yq
                        elif command -v pacman &> /dev/null; then
                            sudo pacman -S --noconfirm yq
                        fi
                    fi
                    echo -e "${GREEN}✓ yq installed${NC}"
                    ;;
                gum)
                    echo -e "${BLUE}Installing gum...${NC}"
                    if [[ "$OS" == "macOS" ]]; then
                        brew install gum
                    elif [[ "$OS" == "Linux" ]]; then
                        if command -v apt-get &> /dev/null; then
                            sudo mkdir -p /etc/apt/keyrings
                            curl -fsSL https://repo.charm.sh/apt/gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/charm.gpg
                            echo "deb [signed-by=/etc/apt/keyrings/charm.gpg] https://repo.charm.sh/apt/ * *" | sudo tee /etc/apt/sources.list.d/charm.list
                            sudo apt-get update && sudo apt-get install -y gum
                        elif command -v dnf &> /dev/null; then
                            echo '[charm]
name=Charm
baseurl=https://repo.charm.sh/yum/
enabled=1
gpgcheck=1
gpgkey=https://repo.charm.sh/yum/gpg.key' | sudo tee /etc/yum.repos.d/charm.repo
                            sudo dnf install -y gum
                        elif command -v pacman &> /dev/null; then
                            sudo pacman -S --noconfirm gum
                        fi
                    fi
                    echo -e "${GREEN}✓ gum installed${NC}"
                    ;;
            esac
        done
        echo ""
        echo -e "${GREEN}All dependencies installed!${NC}"
        echo ""
    else
        echo -e "${RED}Cannot proceed without required dependencies${NC}"
        exit 1
    fi
fi

# Now use gum for everything from here on
gum style \
    --foreground 212 --border-foreground 212 --border double \
    --align center --width 50 --margin "1 2" --padding "1 2" \
    'Cross-Platform Dotfiles Bootstrap' 'macOS & Linux Compatible'

gum style --foreground 120 "✓ Detected OS: $OS"
gum style --foreground 120 "✓ Default shell: $DEFAULT_SHELL"
echo ""

# Load package lists from config.yaml
mapfile -t DEV_PACKAGES < <(yq -r '.dev.packages[]' "$SCRIPT_DIR/config.yaml")
mapfile -t OPTIONAL_PACKAGES < <(yq -r '.optional.packages[]' "$SCRIPT_DIR/config.yaml")
mapfile -t DEV_CASKS < <(yq -r '.dev.macos_casks[]' "$SCRIPT_DIR/config.yaml")
mapfile -t OPTIONAL_CASKS < <(yq -r '.optional.macos_casks[]' "$SCRIPT_DIR/config.yaml")
mapfile -t VSCODE_EXTENSIONS < <(yq -r '.vscode.extensions[]' "$SCRIPT_DIR/config.yaml")

# Prompt for installation options
gum style --foreground 75 --bold "What would you like to install?"
choice=$(gum choose \
    "Full installation (base + dev tools + optional)" \
    "Base installation only" \
    "Base + dev tools" \
    "Custom package selection")

case "$choice" in
    "Full installation (base + dev tools + optional)")
        INSTALL_BASE=true
        INSTALL_DEV=true
        INSTALL_OPTIONAL=true
        INSTALL_VSCODE=true
        INSTALL_CLAUDE_CODE=true
        CUSTOM_PACKAGES=()
        ;;
    "Base installation only")
        INSTALL_BASE=true
        INSTALL_DEV=false
        INSTALL_OPTIONAL=false
        INSTALL_VSCODE=false
        INSTALL_CLAUDE_CODE=false
        CUSTOM_PACKAGES=()
        ;;
    "Base + dev tools")
        INSTALL_BASE=true
        INSTALL_DEV=true
        INSTALL_OPTIONAL=false
        INSTALL_VSCODE=true
        INSTALL_CLAUDE_CODE=true
        CUSTOM_PACKAGES=()
        ;;
    "Custom package selection")
        INSTALL_BASE=$(gum confirm "Install base tools (fonts, zinit, nix, git, stow)?" && echo true || echo false)
        INSTALL_VSCODE=$(gum confirm "Install Visual Studio Code?" && echo true || echo false)
        INSTALL_CLAUDE_CODE=$(gum confirm "Install Claude Code?" && echo true || echo false)

        # Let user select from dev packages
        gum style --foreground 75 "Select development tools to install (space to select, enter to confirm):"
        SELECTED_DEV=$(gum choose --no-limit "${DEV_PACKAGES[@]}")

        # Let user select from optional packages
        gum style --foreground 75 "Select optional packages to install (space to select, enter to confirm):"
        SELECTED_OPT=$(gum choose --no-limit "${OPTIONAL_PACKAGES[@]}")

        # Combine selections
        CUSTOM_PACKAGES=()
        if [[ -n "$SELECTED_DEV" ]]; then
            while IFS= read -r pkg; do
                CUSTOM_PACKAGES+=("$pkg")
            done <<< "$SELECTED_DEV"
        fi
        if [[ -n "$SELECTED_OPT" ]]; then
            while IFS= read -r pkg; do
                CUSTOM_PACKAGES+=("$pkg")
            done <<< "$SELECTED_OPT"
        fi

        INSTALL_DEV=false
        INSTALL_OPTIONAL=false
        ;;
esac

echo ""

# Display installation summary
gum style --foreground 75 --bold "Installation Summary"
summary=""
[ "$INSTALL_BASE" = true ] && summary+="✓ Base installation (fonts, zinit, nix, git, stow, bitwarden-cli)\n" || summary+="✗ Base installation\n"
[ "$INSTALL_VSCODE" = true ] && summary+="✓ Visual Studio Code + extensions\n" || summary+="✗ Visual Studio Code\n"
[ "$INSTALL_CLAUDE_CODE" = true ] && summary+="✓ Claude Code\n" || summary+="✗ Claude Code\n"

if [ "$INSTALL_DEV" = true ]; then
    summary+="✓ Dev tools (${DEV_PACKAGES[*]})\n"
elif [ "$INSTALL_OPTIONAL" = true ]; then
    summary+="✓ Optional packages (${OPTIONAL_PACKAGES[*]})"
elif [ ${#CUSTOM_PACKAGES[@]} -gt 0 ]; then
    summary+="✓ Custom packages (${CUSTOM_PACKAGES[*]})\n"
else
    gum style --foreground 220 "No packages selected. Installation cancelled"
    exit 0
fi

echo -e "$summary" | gum format
echo ""

if ! gum confirm "Proceed with installation?"; then
    gum style --foreground 220 "Installation cancelled"
    exit 0
fi

echo ""
gum spin --spinner dot --title "Starting installation..." -- sleep 1

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
[ "$INSTALL_BASE" = true ] && INSTALL_ARGS+=("--base")
[ ${#ALL_PACKAGES[@]} -gt 0 ] && INSTALL_ARGS+=("--packages" "${ALL_PACKAGES[@]}")

# Run unified installation script
if [ ${#INSTALL_ARGS[@]} -gt 0 ]; then
    gum style --foreground 212 "▶ Running installation..."
    bash "$SCRIPT_DIR/lib/install.sh" "${INSTALL_ARGS[@]}"
fi

# Install macOS casks if any
if [[ "$OS" == "macOS" ]] && [ ${#ALL_CASKS[@]} -gt 0 ]; then
    gum style --foreground 212 "▶ Installing macOS applications..."
    for cask in "${ALL_CASKS[@]}"; do
        brew install --cask "$cask" || gum style --foreground 220 "Warning: Failed to install cask $cask"
    done
fi

# Install VS Code if selected
if [[ "$INSTALL_VSCODE" == true ]]; then
    if [[ "$OS" == "macOS" ]]; then
        gum style --foreground 212 "▶ Installing Visual Studio Code..."
        brew install --cask visual-studio-code || gum style --foreground 220 "Warning: Failed to install VS Code"
    elif [[ "$OS" == "Linux" ]] && ! command -v code &> /dev/null; then
        # Source os-detect to get package manager
        source "$SCRIPT_DIR/lib/os-detect.sh"

        if [[ "$PKG_MGR" == "apt" ]]; then
            gum style --foreground 212 "▶ Installing Visual Studio Code on Linux..."
            wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
            sudo install -D -o root -g root -m 644 packages.microsoft.gpg /etc/apt/keyrings/packages.microsoft.gpg
            sudo sh -c 'echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list'
            rm -f packages.microsoft.gpg
            sudo apt-get update
            sudo apt-get install -y code
            gum style --foreground 120 "✓ VS Code installed"
        fi
    fi

    # Install VS Code extensions if VS Code is now available
    if command -v code &> /dev/null; then
        gum style --foreground 212 "▶ Installing VS Code extensions..."
        for ext in "${VSCODE_EXTENSIONS[@]}"; do
            code --install-extension "$ext"
        done
        gum style --foreground 120 "✓ VS Code extensions installed"
    fi
fi

# Install Claude Code if selected
if [[ "$INSTALL_CLAUDE_CODE" == true ]]; then
    if [[ "$OS" == "macOS" ]]; then
        CLAUDE_CASK=$(yq -r '.claude_code.macos_cask' "$SCRIPT_DIR/config.yaml")
        gum style --foreground 212 "▶ Installing Claude Code..."
        brew install --cask "$CLAUDE_CASK" || gum style --foreground 220 "Warning: Failed to install Claude Code"
    else
        gum style --foreground 212 "▶ Installing Claude Code..."
        curl -fsSL https://claude.ai/install.sh | bash -s latest
    fi
fi

# Ask about sync
echo ""
if gum confirm "Configure git and sync dotfiles now?"; then
    bash "$SCRIPT_DIR/lib/sync.sh"
fi

# Ask about default shell
echo ""
gum style --foreground 75 --bold "Shell Configuration"

if [[ "$OS" == "macOS" ]]; then
    current_shell=$(dscl . -read ~/ UserShell | sed 's/UserShell: //')
    if [[ "$current_shell" != *"zsh"* ]]; then
        if gum confirm "Set zsh as default shell?"; then
            chsh -s $(which zsh)
            gum style --foreground 120 "✓ Default shell set to zsh"
        fi
    else
        gum style --foreground 120 "✓ zsh is already the default shell"
    fi
elif [[ "$OS" == "Linux" ]]; then
    current_shell=$(getent passwd $USER | cut -d: -f7)
    if [[ "$current_shell" != *"bash"* ]]; then
        if gum confirm "Set bash as default shell?"; then
            chsh -s $(which bash)
            gum style --foreground 120 "✓ Default shell set to bash"
        fi
    else
        gum style --foreground 120 "✓ bash is already the default shell"
    fi
fi

echo ""

# Display completion message
gum style \
    --foreground 120 --border-foreground 120 --border double \
    --align center --width 50 --margin "1 2" --padding "1 2" \
    'Bootstrap Complete! 🎉'

echo ""
gum style --foreground 75 --bold "Next Steps:"

next_steps=""
if [[ "$OS" == "macOS" ]]; then
    next_steps+="1. Restart your terminal or run: source ~/.zshrc\n"
else
    next_steps+="1. Restart your terminal or run: source ~/.bashrc\n"
fi
next_steps+="2. Configure VS Code to use Fira Code font\n"
next_steps+="3. Verify all tools are working correctly"

echo -e "$next_steps" | gum format
echo ""
gum style --foreground 220 "⚠ Note: Some changes may require a system restart"
