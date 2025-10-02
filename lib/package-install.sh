#!/usr/bin/env bash
# Cross-platform package installation utilities
# Requires: lib/os-detect.sh to be sourced first

# Source os-detect if not already loaded
if [[ -z "$OS" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    source "$SCRIPT_DIR/os-detect.sh"
fi

# Load package mappings from YAML file
load_package_mappings() {
    local yaml_file="$1"

    if [[ ! -f "$yaml_file" ]]; then
        echo -e "${RED}Error: Package mappings file not found: $yaml_file${NC}"
        return 1
    fi

    # Check if yq is available
    if ! command -v yq &> /dev/null; then
        echo -e "${YELLOW}Warning: yq not found. Install it for package mapping support${NC}"
        return 1
    fi

    export PACKAGE_MAPPINGS_FILE="$yaml_file"
}

# Get platform-specific package name
get_package_name() {
    local common_name="$1"
    local pkg_name="$common_name"

    # Only use package mappings if file is set and yq is available
    if [[ -n "$PACKAGE_MAPPINGS_FILE" ]] && [[ -f "$PACKAGE_MAPPINGS_FILE" ]] && command -v yq &> /dev/null; then
        # Try to get OS-specific package name
        local mapped_name

        if [[ "$OS" == "macos" ]]; then
            mapped_name=$(yq -r ".packages[] | select(.name == \"$common_name\") | .brew // empty" "$PACKAGE_MAPPINGS_FILE" 2>/dev/null)
        elif [[ "$OS" == "linux" ]]; then
            case "$PKG_MGR" in
                apt)
                    mapped_name=$(yq -r ".packages[] | select(.name == \"$common_name\") | .apt // empty" "$PACKAGE_MAPPINGS_FILE" 2>/dev/null)
                    ;;
                dnf|yum)
                    mapped_name=$(yq -r ".packages[] | select(.name == \"$common_name\") | .dnf // empty" "$PACKAGE_MAPPINGS_FILE" 2>/dev/null)
                    ;;
                pacman)
                    mapped_name=$(yq -r ".packages[] | select(.name == \"$common_name\") | .pacman // empty" "$PACKAGE_MAPPINGS_FILE" 2>/dev/null)
                    ;;
            esac
        fi

        # Use mapped name if found and not empty, otherwise use common name
        if [[ -n "$mapped_name" ]]; then
            pkg_name="$mapped_name"
        fi
    fi
    # If PACKAGE_MAPPINGS_FILE is not set or yq not available, just use common_name

    echo "$pkg_name"
}

# Check if package is available for current platform
is_package_available() {
    local common_name="$1"

    # If no package mappings file, assume package is available
    if [[ -z "$PACKAGE_MAPPINGS_FILE" ]] || [[ ! -f "$PACKAGE_MAPPINGS_FILE" ]] || ! command -v yq &> /dev/null; then
        return 0
    fi

    local platform_key

    if [[ "$OS" == "macos" ]]; then
        platform_key="brew"
    elif [[ "$OS" == "linux" ]]; then
        case "$PKG_MGR" in
            apt) platform_key="apt" ;;
            dnf|yum) platform_key="dnf" ;;
            pacman) platform_key="pacman" ;;
            *) return 0 ;;  # If unknown package manager, assume available
        esac
    fi

    local has_package=$(yq -r ".packages[] | select(.name == \"$common_name\") | .$platform_key // \"skip\"" "$PACKAGE_MAPPINGS_FILE" 2>/dev/null)

    if [[ "$has_package" == "skip" ]]; then
        return 1
    fi

    return 0
}

# Install a single package
install_package() {
    local common_name="$1"

    # Check if package is available for this platform
    if ! is_package_available "$common_name"; then
        echo -e "${YELLOW}Skipping $common_name (not available on $OS/$PKG_MGR)${NC}"
        return 0
    fi

    local pkg_name=$(get_package_name "$common_name")
    local install_cmd=$(pkg_install_cmd)

    echo -e "${BLUE}Installing: $pkg_name${NC}"

    if eval "$install_cmd $pkg_name"; then
        echo -e "${GREEN}✓ Installed: $pkg_name${NC}"
        return 0
    else
        echo -e "${RED}✗ Failed to install: $pkg_name${NC}"
        return 1
    fi
}

# Install multiple packages
install_packages() {
    local packages=("$@")
    local failed=()

    echo -e "${BLUE}=== Installing ${#packages[@]} packages ===${NC}"

    for pkg in "${packages[@]}"; do
        if ! install_package "$pkg"; then
            failed+=("$pkg")
        fi
    done

    if [[ ${#failed[@]} -gt 0 ]]; then
        echo -e "${YELLOW}Failed to install ${#failed[@]} packages:${NC}"
        printf '%s\n' "${failed[@]}"
        return 1
    else
        echo -e "${GREEN}All packages installed successfully${NC}"
        return 0
    fi
}

# Install cask (macOS only)
install_cask() {
    local cask_name="$1"

    if [[ "$OS" != "macos" ]]; then
        echo -e "${YELLOW}Skipping cask $cask_name (macOS only)${NC}"
        return 0
    fi

    echo -e "${BLUE}Installing cask: $cask_name${NC}"

    if brew install --cask "$cask_name"; then
        echo -e "${GREEN}✓ Installed cask: $cask_name${NC}"
        return 0
    else
        echo -e "${RED}✗ Failed to install cask: $cask_name${NC}"
        return 1
    fi
}

# Install from Brewfile (macOS) or equivalent packages (Linux)
install_from_brewfile() {
    local brewfile="$1"

    if [[ ! -f "$brewfile" ]]; then
        echo -e "${RED}Error: Brewfile not found: $brewfile${NC}"
        return 1
    fi

    if [[ "$OS" == "macos" ]]; then
        echo -e "${BLUE}Installing from Brewfile: $brewfile${NC}"
        brew bundle --file="$brewfile"
    else
        # Parse Brewfile and install Linux equivalents
        echo -e "${BLUE}Installing packages from $brewfile (Linux mode)${NC}"

        while IFS= read -r line; do
            # Skip comments and empty lines
            [[ "$line" =~ ^[[:space:]]*# ]] && continue
            [[ -z "${line// }" ]] && continue

            # Extract package/cask names
            if [[ "$line" =~ ^brew[[:space:]]+\"([^\"]+)\" ]]; then
                local pkg="${BASH_REMATCH[1]}"
                install_package "$pkg"
            elif [[ "$line" =~ ^cask[[:space:]]+\"([^\"]+)\" ]]; then
                # Skip casks on Linux (GUI apps)
                echo -e "${YELLOW}Skipping cask ${BASH_REMATCH[1]} (macOS only)${NC}"
            fi
        done < "$brewfile"
    fi
}

# Update package repositories
update_package_repos() {
    echo -e "${BLUE}Updating package repositories...${NC}"
    local update_cmd=$(pkg_update_cmd)

    if eval "$update_cmd"; then
        echo -e "${GREEN}✓ Package repositories updated${NC}"
        return 0
    else
        echo -e "${RED}✗ Failed to update package repositories${NC}"
        return 1
    fi
}

# Check if a command/package is installed
is_installed() {
    command -v "$1" &> /dev/null
}

# Install package only if not already installed
install_if_missing() {
    local pkg="$1"
    local cmd="${2:-$pkg}"  # Command name (defaults to package name)

    if is_installed "$cmd"; then
        echo -e "${GREEN}✓ $pkg already installed${NC}"
        return 0
    else
        install_package "$pkg"
    fi
}
