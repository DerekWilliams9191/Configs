# My Dotfiles Repository

This repository contains my personal dotfiles and configurations for macOS and Linux.

## Quick Start

1. Clone the repository:

   ```bash
   git clone <repository-url> ~/.config
   ```

2. Run the installation script:

   **macOS:**
   ```bash
   cd ~/.config/Configs
   ./install-mac.sh
   ```

   **Linux:**
   ```bash
   cd ~/.config/Configs
   ./install-linux.sh
   ```

3. Restart your terminal or source the config:
   ```bash
   source ~/.zshrc
   ```

## What's Included

- **Zsh configuration** with Oh My Zsh, Powerlevel10k theme, fzf-tab, ctrl+r fzf history
- **Tmux configuration** with vim-style keybindings and plugins
- **Git configuration** with global gitignore
- **Ghostty configuration** (macOS)
- **iTerm2 preferences** (macOS only)
- **Package management** via Homebrew (macOS) or native package managers (Linux)

## Manual Steps After Installation

1. **Tmux plugins**: Open tmux and press `Ctrl+Space + I` to install plugins
2. **Powerlevel10k**: Run `p10k configure` if you need to reconfigure the prompt
3. **iTerm2** (macOS): If preferences weren't imported, manually configure and export to
   `iterm2/com.googlecode.iterm2.plist`
4. **Linux**: Set your terminal font to 'MesloLGS NF' for proper icon display

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

## Linux Support

The `install-linux.sh` script supports:
- **Ubuntu/Debian** - Uses apt package manager
- **Fedora/Rocky/AlmaLinux** - Uses dnf package manager
- **RHEL/CentOS** - Uses dnf if available, falls back to yum
- **Amazon Linux** - Uses yum on AL2, dnf on AL2023
- **Arch/Manjaro** - Uses pacman package manager

### Local vs remote profile

The shell behaves slightly differently on remote hosts. `DOTFILES_PROFILE`
controls this — defaults to `local`. Setting it to `remote` (the Linux
installer does this automatically when run over SSH or without a graphical
display) causes the shell to auto-attach to a tmux session on login. The last
attached session name is saved to `~/.tmux-last-session`; first login uses
`main`.

To force remote behavior on a host:

```bash
echo 'export DOTFILES_PROFILE=remote' >> ~/.zshenv
```

### Ghostty over SSH

If you SSH from Ghostty into a host that doesn't have Ghostty's terminfo,
you'll see `'xterm-ghostty': unknown terminal type`. Two ways to fix it:

- **Push terminfo from local (run once per remote host):**
  ```bash
  infocmp -x ghostty | ssh user@host -- tic -x -
  ```
- **Fallback (no setup needed):** the `ssh()` wrapper in `.zshrc`
  auto-downgrades `TERM=xterm-256color` when SSHing from Ghostty. Use
  `command ssh` to bypass it when you want the real `TERM`.

Key differences from macOS:
- No iTerm2 (use any terminal with Nerd Font support)
- Packages installed via system package managers instead of Homebrew
- Plugins installed directly to `.oh-my-zsh/custom/`
- MesloLGS Nerd Font downloaded and installed to `~/.local/share/fonts/`

## Troubleshooting

- If tmux plugins don't work, ensure TPM is installed and press `Ctrl+Space + I`
- If zsh isn't the default shell, run: `chsh -s $(which zsh)`
- **macOS**: For iTerm2 theme issues, check that Meslo LG Nerd Font is selected in preferences
- **Linux**: Set terminal font to 'MesloLGS NF' for proper display
- If vim bindings don't work in tmux copy mode, ensure your .tmux.conf is properly linked

> Font and theme inspiration from:
> https://www.josean.com/posts/how-to-setup-wezterm-terminal
