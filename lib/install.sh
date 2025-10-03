#!/usr/bin/env bash
# Cross-platform installation script
# Works on both macOS and Linux
# Can install base system, dev tools, optional packages, or custom selection

set -e  # Exit on error

# Get script directory (parent of lib/)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Source OS detection utilities
source "$SCRIPT_DIR/lib/os-detect.sh"
source "$SCRIPT_DIR/lib/package-install.sh"
source "$SCRIPT_DIR/lib/fonts.sh"

# Base packages (hardcoded)
BASE_PACKAGES_LINUX=(
    locales
    yq
    git
    curl
    stow
    xz-utils
    fontconfig
    gnupg
)

BASE_PACKAGES_MAC=(
    yq
    git
    curl
    stow
)

# Parse arguments
INSTALL_BASE=false
CUSTOM_PACKAGES=()

while [[ $# -gt 0 ]]; do
    case $1 in
        --base)
            INSTALL_BASE=true
            shift
            ;;
        --packages)
            shift
            while [[ $# -gt 0 ]] && [[ ! "$1" =~ ^-- ]]; do
                CUSTOM_PACKAGES+=("$1")
                shift
            done
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Print OS information
print_os_info

# Check if OS is supported
check_supported_os

# Update package repositories
if [[ "$OS" == "linux" ]]; then
    echo -e "${BLUE}Updating package repositories...${NC}"
    update_package_repos
fi

# Base installation
if [ "$INSTALL_BASE" = true ]; then
    echo -e "${BLUE}=== Base Installation ===${NC}"

    # Install base tools FIRST (needed for fonts and other steps)
    echo -e "${BLUE}Installing base tools...${NC}"
    
    if [[ "$OS" == "linux" ]]; then
        install_packages "${BASE_PACKAGES_LINUX[@]}"
    elif [[ "$OS" == "macos" ]]; then
        install_packages "${BASE_PACKAGES_MAC[@]}"
    else
        echo -e "${RED}Error: Unsupported operating system${NC}"
        exit 1
    fi

    echo -e "${GREEN}✓ Base tools installed${NC}"
    echo ""

    # Install Nerd Fonts
    echo -e "${BLUE}Installing Nerd Fonts...${NC}"
    install_nerd_font "FiraCode"
    echo ""

    # Install Nix (single-user install, cross-platform)
    if ! command -v nix &> /dev/null; then
        echo -e "${BLUE}Installing Nix package manager...${NC}"
        if sh <(curl -L https://nixos.org/nix/install) --no-daemon 2>/dev/null; then
            echo -e "${GREEN}✓ Nix installed${NC}"
        else
            echo -e "${YELLOW}⚠ Nix installation failed (skipping)${NC}"
        fi
    else
        echo -e "${GREEN}✓ Nix already installed${NC}"
    fi

    echo ""
    echo -e "${GREEN}=== Base installation complete ===${NC}"
fi

# Custom packages installation
if [ ${#CUSTOM_PACKAGES[@]} -gt 0 ]; then
    echo -e "${BLUE}=== Custom Packages Installation ===${NC}"

    # Load package mappings
    load_package_mappings "$SCRIPT_DIR/packages.yaml"

    install_packages "${CUSTOM_PACKAGES[@]}"

    # Special install script required for kubecolor on Linux
    if [[ "$OS" == "linux" ]] && grep -q "kubecolor" "$SCRIPT_DIR/config.yaml"; then
        install_kubecolor
    fi

    echo -e "${GREEN}=== Custom Packages Installation complete ===${NC}"
fi

