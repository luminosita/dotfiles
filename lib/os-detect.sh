#!/usr/bin/env bash
# OS Detection and Package Manager Utilities
# Source this file to get OS-specific variables and functions

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Detect operating system
detect_os() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        OS="macos"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        OS="linux"
    else
        OS="unknown"
    fi
    export OS
}

# Detect Linux distribution
detect_distro() {
    if [[ "$OS" != "linux" ]]; then
        DISTRO="none"
        export DISTRO
        return
    fi

    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        DISTRO="$ID"
    elif [[ -f /etc/lsb-release ]]; then
        . /etc/lsb-release
        DISTRO="$DISTRIB_ID"
    else
        DISTRO="unknown"
    fi

    # Normalize distro names
    DISTRO=$(echo "$DISTRO" | tr '[:upper:]' '[:lower:]')
    export DISTRO
}

# Detect package manager
detect_package_manager() {
    if [[ "$OS" == "macos" ]]; then
        PKG_MGR="brew"
    elif [[ "$OS" == "linux" ]]; then
        if command -v apt-get &> /dev/null; then
            PKG_MGR="apt"
        elif command -v dnf &> /dev/null; then
            PKG_MGR="dnf"
        elif command -v yum &> /dev/null; then
            PKG_MGR="yum"
        elif command -v pacman &> /dev/null; then
            PKG_MGR="pacman"
        elif command -v zypper &> /dev/null; then
            PKG_MGR="zypper"
        else
            PKG_MGR="unknown"
        fi
    else
        PKG_MGR="unknown"
    fi
    export PKG_MGR
}

# Set OS-specific paths
set_os_paths() {
    if [[ "$OS" == "macos" ]]; then
        # macOS paths
        FONT_DIR="$HOME/Library/Fonts"
        SHELL_RC="$HOME/.zshrc"
        DEFAULT_SHELL="zsh"
    elif [[ "$OS" == "linux" ]]; then
        # Linux paths
        FONT_DIR="$HOME/.local/share/fonts"
        SHELL_RC="$HOME/.bashrc"
        DEFAULT_SHELL="bash"
    fi

    export FONT_DIR
    export SHELL_RC
    export DEFAULT_SHELL
}

# Get package manager update command
pkg_update_cmd() {
    case "$PKG_MGR" in
        apt)
            echo "sudo apt-get update"
            ;;
        dnf|yum)
            echo "sudo $PKG_MGR check-update || true"
            ;;
        pacman)
            echo "sudo pacman -Sy"
            ;;
        zypper)
            echo "sudo zypper refresh"
            ;;
        brew)
            echo "brew update"
            ;;
        *)
            echo "echo 'Unknown package manager'"
            ;;
    esac
}

# Get package manager install command (without package names)
pkg_install_cmd() {
    case "$PKG_MGR" in
        apt)
            echo "sudo apt-get install -y"
            ;;
        dnf|yum)
            echo "sudo $PKG_MGR install -y"
            ;;
        pacman)
            echo "sudo pacman -S --noconfirm"
            ;;
        zypper)
            echo "sudo zypper install -y"
            ;;
        brew)
            echo "brew install"
            ;;
        *)
            echo "echo 'Unknown package manager, cannot install:'"
            ;;
    esac
}

# Print OS information
print_os_info() {
    echo -e "${BLUE}=== System Information ===${NC}"
    echo -e "OS: ${GREEN}$OS${NC}"
    if [[ "$OS" == "linux" ]]; then
        echo -e "Distribution: ${GREEN}$DISTRO${NC}"
    fi
    echo -e "Package Manager: ${GREEN}$PKG_MGR${NC}"
    echo -e "Default Shell: ${GREEN}$DEFAULT_SHELL${NC}"
    echo -e "Font Directory: ${GREEN}$FONT_DIR${NC}"
    echo -e "Shell RC File: ${GREEN}$SHELL_RC${NC}"
    echo ""
}

# Check if running on supported OS
check_supported_os() {
    if [[ "$OS" == "unknown" ]]; then
        echo -e "${RED}Error: Unsupported operating system${NC}"
        exit 1
    fi

    if [[ "$OS" == "linux" ]] && [[ "$PKG_MGR" == "unknown" ]]; then
        echo -e "${RED}Error: Could not detect package manager${NC}"
        exit 1
    fi
}

# Initialize - run all detection functions
init_os_detection() {
    detect_os
    detect_distro
    detect_package_manager
    set_os_paths
}

# Run initialization when sourced
init_os_detection
