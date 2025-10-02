#!/usr/bin/env bash
# Cross-platform font installation utilities
# Requires: lib/os-detect.sh to be sourced first

# Source os-detect if not already loaded
if [[ -z "$OS" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    source "$SCRIPT_DIR/os-detect.sh"
fi

# Install Nerd Fonts
install_nerd_font() {
    local font_name="$1"  # e.g., "FiraCode", "Hack", "JetBrainsMono"
    local font_url="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/${font_name}.tar.xz"

    echo -e "${BLUE}Installing Nerd Font: $font_name${NC}"

    # Create font directory if it doesn't exist
    mkdir -p "$FONT_DIR"

    # Download and extract font
    if curl -sL "$font_url" | tar -xJf - -C "$FONT_DIR"; then
        echo -e "${GREEN}✓ Downloaded $font_name to $FONT_DIR${NC}"

        # Update font cache on Linux
        if [[ "$OS" == "linux" ]]; then
            echo -e "${BLUE}Updating font cache...${NC}"
            if fc-cache -fv "$FONT_DIR" &> /dev/null; then
                echo -e "${GREEN}✓ Font cache updated${NC}"
            else
                echo -e "${YELLOW}Warning: Failed to update font cache${NC}"
            fi
        fi

        return 0
    else
        echo -e "${RED}✗ Failed to install $font_name${NC}"
        return 1
    fi
}

# Install multiple Nerd Fonts
install_nerd_fonts() {
    local fonts=("$@")

    echo -e "${BLUE}=== Installing ${#fonts[@]} Nerd Fonts ===${NC}"

    for font in "${fonts[@]}"; do
        install_nerd_font "$font"
    done
}

# Install fonts from a local directory
install_fonts_from_dir() {
    local source_dir="$1"

    if [[ ! -d "$source_dir" ]]; then
        echo -e "${RED}Error: Font source directory not found: $source_dir${NC}"
        return 1
    fi

    echo -e "${BLUE}Installing fonts from: $source_dir${NC}"

    # Create font directory if it doesn't exist
    mkdir -p "$FONT_DIR"

    # Find and copy font files
    local font_count=0
    while IFS= read -r -d '' font_file; do
        cp "$font_file" "$FONT_DIR/"
        ((font_count++))
    done < <(find "$source_dir" -type f \( -iname "*.ttf" -o -iname "*.otf" -o -iname "*.woff" -o -iname "*.woff2" \) -print0)

    if [[ $font_count -gt 0 ]]; then
        echo -e "${GREEN}✓ Installed $font_count font files${NC}"

        # Update font cache on Linux
        if [[ "$OS" == "linux" ]]; then
            echo -e "${BLUE}Updating font cache...${NC}"
            fc-cache -fv "$FONT_DIR" &> /dev/null
            echo -e "${GREEN}✓ Font cache updated${NC}"
        fi

        return 0
    else
        echo -e "${YELLOW}Warning: No font files found in $source_dir${NC}"
        return 1
    fi
}

# Check if a font is installed
is_font_installed() {
    local font_name="$1"

    if [[ "$OS" == "macos" ]]; then
        # On macOS, check if font exists in Font directory
        if ls "$FONT_DIR"/*"$font_name"* 1> /dev/null 2>&1; then
            return 0
        fi
    elif [[ "$OS" == "linux" ]]; then
        # On Linux, use fc-list to check
        if fc-list | grep -qi "$font_name"; then
            return 0
        fi
    fi

    return 1
}

# List installed fonts
list_installed_fonts() {
    echo -e "${BLUE}=== Installed Fonts ===${NC}"

    if [[ "$OS" == "macos" ]]; then
        ls -1 "$FONT_DIR" 2>/dev/null || echo "No fonts found in $FONT_DIR"
    elif [[ "$OS" == "linux" ]]; then
        fc-list : family | sort -u
    fi
}

# Update font cache (Linux only)
update_font_cache() {
    if [[ "$OS" == "linux" ]]; then
        echo -e "${BLUE}Updating font cache...${NC}"
        if fc-cache -fv; then
            echo -e "${GREEN}✓ Font cache updated${NC}"
            return 0
        else
            echo -e "${RED}✗ Failed to update font cache${NC}"
            return 1
        fi
    else
        echo -e "${YELLOW}Font cache update not needed on $OS${NC}"
        return 0
    fi
}
