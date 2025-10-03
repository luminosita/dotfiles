# Cross-Platform Dotfiles - Development Documentation

This document describes the architecture and implementation of the cross-platform dotfiles system, created to work seamlessly on both macOS and Linux.

## Overview

This dotfiles repository has been engineered to be fully cross-platform, automatically detecting the operating system and using the appropriate package manager, shell, and configurations.

### Key Features

- **OS Detection**: Automatic detection of macOS vs Linux
- **Package Manager Support**: Homebrew (macOS), apt/dnf/pacman (Linux)
- **Shell Configuration**: zsh (macOS), bash (Linux) with shared common config
- **Interactive UI**: Uses `gum` for beautiful TUI interactions
- **Modular Design**: Clean separation of concerns with utility libraries

## Architecture

### Directory Structure

```
dotfiles/
├── bootstrap.sh              # Main entry point - interactive installer
├── lib/                      # All utility scripts and installers
│   ├── os-detect.sh         # OS and package manager detection
│   ├── package-install.sh   # Cross-platform package installation
│   ├── fonts.sh             # Font installation utilities
│   ├── install.sh           # Base system installation
│   ├── install-dev.sh       # Development tools installation
│   ├── install-optional.sh  # Optional packages installation
│   ├── sync.sh              # Git config and dotfile syncing
│   ├── shh.sh               # Secret management (Bitwarden, etc.)
│   └── uninstall.sh         # Cleanup script
├── .config/
│   └── shell/
│       └── common.sh        # Shared shell configuration (bash + zsh)
├── .bashrc                  # Bash configuration (Linux)
├── .bash_profile            # Bash profile (sources .bashrc)
├── .zshrc                   # Zsh configuration (macOS)
├── packages.yaml            # Package name mappings across platforms
```

### Component Responsibilities

#### `bootstrap.sh`
- Entry point for the entire system
- Checks for required dependencies (gum, package manager)
- Offers to install missing dependencies automatically
- Provides interactive TUI for installation options
- Orchestrates all installation scripts

#### `lib/os-detect.sh`
- Detects operating system (macOS/Linux)
- Detects Linux distribution (Ubuntu, Fedora, Arch, etc.)
- Identifies available package manager (brew/apt/dnf/pacman)
- Sets OS-specific paths (fonts, shell RC files)
- Exports environment variables for other scripts

#### `lib/package-install.sh`
- Provides cross-platform package installation functions
- Loads package mappings from `packages.yaml`
- Maps common package names to OS-specific names
- Handles Brewfile parsing on Linux
- Skips GUI applications (casks) on Linux

#### `lib/fonts.sh`
- Cross-platform font installation
- Downloads and installs Nerd Fonts
- Handles platform-specific font directories:
  - macOS: `~/Library/Fonts`
  - Linux: `~/.local/share/fonts`
- Updates font cache on Linux with `fc-cache`

#### `lib/install.sh`
- Base system installation
- Installs Homebrew (local user installation)
- Installs Zinit plugin manager
- Installs Nix package manager
- Installs Nerd Fonts (FiraCode)
- Installs Bitwarden CLI

#### `lib/install-dev.sh`
- Development tools installation
- Uses Brewfile on macOS
- Maps packages to Linux equivalents
- Installs VS Code on Linux (with Microsoft repo)
- Installs VS Code extensions

#### `lib/install-optional.sh`
- Optional packages installation
- Media tools (VLC, Transmission, etc.)
- Utility applications
- Skips GUI apps on Linux

#### `lib/sync.sh`
- Configures git credentials
- Logs into Bitwarden
- Pulls secrets using `shh.sh`
- Uses GNU Stow to symlink dotfiles
- Generates SSH keys
- Sets up git remotes

#### `.config/shell/common.sh`
- Shared configuration for bash and zsh
- PATH setup (Homebrew, Go, local bin)
- Tool initialization (Starship, Zoxide, thefuck)
- Common aliases (eza, bat, kubectl)
- Kubectl completion and kubecolor setup

## Platform Differences

### macOS
- **Shell**: zsh (default)
- **Package Manager**: Homebrew (local user install in `~/homebrew`)
- **Font Directory**: `~/Library/Fonts`
- **Shell RC**: `~/.zshrc`

### Linux
- **Shell**: bash (default)
- **Package Manager**: apt, dnf, or pacman (system package manager)
- **Font Directory**: `~/.local/share/fonts`
- **Shell RC**: `~/.bashrc`
- **Font Cache**: Requires `fc-cache -fv` after font installation

## Package Mapping System

The `packages.yaml` file provides mappings between common package names and platform-specific names:

```yaml
packages:
  - name: gh
    brew: gh
    apt: gh
    dnf: gh
    pacman: github-cli

  - name: bat
    brew: bat
    apt: bat
    dnf: bat
    pacman: bat
```

Use `skip` to mark packages unavailable on specific platforms:

```yaml
  - name: kubecolor
    brew: kubecolor
    apt: skip
    dnf: skip
    pacman: kubecolor
```

## Shell Configuration Strategy

### Common Configuration
All shared configuration lives in `.config/shell/common.sh`:
- PATH setup
- Tool initialization (conditional on availability)
- Aliases
- Environment variables

### Shell-Specific Configuration

