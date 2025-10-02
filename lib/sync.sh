#!/usr/bin/env bash
# Cross-platform sync and configuration script
# Works on both macOS and Linux

set -e

# Get script directory (parent of lib/)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Source OS detection utilities
source "$SCRIPT_DIR/lib/os-detect.sh"

echo -e "${BLUE}=== Syncing dotfiles ===${NC}"

#TODO: enable Bitwarden on Linux
# Login to Bitwarden
#echo -e "${BLUE}Logging in to Bitwarden...${NC}"
#bw login

# Pull secrets for Fabric AI
#chmod +x "$SCRIPT_DIR/lib/shh.sh"
#"$SCRIPT_DIR/lib/shh.sh" -o .config/fabric/.env

# Remove existing shell rc file to prevent conflicts
if [[ -f "$SHELL_RC" ]]; then
    echo -e "${YELLOW}Removing existing $SHELL_RC${NC}"
    rm "$SHELL_RC"
fi

# Use GNU Stow to symlink dotfiles
echo -e "${BLUE}Creating symlinks with stow...${NC}"
stow .

# Generate SSH key
if [[ ! -f ~/.ssh/id_rsa.luminosita ]]; then
    echo -e "${BLUE}Generating SSH key...${NC}"
    ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa.luminosita -N ""
    echo -e "${GREEN}✓ SSH key generated${NC}"
else
    echo -e "${GREEN}✓ SSH key already exists${NC}"
fi

# Configure git
cd "$SCRIPT_DIR"

if git remote get-url origin &> /dev/null; then
    git remote remove origin
fi
git remote add origin git@gh-luminosita:luminosita/dotfiles.git

git config --global user.email "milosh@emisia.net"
git config --global user.name "Milos Milosavljevic"

echo -e "${GREEN}✓ Git configured${NC}"

# Display next steps
echo ""
echo -e "${BLUE}=== Next Steps ===${NC}"
echo -e "1. Follow instructions at https://github.com/tonsky/FiraCode/wiki/VS-Code-Instructions to enable Fira Code in VS Code"

if [[ "$OS" == "macos" ]]; then
    echo -e "2. Execute: ${GREEN}source ~/.zshrc${NC}"
elif [[ "$OS" == "linux" ]]; then
    echo -e "2. Execute: ${GREEN}source ~/.bashrc${NC}"
fi

echo ""
echo -e "${GREEN}=== Sync complete ===${NC}"

