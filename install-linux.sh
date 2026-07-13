#!/bin/bash

set -e  # Exit on any error

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Profile: --local or --remote. Required.
case "$1" in
    --local)  PROFILE="local" ;;
    --remote) PROFILE="remote" ;;
    *)        echo "Usage: $0 --local|--remote"; exit 1 ;;
esac

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_step() {
    echo -e "${BLUE}==>${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

# Detect Linux distribution
detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo "$ID"
    elif [ -f /etc/debian_version ]; then
        echo "debian"
    elif [ -f /etc/redhat-release ]; then
        echo "rhel"
    else
        echo "unknown"
    fi
}

# Create symlink
create_symlink() {
    local source="$1"
    local target="$2"

    if [ -e "$target" ] || [ -L "$target" ]; then
        rm -rf "$target"
    fi

    mkdir -p "$(dirname "$target")"
    ln -sf "$source" "$target"
    print_success "Linked $source -> $target"
}

# Package installation functions
install_packages_apt() {
    print_step "Installing packages via apt..."
    sudo apt update

    # Install packages
    sudo apt install -y \
        zsh \
        bash \
        fzf \
        git \
        curl \
        wget \
        tmux \
        vim \
        ripgrep \
        fd-find \
        build-essential \
        fonts-powerline \
        fonts-noto-color-emoji
    
    # Install eza (better ls)
    if ! command -v eza &> /dev/null; then
        print_step "Installing eza..."
        wget -qO- https://raw.githubusercontent.com/eza-community/eza/main/deb.asc | sudo gpg --dearmor -o /etc/apt/keyrings/gierens.gpg
        echo "deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main" | sudo tee /etc/apt/sources.list.d/gierens.list
        sudo chmod 644 /etc/apt/keyrings/gierens.gpg /etc/apt/sources.list.d/gierens.list
        sudo apt update
        sudo apt install -y eza
    fi
    
    # Install zoxide (better cd)
    if ! command -v zoxide &> /dev/null; then
        print_step "Installing zoxide..."
        curl -sS https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | bash
        export PATH="$HOME/.local/bin:$PATH"
    fi
    
    # Install lazygit
    if ! command -v lazygit &> /dev/null; then
        print_step "Installing lazygit..."
        LAZYGIT_VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | grep -Po '"tag_name": "v\K[^"]*')
        curl -Lo lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz"
        tar xf lazygit.tar.gz lazygit
        sudo install lazygit /usr/local/bin
        rm lazygit.tar.gz lazygit
    fi
}

