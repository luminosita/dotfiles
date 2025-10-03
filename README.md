# Cross-Platform Dotfiles

A comprehensive dotfiles setup that works seamlessly on both macOS and Linux, with automatic OS detection, package manager support, and interactive installation.

## Features

- **Cross-Platform**: Supports macOS and Linux (Ubuntu, Fedora, Arch)
- **Automatic Detection**: OS and package manager detection
- **Modular Design**: Separate scripts for base, dev tools, and optional packages
- **Shared Configuration**: Common shell config for both bash (Linux) and zsh (macOS)
- **Secret Management**: Bitwarden integration for secure credential storage
- **Container Tools**: Podman with completion support

## Quick Start

```sh
# Clone the repository
git clone https://github.com/luminosita/dotfiles.git ~/dotfiles
cd ~/dotfiles

# Run the interactive installer
./bootstrap.sh
```

The bootstrap script will:
1. Check for required dependencies (gum, package manager)
2. Offer to install missing dependencies
3. Show an interactive menu for installation options
4. Install selected components
5. Optionally sync dotfiles and configure git

## Configuration

`Bootstrap` script will read `config.yaml` file and install the packages

## Installation Options

### Full Installation (Recommended)
```sh
./bootstrap.sh
```

### Manual Installation
```sh
# Base installation (Homebrew, Zinit, Nix, fonts)
./lib/install.sh

# Development tools (git, docker, kubectl, VS Code, etc.)
./lib/install-dev.sh

# Optional packages (VLC, Transmission, etc.)
./lib/install-optional.sh

# Sync and configure (git, SSH keys, symlinks)
./lib/sync.sh
```

## Platform Support

### macOS
- Shell: zsh (default)
- Package Manager: Homebrew (local install in `~/homebrew`)
- Font Directory: `~/Library/Fonts`

### Linux
- Shell: bash (default)
- Package Manager: apt, dnf, or pacman (system package manager)
- Font Directory: `~/.local/share/fonts`

## Key Components

### Shell Configuration
- **`.config/shell/common.sh`**: Shared configuration for bash and zsh
  - PATH setup (Homebrew, Go, Nix, local bin)
  - Tool initialization (Starship, Zoxide, thefuck)
  - Completions (kubectl, podman)
  - Common aliases (eza, bat, kubecolor)

### Included Tools
- **Shell**: Starship prompt, Zoxide, thefuck
- **Development**: git, gh, docker/podman, kubectl, kubecolor
- **Languages**: go, rust, node, python
- **Editors**: VS Code with extensions
- **Utilities**: eza, bat, fzf, ripgrep, fd, jq, yq
- **Secrets**: Bitwarden CLI, shh.sh
- **Package Managers**: Homebrew, Nix, Zinit

## Usage

After installation, start a new terminal session. The prompt will be powered by Starship and all tools will be configured.

### Example: Using Zoxide
Zoxide enhances `cd` with smart directory navigation:

```sh
cd dot  # Press tab to jump to ~/dotfiles
```

### Example: Using Nix
Run development environments with unfree packages:

```sh
nixd  # Alias for: nix develop --impure
```

## Optional Applications

```sh
chmod +x install-optional.sh
./install-optional.sh
```

## Fabric

Run Setup and configure all the required components.

For Custom Patterns use `~/.config/fabric/patterns` path. Default values for the rest of required options.

```sh
fabric --setup
```

## Browser Extensions

floccus bookmarks sync (floccus.org)
Webpage to Markdown (chr0mekitdev)
Dark Reader (darkreader.org)
Medium Unlock (code4you.net)

AI Grammar Checker & Paraphraser – LanguageTool (languagetool.org)
Grammarly: AI Writing Assistant and Grammar Checker App (grammarly.com)
Google Translate (Google)

Save my Chatbot - AI Conversation Exporter (hugocollin.com)
AI Exporter: Save ChatGPT to PDF/MD/Notion.Supports Gemini,Deepseek,Claude (saveai.net)

Markdown Viewer (simov.github.io)

## Destroy

> Run nixd (alias) from ~/dotfiles folder

```sh
./uninstall.sh
```

> Ignore errors in the commands that follow.

```sh
mv ~/.zshrc-orig ~/.zshrc

mv ~/.config/starship.toml-orig ~/.config/starship.toml

mv ~/.config/fabric-orig ~/.config/fabric
```