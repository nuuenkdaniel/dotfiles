## Dotfiles ##
Config files for my desktop

### Main Stuff ###
* OS: Arch
* WM: hyprland
* Launcher: wofi
* File Manager: dolphin
* Info Bar: waybar
* Terminal: kitty
* Shell: zsh

### Installation ###
```
git clone https://github.com/nuuenkdaniel/dotfiles
mv dotfiles/.git ~/.dotfiles
mv dotfiles/* ~
```
### Repo Setup ###
```
git init --bare "$HOME/.dotfiles"
alias dotfiles="git --git-dir=$HOME/.dotfiles/ --work-tree=$HOME"
compdef dotfiles=git

dotfiles remote add origin https://github.com/nuuenkdaniel/dotfiles
dotfiles push --set-upstream origin main
```