install_packages_dnf() {
    # Amazon Linux 2023's default repos lack fzf, neovim, and powerline-fonts,
    # so we install fzf/neovim from upstream and drop powerline-fonts (the
    # MesloLGS Nerd Font installed later is what p10k uses).
    print_step "Installing packages via dnf..."
    sudo dnf update -y

    sudo dnf install -y \
        zsh \
        bash \
        git \
        wget \
        tmux \
        vim \
        gcc \
        gcc-c++ \
        make \
        unzip \
        tar \
        google-noto-emoji-color-fonts

    # fzf via official installer (not in AL2023's default repos)
    if ! command -v fzf &> /dev/null; then
        print_step "Installing fzf from git..."
        if [ ! -d "$HOME/.fzf" ]; then
            git clone --depth 1 https://github.com/junegunn/fzf.git "$HOME/.fzf"
        fi
        "$HOME/.fzf/install" --bin
        # Symlink the binary into a directory on PATH for non-interactive shells
        mkdir -p "$HOME/.local/bin"
        ln -sf "$HOME/.fzf/bin/fzf" "$HOME/.local/bin/fzf"
    fi

    # neovim from upstream GitHub release tarball (not in AL2023's default repos)
    if ! command -v nvim &> /dev/null; then
        print_step "Installing neovim from GitHub release..."
        cd /tmp
        curl -Lo nvim.tar.gz "https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz"
        tar xf nvim.tar.gz
        mkdir -p "$HOME/.local"
        cp -r nvim-linux-x86_64/* "$HOME/.local/"
        rm -rf nvim.tar.gz nvim-linux-x86_64
    fi

    # Install eza
    if ! command -v eza &> /dev/null; then
        print_step "Installing eza..."
        sudo dnf install -y eza || {
            print_warning "eza not in repos; installing from GitHub release..."
            cd /tmp
            curl -Lo eza.tar.gz "https://github.com/eza-community/eza/releases/latest/download/eza_x86_64-unknown-linux-gnu.tar.gz"
            tar xf eza.tar.gz
            mkdir -p "$HOME/.local/bin"
            mv eza "$HOME/.local/bin/eza"
            rm -f eza.tar.gz
        }
    fi

    # Install zoxide
    if ! command -v zoxide &> /dev/null; then
        print_step "Installing zoxide..."
        curl -sS https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | bash
        export PATH="$HOME/.local/bin:$PATH"
    fi

    # Install lazygit
    if ! command -v lazygit &> /dev/null; then
        print_step "Installing lazygit..."
        { sudo dnf copr enable atim/lazygit -y && sudo dnf install lazygit -y; } || {
            print_warning "lazygit copr unavailable; installing from GitHub release..."
            LAZYGIT_VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | grep -Po '"tag_name": "v\K[^"]*')
            cd /tmp
            curl -Lo lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz"
            tar xf lazygit.tar.gz lazygit
            sudo install lazygit /usr/local/bin
            rm lazygit.tar.gz lazygit
        }
    fi
}

install_packages_pacman() {
    print_step "Installing packages via pacman..."
    sudo pacman -Syu --noconfirm

    sudo pacman -S --noconfirm \
        zsh \
        bash \
        fzf \
        git \
        curl \
        wget \
        tmux \
        vim \
        neovim \
        base-devel \
        powerline-fonts \
        noto-fonts-emoji \
        eza \
        zoxide \
        lazygit
}

install_packages_yum() {
    # For Amazon Linux 2 and older RHEL/CentOS where dnf isn't available.
    # eza, lazygit, and fzf aren't in the default repos here, so we install
    # them from upstream releases / git.
    print_step "Installing packages via yum..."
    sudo yum update -y

    sudo yum install -y \
        zsh \
        bash \
        git \
        curl \
        wget \
        tmux \
        vim \
        gcc \
        gcc-c++ \
        make \
        unzip \
        tar

    # fzf via official installer (no yum package)
    if ! command -v fzf &> /dev/null; then
        print_step "Installing fzf from git..."
        if [ ! -d "$HOME/.fzf" ]; then
            git clone --depth 1 https://github.com/junegunn/fzf.git "$HOME/.fzf"
        fi
        "$HOME/.fzf/install" --bin
        # Symlink the binary into a directory on PATH for non-interactive shells
        mkdir -p "$HOME/.local/bin"
        ln -sf "$HOME/.fzf/bin/fzf" "$HOME/.local/bin/fzf"
    fi

    # eza from upstream release tarball
    if ! command -v eza &> /dev/null; then
        print_step "Installing eza from GitHub release..."
        EZA_VERSION=$(curl -s "https://api.github.com/repos/eza-community/eza/releases/latest" | grep -Po '"tag_name": "v\K[^"]*')
        cd /tmp
        curl -Lo eza.tar.gz "https://github.com/eza-community/eza/releases/latest/download/eza_x86_64-unknown-linux-gnu.tar.gz"
        tar xf eza.tar.gz
        mkdir -p "$HOME/.local/bin"
        mv eza "$HOME/.local/bin/eza"
        rm -f eza.tar.gz
    fi

    # zoxide via upstream installer
    if ! command -v zoxide &> /dev/null; then
        print_step "Installing zoxide..."
        curl -sS https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | bash
        export PATH="$HOME/.local/bin:$PATH"
    fi

    # lazygit from GitHub release tarball
    if ! command -v lazygit &> /dev/null; then
        print_step "Installing lazygit..."
        LAZYGIT_VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | grep -Po '"tag_name": "v\K[^"]*')
        cd /tmp
        curl -Lo lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz"
        tar xf lazygit.tar.gz lazygit
        sudo install lazygit /usr/local/bin
        rm lazygit.tar.gz lazygit
    fi
}

# Install zsh plugins
install_zsh_plugins() {
    local ZSH_CUSTOM="$HOME/.oh-my-zsh/custom"

    # Install zsh-autosuggestions
    if [ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]; then
        print_step "Installing zsh-autosuggestions..."
        git clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
    fi

    # Install zsh-syntax-highlighting
    if [ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]; then
        print_step "Installing zsh-syntax-highlighting..."
        git clone https://github.com/zsh-users/zsh-syntax-highlighting "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
    fi

    # Install fzf-tab
    if [ ! -d "$ZSH_CUSTOM/plugins/fzf-tab" ]; then
        print_step "Installing fzf-tab..."
        git clone https://github.com/Aloxaf/fzf-tab "$ZSH_CUSTOM/plugins/fzf-tab"
    fi

    # Install powerlevel10k theme
    if [ ! -d "$ZSH_CUSTOM/themes/powerlevel10k" ]; then
        print_step "Installing powerlevel10k theme..."
        git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$ZSH_CUSTOM/themes/powerlevel10k"
    fi
}

print_step "Starting dotfiles installation for Linux..."

# Detect distribution and install packages
DISTRO=$(detect_distro)
print_step "Detected distribution: $DISTRO"

case "$DISTRO" in
    ubuntu|debian|mint|pop)
        install_packages_apt
        ;;
    fedora|rocky|almalinux)
        install_packages_dnf
        ;;
    rhel|centos)
        # Newer RHEL/CentOS ship dnf; older ones only have yum.
        if command -v dnf >/dev/null 2>&1; then
            install_packages_dnf
        else
            install_packages_yum
        fi
        ;;
    amzn)
        # Amazon Linux 2 is yum-only; AL2023 uses dnf.
        if command -v dnf >/dev/null 2>&1; then
            install_packages_dnf
        else
            install_packages_yum
        fi
        ;;
    arch|manjaro|endeavouros)
        install_packages_pacman
        ;;
    *)
        print_error "Unsupported distribution: $DISTRO"
        print_error "Please install packages manually:"
        print_error "  zsh bash fzf git curl wget tmux vim neovim eza zoxide lazygit"
        exit 1
        ;;
esac

# Install Oh My Zsh if not present
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    print_step "Installing Oh My Zsh..."
    git clone https://github.com/ohmyzsh/ohmyzsh.git "$HOME/.oh-my-zsh"
    print_success "Oh My Zsh installed to $HOME/.oh-my-zsh"
else
    print_success "Oh My Zsh already present"
fi

# Install zsh plugins
install_zsh_plugins

# Create symlinks for configuration files
print_step "Creating configuration symlinks..."

create_symlink "$SCRIPT_DIR/.zshrc" "$HOME/.zshrc"

create_symlink "$SCRIPT_DIR/.gitconfig" "$HOME/.gitconfig"

# Only link .gitignore_global if it exists
if [ -f "$SCRIPT_DIR/.gitignore_global" ]; then
    create_symlink "$SCRIPT_DIR/.gitignore_global" "$HOME/.gitignore_global"
fi

create_symlink "$SCRIPT_DIR/.tmux.conf" "$HOME/.tmux.conf"

# Link nvim config if it exists
if [ -d "$SCRIPT_DIR/nvim" ]; then
    create_symlink "$SCRIPT_DIR/nvim" "$HOME/.config/nvim"
fi

# Install TPM (Tmux Plugin Manager)
if [ ! -d "$HOME/.tmux/plugins/tpm" ]; then
    print_step "Installing Tmux Plugin Manager..."
    git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
    print_success "TPM installed"
else
    print_success "TPM already installed"
fi

# Install tmux plugins non-interactively
print_step "Installing tmux plugins..."
"$HOME/.tmux/plugins/tpm/bin/install_plugins"
print_success "Tmux plugins installed"

# Set up Powerlevel10k
if [ -f "$SCRIPT_DIR/.p10k.zsh" ]; then
    create_symlink "$SCRIPT_DIR/.p10k.zsh" "$HOME/.p10k.zsh"
else
    print_warning "No Powerlevel10k config found. Run 'p10k configure' after installation."
fi
if [ -f "$SCRIPT_DIR/.p10k-gruvbox.zsh" ]; then
    create_symlink "$SCRIPT_DIR/.p10k-gruvbox.zsh" "$HOME/.p10k-gruvbox.zsh"
fi

# Add zoxide and eza to PATH if needed
if ! echo "$PATH" | grep -q "$HOME/.local/bin"; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.profile"
    export PATH="$HOME/.local/bin:$PATH"
fi

if [ "$PROFILE" = "remote" ]; then
    echo 'export DOTFILES_PROFILE=remote' > "$HOME/.zshenv"
    print_success "Wrote DOTFILES_PROFILE=remote to ~/.zshenv"
fi

# Make zsh the default shell
if [ "$SHELL" != "$(which zsh)" ]; then
    print_step "Setting zsh as default shell..."
    echo "You may be prompted for your password to change the default shell."
    chsh -s "$(which zsh)" || print_warning "Failed to set zsh as default shell. Run manually: chsh -s \$(which zsh)"
    print_success "Default shell set to zsh"
else
    print_success "zsh is already the default shell"
fi

# Install Nerd Font
print_step "Installing Nerd Font..."
FONT_DIR="$HOME/.local/share/fonts"
mkdir -p "$FONT_DIR"

if [ ! -f "$FONT_DIR/MesloLGS NF Regular.ttf" ]; then
    print_step "Downloading MesloLGS Nerd Font..."
    cd /tmp
    wget -q "https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Regular.ttf"
    wget -q "https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Bold.ttf"
    wget -q "https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Italic.ttf"
    wget -q "https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Bold%20Italic.ttf"
    
    mv "MesloLGS NF"*.ttf "$FONT_DIR/"
    fc-cache -fv
    print_success "MesloLGS Nerd Font installed"
else
    print_success "MesloLGS Nerd Font already installed"
fi

# Configure GNOME Terminal if available
if command -v gnome-terminal &> /dev/null; then
    print_step "Configuring GNOME Terminal..."
    "$SCRIPT_DIR/configure-gnome-terminal.sh" || print_warning "Failed to configure GNOME Terminal"
fi

# Install Blur my Shell extension for GNOME
if command -v gnome-shell &> /dev/null; then
    print_step "Installing Blur my Shell extension..."
    if ! gnome-extensions list | grep -q "blur-my-shell@aunetx"; then
        # Download and install the extension
        EXTENSION_UUID="blur-my-shell@aunetx"
        EXTENSION_URL="https://extensions.gnome.org/extension-data/blur-my-shellaunetx.v64.shell-extension.zip"
        EXTENSION_DIR="$HOME/.local/share/gnome-shell/extensions/$EXTENSION_UUID"

        mkdir -p "$EXTENSION_DIR"
        wget -q -O /tmp/blur-my-shell.zip "$EXTENSION_URL"
        unzip -q -o /tmp/blur-my-shell.zip -d "$EXTENSION_DIR"
        rm /tmp/blur-my-shell.zip

        gnome-extensions enable "$EXTENSION_UUID" 2>/dev/null || print_warning "Extension installed but needs manual activation"
        print_success "Blur my Shell extension installed"
    else
        print_success "Blur my Shell extension already installed"
    fi
fi

# Final setup steps
print_step "Performing final setup..."

print_success "Configuration installed successfully!"

echo
echo -e "${GREEN}🎉 Installation complete!${NC}"
echo
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Restart your terminal or run: source ~/.zshrc"
echo "2. If you don't have a Powerlevel10k config, run: p10k configure"
echo "3. Set your terminal font to 'MesloLGS NF' for best results"
echo "4. (GNOME Terminal) Theme already applied! Open a new terminal window to see it"
echo
echo -e "${YELLOW}Ghostty over SSH${NC}"
echo "If you SSH from Ghostty into a host that doesn't know xterm-ghostty,"
echo "you'll see: 'xterm-ghostty': unknown terminal type."
echo
echo "Two ways to fix it:"
echo
echo "  [Local — Ghostty machine] Push Ghostty's terminfo to the remote (run ONCE per host):"
echo "      infocmp -x ghostty | ssh user@host -- tic -x -"
echo
echo "  [Local — fallback] The ssh() wrapper in .zshrc auto-downgrades TERM"
echo "      to xterm-256color when SSHing from Ghostty. Already enabled,"
echo "      no action needed. Use 'command ssh' to bypass it."
echo
echo "  [Remote] If you can't run the local command above (e.g. you don't have"
echo "  Ghostty installed locally), have someone with Ghostty send you the"
echo "  terminfo file, then on the remote run:"
echo "      tic -x ghostty.terminfo"
echo
