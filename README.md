# Configs

This is the place I store my configs so I can easily add them to any system.


## Getting started

### Adding symlinks
```bash
ln -s ~/.config/.zshrc ~/.zshrc
ln -s ~/.config/.gitconfig ~/.gitconfig
ln -s ~/.config/.wezterm.lua ~/.wezterm.lua

```


### Remove the "Last login:..." message
touch ~/.hushlogin

> Front and theme pulled from here: https://www.josean.com/posts/how-to-setup-wezterm-terminal

### Font
```bash
brew install font-meslo-lg-nerd-font
```

### Theme
This needs a nerd font to work, see the above font to run it

```bash
brew install powerlevel10k
echo "source $(brew --prefix)/share/powerlevel10k/powerlevel10k.zsh-theme" >> ~/.zshrc
source ~/.zshrc
```
