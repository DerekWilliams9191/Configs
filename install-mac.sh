#!/bin/bash

set -e  # Exit on any error

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$HOME/.dotfiles-backup-$(date +%Y%m%d-%H%M%S)"

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

# Backup existing files
backup_file() {
    local file="$1"
    if [ -e "$file" ] || [ -L "$file" ]; then
        mkdir -p "$BACKUP_DIR"
        cp -R "$file" "$BACKUP_DIR/"
        print_warning "Backed up existing $file to $BACKUP_DIR/"
    fi
}

# Create symlink with backup
create_symlink() {
    local source="$1"
    local target="$2"
    
    if [ -e "$target" ] || [ -L "$target" ]; then
        backup_file "$target"
        rm -rf "$target"
    fi
    
    mkdir -p "$(dirname "$target")"
    ln -sf "$source" "$target"
    print_success "Linked $source -> $target"
}

print_step "Starting dotfiles installation..."

# Check if Homebrew is installed
if ! command -v brew &> /dev/null; then
    print_step "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    
    # Add Homebrew to PATH for the current session
    if [[ $(uname -m) == "arm64" ]]; then
        export PATH="/opt/homebrew/bin:$PATH"
        echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
    else
        export PATH="/usr/local/bin:$PATH"
        echo 'eval "$(/usr/local/bin/brew shellenv)"' >> ~/.zprofile
    fi
    eval "$(brew shellenv)"
    print_success "Homebrew installed"
else
    print_success "Homebrew already installed"
fi

# Install essential packages
print_step "Installing essential packages..."

# Formulae
BREW_FORMULAE=(
    "eza"
    "zoxide"
    "lazygit"
    "zsh-autosuggestions"
    "zsh-syntax-highlighting"
    "powerlevel10k"
    "tmux"
)

for formula in "${BREW_FORMULAE[@]}"; do
    if brew list --formulae | grep -q "^${formula}$"; then
        print_success "$formula already installed"
    else
        print_step "Installing $formula..."
        brew install "$formula"
        print_success "Installed $formula"
    fi
done

# Casks
BREW_CASKS=(
    "iterm2"
)

for cask in "${BREW_CASKS[@]}"; do
    if brew list --cask | grep -q "^${cask}$"; then
        print_success "$cask already installed"
    else
        print_step "Installing $cask..."
        brew install --cask "$cask"
        print_success "Installed $cask"
    fi
done

# Install Oh My Zsh if not present
if [ ! -d "$SCRIPT_DIR/.oh-my-zsh" ]; then
    print_step "Installing Oh My Zsh..."
    # Clone Oh My Zsh to our config directory
    git clone https://github.com/ohmyzsh/ohmyzsh.git "$SCRIPT_DIR/.oh-my-zsh"
    print_success "Oh My Zsh installed to .config"
else
    print_success "Oh My Zsh already present"
fi

# Create symlinks for configuration files
print_step "Creating configuration symlinks..."

create_symlink "$SCRIPT_DIR/.zshrc" "$HOME/.zshrc"
create_symlink "$SCRIPT_DIR/.gitconfig" "$HOME/.gitconfig"

# Only link .gitignore_global if it exists
if [ -f "$SCRIPT_DIR/.gitignore_global" ]; then
    create_symlink "$SCRIPT_DIR/.gitignore_global" "$HOME/.gitignore_global"
fi

create_symlink "$SCRIPT_DIR/.wezterm.lua" "$HOME/.wezterm.lua"
create_symlink "$SCRIPT_DIR/.tmux.conf" "$HOME/.tmux.conf"

# Link nvim config if it exists
if [ -d "$SCRIPT_DIR/nvim" ]; then
    create_symlink "$SCRIPT_DIR/nvim" "$HOME/.config/nvim"
fi

# Link Brewfile if it exists
if [ -f "$SCRIPT_DIR/Brewfile" ]; then
    create_symlink "$SCRIPT_DIR/Brewfile" "$HOME/Brewfile"
fi

# Install TPM (Tmux Plugin Manager)
if [ ! -d "$HOME/.tmux/plugins/tpm" ]; then
    print_step "Installing Tmux Plugin Manager..."
    git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
    print_success "TPM installed"
else
    print_success "TPM already installed"
fi

# Set up iTerm2 configuration
print_step "Setting up iTerm2 configuration..."

# Create iTerm2 preference directory if it doesn't exist
ITERM2_PREF_DIR="$HOME/Library/Preferences"
ITERM2_CONFIG_DIR="$SCRIPT_DIR/iterm2"

# Copy iTerm2 preferences if they exist in the dotfiles
if [ -f "$ITERM2_CONFIG_DIR/com.googlecode.iterm2.plist" ]; then
    backup_file "$ITERM2_PREF_DIR/com.googlecode.iterm2.plist"
    cp "$ITERM2_CONFIG_DIR/com.googlecode.iterm2.plist" "$ITERM2_PREF_DIR/"
    print_success "iTerm2 preferences copied"
else
    print_warning "No iTerm2 preferences found in dotfiles"
    print_warning "You'll need to configure iTerm2 manually and then export preferences to:"
    print_warning "  $ITERM2_CONFIG_DIR/com.googlecode.iterm2.plist"
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

# Install MesloLGS Nerd Font (same as Linux script for consistency)
print_step "Installing MesloLGS Nerd Font..."
FONT_DIR="$HOME/Library/Fonts"
mkdir -p "$FONT_DIR"

if [ ! -f "$FONT_DIR/MesloLGS NF Regular.ttf" ]; then
    print_step "Downloading MesloLGS Nerd Font..."
    cd /tmp
    wget -q "https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Regular.ttf" || curl -sL -o "MesloLGS NF Regular.ttf" "https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Regular.ttf"
    wget -q "https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Bold.ttf" || curl -sL -o "MesloLGS NF Bold.ttf" "https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Bold.ttf"
    wget -q "https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Italic.ttf" || curl -sL -o "MesloLGS NF Italic.ttf" "https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Italic.ttf"
    wget -q "https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Bold%20Italic.ttf" || curl -sL -o "MesloLGS NF Bold Italic.ttf" "https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Bold%20Italic.ttf"
    
    mv "MesloLGS NF"*.ttf "$FONT_DIR/"
    print_success "MesloLGS Nerd Font installed"
else
    print_success "MesloLGS Nerd Font already installed"
fi

# Make zsh the default shell
if [ "$SHELL" != "$(which zsh)" ]; then
    print_step "Setting zsh as default shell..."
    chsh -s "$(which zsh)"
    print_success "Default shell set to zsh"
else
    print_success "zsh is already the default shell"
fi

# Final setup steps
print_step "Performing final setup..."

# Source the new zsh configuration
print_success "Configuration installed successfully!"

echo
echo -e "${GREEN}🎉 Installation complete!${NC}"
echo
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Restart your terminal or run: source ~/.zshrc"
echo "2. Open tmux and press Ctrl+Space + I to install tmux plugins"
echo "3. If iTerm2 preferences weren't found, configure iTerm2 and export preferences to:"
echo "   $SCRIPT_DIR/iterm2/com.googlecode.iterm2.plist"
echo "4. If you don't have a Powerlevel10k config, run: p10k configure"
echo
if [ -d "$BACKUP_DIR" ]; then
    echo -e "${BLUE}Your original configs have been backed up to:${NC}"
    echo "  $BACKUP_DIR"
    echo
fi

# Reload shell configuration
print_step "Reloading shell configuration..."
exec zsh -l
