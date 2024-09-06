export PATH="${PATH}:${HOME}/.local/bin"

# Lines configured by zsh-newuser-install
HISTFILE=~/.histfile
HISTSIZE=1000
SAVEHIST=1000
bindkey -e
# End of lines configured by zsh-newuser-install
# The following lines were added by compinstall
zstyle :compinstall filename '/home/Danuu/.zshrc'

# Alias
alias dotfiles="git --git-dir=$HOME/.dotfiles/ --work-tree=$HOME"
alias ls="exa"
alias syncDrive="rclone copy -L /home/Danuu/OneDrive OneDrive:Lapnuu"
alias neofetch2="neofetch --ascii ~/.config/neofetch/ascii-art.txt --set-color 6"
alias syncPC="syncthing --no-browser"

autoload -Uz compinit
compinit

# ------------------------------------------
# Comp
# ------------------------------------------
zmodload zsh/complist 
autoload -Uz compinit
compinit
zstyle :compinstall filename '${HOME}/.zshrc'
compdef dotfiles=git

#- buggy
zstyle ':completion:*:descriptions' format '%U%B%d%b%u'
zstyle ':completion:*:warnings' format '%BSorry, no matches for: %d%b'
#-/buggy

zstyle ':completion:*:pacman:*' force-list always
zstyle ':completion:*:*:pacman:*' menu yes select

zstyle ':completion:*:default' list-colors ${(s.:.)LS_COLORS}

zstyle ':completion:*:*:kill:*' menu yes select
zstyle ':completion:*:kill:*'   force-list always

zstyle ':completion:*:*:killall:*' menu yes select
zstyle ':completion:*:killall:*'   force-list always

# Prompt style
setprompt() {
  setopt prompt_subst

  if [[ -n "$SSH_CLIENT"  ||  -n "$SSH2_CLIENT" ]]; then 
    p_host='%F{cyan}[%f%F{green}%n%f%F{cyan}@%f%F{green}%M%f%F{cyan}]%f'
  else 
    p_host=''
  fi

  PS1="${p_host}%F{cyan}[%~]%f "
  PS2=$'%_>'
  RPROMPT=$'${vcs_info_msg_0_}'
}
setprompt
# End of lines added by compinstall
