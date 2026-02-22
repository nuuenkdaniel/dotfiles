HISTFILE=~/.histfile
HISTSIZE=1000
SAVEHIST=500
bindkey -e
zstyle :compinstall filename '$HOME/.zshrc'

# Alias
alias dotfiles="git --git-dir=$HOME/.dotfiles/ --work-tree=$HOME"
alias dotfiles-private="git --git-dir=$HOME/.dotfiles-private/ --work-tree=/"
alias ls="eza"
alias cat="bat"
alias b="bigsay"
alias dup="kitty @ launch --type=os-window --cwd=current"
alias sl="ls"

# ------------------------------------------
# Comp
# ------------------------------------------
zmodload zsh/complist 
autoload -Uz compinit
compinit

compdef _paru paru
zstyle :compinstall filename '${HOME}/.zshrc'
compdef dotfiles=git
compdef dotfiles-private=git

zstyle ':completion:*:descriptions' format '%U%B%d%b%u'
zstyle ':completion:*:warnings' format '%BSorry, no matches for: %d%b'

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

PROMPT='$(check_git_status)${vcs_info_msg_0_}${p_host}%F{cyan}[%~]%f '
fastfetch

# >>> conda initialize >>>
# !! Contents within this block are managed by 'conda init' !!
function conda_init() {
  __conda_setup="$('/home/Danuu/.miniconda3/bin/conda' 'shell.zsh' 'hook' 2> /dev/null)"
  if [ $? -eq 0 ]; then
      eval "$__conda_setup"
  else
      if [ -f "/home/Danuu/.miniconda3/etc/profile.d/conda.sh" ]; then
          . "/home/Danuu/.miniconda3/etc/profile.d/conda.sh"
      else
          export PATH="/home/Danuu/.miniconda3/bin:$PATH"
      fi
  fi
  unset __conda_setup
}
# <<< conda initialize <<<

