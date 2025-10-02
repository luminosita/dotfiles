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

# Load package mappings
load_package_mappings "$SCRIPT_DIR/packages.yaml"

# Update package repositories
if [[ "$OS" == "linux" ]]; then
    echo -e "${BLUE}Updating package repositories...${NC}"
    update_package_repos
fi

# Base installation
if [ "$INSTALL_BASE" = true ]; then
    echo -e "${BLUE}=== Base Installation ===${NC}"

    # Install Nerd Fonts
    echo -e "${BLUE}Installing Nerd Fonts...${NC}"
    install_nerd_font "FiraCode"

    # Install Nix (single-user install, cross-platform)
    if ! command -v nix &> /dev/null; then
        echo -e "${BLUE}Installing Nix package manager...${NC}"
        echo -e "${YELLOW}Add --yes to skip prompts if needed${NC}"
        sh <(curl -L https://nixos.org/nix/install) --no-daemon
        echo -e "${GREEN}✓ Nix installed${NC}"
    else
        echo -e "${GREEN}✓ Nix already installed${NC}"
    fi

    # Install base tools from config.yaml
    echo -e "${BLUE}Installing base tools...${NC}"

    # Load base packages from config.yaml
    mapfile -t BASE_PACKAGES < <(yq -r '.base.packages[]' "$SCRIPT_DIR/config.yaml")
    install_packages "${BASE_PACKAGES[@]}"

    echo -e "${GREEN}=== Base installation complete ===${NC}"
fi

# Custom packages installation
if [ ${#CUSTOM_PACKAGES[@]} -gt 0 ]; then
    echo -e "${BLUE}=== Custom Packages Installation ===${NC}"
    install_packages "${CUSTOM_PACKAGES[@]}"
    echo -e "${GREEN}=== Custom Packages Installation complete ===${NC}"
fi

