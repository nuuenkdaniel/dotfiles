## Dotfiles ##
Config files for my desktop

### Main Stuff ###
OS: Arch
WM: hyprland
Launcher: wofi
File Manager: dolphin
Info Bar: waybar
Terminal: kitty
Shell: zsh

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
### Stuff to install ###
hyprland,waybar,base,base-devel,eza,git,grim,slurp,intel-ucode,kitty,linux,linux-firmware,imv,mako,man-db,neovim,networkmanager,ttf-font-awesome,ttf-fira-mono,swayidle,swaylock,sof-firmware,polkit,polkit-gnome,otf-font-awesome,noto-fonts-emoji,ntfs-3g,dolphin,pipewire,pipewire-alsa,pipewire-audio,pipewire-pulse,wl-clipboard,wofi,zsh,zsh-completions,rclone