**Zsh (`.zshrc`)**:
- Zsh options (history, completion)
- Zinit plugin manager setup
- Zsh plugins (autosuggestions, syntax highlighting)
- Sources `common.sh`

**Bash (`.bashrc`)**:
- Bash options (history, completion)
- Zinit plugin manager setup (bash mode)
- Bash plugins
- Sources `common.sh`

## Dependencies

### Required (Auto-installed)
- **gum**: TUI library for beautiful CLI interactions
- **Homebrew** (macOS): Package manager
- **apt/dnf/pacman** (Linux): System package manager

### Installed by Scripts
- **Zinit**: Zsh/Bash plugin manager
- **Nix**: Functional package manager
- **Bitwarden CLI**: Secret management
- **GNU Stow**: Symlink management
- **Git**: Version control
- **curl**: HTTP client

## Usage

### Fresh Installation

```bash
# Clone the repository
git clone https://github.com/yourusername/dotfiles.git ~/dotfiles
cd ~/dotfiles

# Run the bootstrap script
./bootstrap.sh
```

The bootstrap script will:
1. Check for required dependencies (gum, package manager)
2. Offer to install missing dependencies
3. Show an interactive menu for installation options
4. Install selected components
5. Optionally sync dotfiles and configure git
6. Set the appropriate default shell

### Installation Options

1. **Full installation**: Base + dev tools + optional packages
2. **Base installation only**: Core system setup
3. **Base + dev tools**: System setup + development environment
4. **Custom selection**: Choose individual components

### Individual Scripts

You can also run individual scripts directly:

```bash
# Base installation
./lib/install.sh

# Development tools
./lib/install-dev.sh

# Optional packages
./lib/install-optional.sh

# Sync and configure
./lib/sync.sh
```

## Secret Management

The repository uses `shh.sh` for secret management, supporting:
- Bitwarden
- AWS Secrets Manager
- Google Cloud Secret Manager
- HashiCorp Vault
- Azure Key Vault
- File-based secrets
- Environment variables

Secrets are pulled during the sync phase and stored in `.config/fabric/.env`.

## Git Configuration

The sync script configures:
- Global git user (name and email)
- SSH keys (RSA 4096-bit)
- Git remotes (using custom SSH key)

## Customization

### Adding Packages

1. Add to `packages.yaml`:
```yaml
- name: mypackage
  brew: mypackage-brew-name
  apt: mypackage-apt-name
  dnf: mypackage-dnf-name
  pacman: mypackage-pacman-name
```

2. Update installation scripts to include the package

### Adding Aliases

Add to `.config/shell/common.sh`:
```bash
alias myalias='command'
```

### Adding Shell-Specific Config

**Zsh**: Add to `.zshrc` (before sourcing common.sh)
**Bash**: Add to `.bashrc` (before sourcing common.sh)

## Design Decisions

### Why Local Homebrew Installation?

Installing Homebrew locally (`~/homebrew`) instead of system-wide (`/opt/homebrew`) provides:
- No sudo required
- User-specific package versions
- Easier cleanup and reinstallation
- No conflicts with system packages

### Why Separate Shell Configs?

While most configuration is shared in `common.sh`, shell-specific files handle:
- Plugin manager initialization (Zinit)
- Shell-specific options
- Completion systems
- Key bindings

### Why gum as Required Dependency?

Making `gum` required (with auto-install) ensures:
- Consistent, beautiful UI across all platforms
- Better user experience with interactive prompts
- Visual feedback during installation
- Simplified code (no fallback logic)

## Troubleshooting

### Homebrew Not in PATH
```bash
# Add to current session
eval "$(/opt/homebrew/bin/brew shellenv)"  # Apple Silicon
eval "$(/usr/local/bin/brew shellenv)"     # Intel
```

### Fonts Not Appearing (Linux)
```bash
# Manually update font cache
fc-cache -fv ~/.local/share/fonts
```

### Shell Not Changing
```bash
# Check current shell
echo $SHELL

# List available shells
cat /etc/shells

# Change shell manually
chsh -s /bin/zsh   # macOS
chsh -s /bin/bash  # Linux
```

### Package Installation Failures
```bash
# Update package repositories first
# macOS
brew update

# Linux (apt)
sudo apt-get update

# Linux (dnf)
sudo dnf check-update
```

## Contributing

When contributing:
1. Test on both macOS and Linux
2. Update `packages.yaml` for new packages
3. Use OS detection for platform-specific code
4. Update this documentation for architectural changes

## Future Enhancements

Potential improvements:
- Support for more Linux distributions
- Windows WSL support
- Automated testing with GitHub Actions
- Configuration profiles (minimal, full, server)
- Backup/restore functionality
- Dotfile versioning and rollback
- Plugin system for custom scripts

## Credits

Created during a Claude Code session on October 2, 2024.

**Technologies Used**:
- [Homebrew](https://brew.sh/) - Package manager
- [gum](https://github.com/charmbracelet/gum) - TUI library
- [Zinit](https://github.com/zdharma-continuum/zinit) - Plugin manager
- [GNU Stow](https://www.gnu.org/software/stow/) - Symlink manager
- [Nix](https://nixos.org/) - Functional package manager
- [Starship](https://starship.rs/) - Shell prompt
- [Bitwarden](https://bitwarden.com/) - Secret management
