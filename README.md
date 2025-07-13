# Configs

This is the place I store my configs so I can easily add them to any system.


## Getting started

Clone the repo, make sure to add the destination
` git clone git@github.com:DerekWilliams9191/Configs.git ~/.dotfiles`


### Adding symlinks
```bash
ln -s ~/.configs/.zshrc ~/.zshrc
ln -s ~/.configs/.gitconfig ~/.gitconfig

```


### Remove the "Last login:..." message
touch ~/.hushlogin

### Load global git ignore
git config --global core.excludesfile ~/.gitignore_global
