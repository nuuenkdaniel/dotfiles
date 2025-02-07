# Lines configured by zsh-newuser-install
HISTFILE=~/.histfile
HISTSIZE=1000
SAVEHIST=500
bindkey -e
# End of lines configured by zsh-newuser-install
# The following lines were added by compinstall
zstyle :compinstall filename '$HOME/.zshrc'

# Alias
alias dotfiles="git --git-dir=$HOME/.dotfiles/ --work-tree=$HOME"
alias ls="eza"
# alias syncDrive="rclone copy -L $HOME/OneDrive OneDrive:CaptNuu"

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

# End of lines added by compinstall

# Prompt style
autoload -Uz vcs_info
zstyle ':vcs_info:*' enable git
zstyle ':vcs_info:*' check-for-staged-changes true
zstyle ':vcs_info:git*' formats '%F{green}[%b]%f'

function check_git_status() {
  git_status=$(git status --porcelain 2> /dev/null | tail -n1)
  git_star=""
  if [[ -n $git_status ]]; then
    git_star="%F{red}*%f"
  fi
  echo $git_star
}

function precmd() {
  vcs_info
  print -Pn "\e]133;A\e\\" # Prompt Jumping
}

setopt prompt_subst

if [[ -n "$SSH_CLIENT"  ||  -n "$SSH2_CLIENT" ]]; then 
  p_host='%F{cyan}[%f%F{green}%n%f%F{cyan}@%f%F{yellow}%M%f%F{cyan}]%f'
fi

PROMPT='${check_git_status}${vcs_info_msg_0_}${p_host}%F{cyan}[%~]%f '
neofetch
