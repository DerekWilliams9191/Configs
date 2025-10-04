#!/bin/bash

set -e  # Exit on any error

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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
    print_step "Installing packages via dnf..."
    sudo dnf update -y
    
    sudo dnf install -y \
        zsh \
        git \
        curl \
        wget \
        tmux \
        vim \
        neovim \
        gcc \
        gcc-c++ \
        make \
        powerline-fonts \
        google-noto-emoji-color-fonts
    
    # Install eza
    if ! command -v eza &> /dev/null; then
        print_step "Installing eza..."
        sudo dnf install -y eza
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
        sudo dnf copr enable atim/lazygit -y
        sudo dnf install lazygit -y
    fi
}

install_packages_pacman() {
    print_step "Installing packages via pacman..."
    sudo pacman -Syu --noconfirm
    
    sudo pacman -S --noconfirm \
        zsh \
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

# Install zsh plugins
install_zsh_plugins() {
    local ZSH_CUSTOM="$SCRIPT_DIR/.oh-my-zsh/custom"
    
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
    fedora|centos|rhel|rocky|almalinux)
        install_packages_dnf
        ;;
    arch|manjaro|endeavouros)
        install_packages_pacman
        ;;
    *)
        print_error "Unsupported distribution: $DISTRO"
        print_error "Please install packages manually:"
        print_error "  zsh git curl wget tmux vim neovim eza zoxide lazygit"
        exit 1
        ;;
esac

# Install Oh My Zsh if not present
if [ ! -d "$SCRIPT_DIR/.oh-my-zsh" ]; then
    print_step "Installing Oh My Zsh..."
    git clone https://github.com/ohmyzsh/ohmyzsh.git "$SCRIPT_DIR/.oh-my-zsh"
    print_success "Oh My Zsh installed to .config"
else
    print_success "Oh My Zsh already present"
fi

# Install zsh plugins
install_zsh_plugins

# Create modified zshrc for Linux
print_step "Creating Linux-specific zshrc..."
if [ -f "$SCRIPT_DIR/.zshrc" ]; then
    # Create a Linux version of zshrc
    cp "$SCRIPT_DIR/.zshrc" "$SCRIPT_DIR/.zshrc.linux"
    
    # Replace macOS-specific paths in the Linux version
    sed -i 's|source /opt/homebrew/share/powerlevel10k/powerlevel10k.zsh-theme|source ~/.config/.oh-my-zsh/custom/themes/powerlevel10k/powerlevel10k.zsh-theme|g' "$SCRIPT_DIR/.zshrc.linux"
    sed -i 's|source /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh|source ~/.config/.oh-my-zsh/custom/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh|g' "$SCRIPT_DIR/.zshrc.linux"
    sed -i 's|source /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh|source ~/.config/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh|g' "$SCRIPT_DIR/.zshrc.linux"
    
    # Update plugins line to include the installed plugins
    sed -i 's|plugins=(git)|plugins=(git zsh-autosuggestions zsh-syntax-highlighting)|g' "$SCRIPT_DIR/.zshrc.linux"
fi

# Create symlinks for configuration files
print_step "Creating configuration symlinks..."

if [ -f "$SCRIPT_DIR/.zshrc.linux" ]; then
    create_symlink "$SCRIPT_DIR/.zshrc.linux" "$HOME/.zshrc"
else
    create_symlink "$SCRIPT_DIR/.zshrc" "$HOME/.zshrc"
fi

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

# Set up Powerlevel10k
if [ ! -f "$HOME/.p10k.zsh" ]; then
    if [ -f "$SCRIPT_DIR/.p10k.zsh" ]; then
        create_symlink "$SCRIPT_DIR/.p10k.zsh" "$HOME/.p10k.zsh"
    else
        print_warning "No Powerlevel10k config found. Run 'p10k configure' after installation."
    fi
else
    print_success "Powerlevel10k configuration already exists"
fi

# Add zoxide and eza to PATH if needed
if ! echo "$PATH" | grep -q "$HOME/.local/bin"; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.profile"
    export PATH="$HOME/.local/bin:$PATH"
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
echo "2. Open tmux and press Ctrl+Space + I to install tmux plugins"
echo "3. If you don't have a Powerlevel10k config, run: p10k configure"
echo "4. Set your terminal font to 'MesloLGS NF' for best results"
echo "5. (GNOME Terminal) Theme already applied! Open a new terminal window to see it"
echo

# Reload shell configuration  
print_step "Reloading shell configuration..."
exec zsh -l
