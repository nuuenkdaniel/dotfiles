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
alias neofetch2="neofetch --ascii ~/.config/neofetch/ascii-art.txt --set-color 6"
alias syncPC="syncthing --no-browser"

# ------------------------------------------
# Comp
# ------------------------------------------
zmodload zsh/complist 
autoload -Uz compinit
compinit -d "$XDG_CACHE_HOME/zsh/zcompdump"
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

function check_ssh() {
  if [[ -n "$SSH_CLIENT"  ||  -n "$SSH2_CLIENT" ]]; then 
    echo "%F{cyan}[%f%F{green}%n%f%F{cyan}@%f%F{yellow}%M%f%F{cyan}]%f"
  fi
}


function precmd() {
  vcs_info
  print -Pn "\e]133;A\e\\" # Prompt Jumping
}


setopt prompt_subst

PROMPT='$(check_git_status)${vcs_info_msg_0_}$(check_ssh)%F{cyan}[%~]%f '
