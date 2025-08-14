# My Dotfiles Repository

This repository contains my personal dotfiles and configurations for macOS.

## Quick Start

1. Clone the repository:

   ```bash
   git clone <repository-url> ~/.config
   ```

2. Run the installation script:

   ```bash
   cd ~/.config
   ./install.sh
   ```

3. Restart your terminal or source the config:
   ```bash
   source ~/.zshrc
   ```

## What's Included

- **Zsh configuration** with Oh My Zsh, Powerlevel10k theme
- **Tmux configuration** with vim-style keybindings and plugins
- **Git configuration** with global gitignore
- **WezTerm configuration**
- **iTerm2 preferences** (if available)
- **Homebrew packages** via Brewfile

## Manual Steps After Installation

1. **Tmux plugins**: Open tmux and press `Ctrl+Space + I` to install plugins
2. **Powerlevel10k**: Run `p10k configure` if you need to reconfigure the prompt
3. **iTerm2**: If preferences weren't imported, manually configure and export to
   `iterm2/com.googlecode.iterm2.plist`

## Key Features

### Tmux

- Prefix key: `Ctrl+Space` (not Ctrl+B)
- Vim-style copy mode (`y` to copy, not Cmd+C)
- Split windows: `|` (horizontal), `-` (vertical)
- Resize panes: `h/j/k/l`
- Reload config: `Ctrl+Space + r`

### Zsh

- Enhanced history with search
- Auto-suggestions and syntax highlighting
- Better ls with `eza`
- Better cd with `zoxide`
- Git aliases: `gs`, `ga`, `gc`, `gl`, `lg`

### Git

- Global gitignore for common files
- Configured editor and basic settings

## Troubleshooting

- If tmux plugins don't work, ensure TPM is installed and press `Ctrl+Space + I`
- If zsh isn't the default shell, run: `chsh -s $(which zsh)`
- For iTerm2 theme issues, check that Meslo LG Nerd Font is selected in
  preferences
- If vim bindings don't work in tmux copy mode, ensure your .tmux.conf is
  properly linked

> Font and theme inspiration from:
> https://www.josean.com/posts/how-to-setup-wezterm-terminal
