# ~/.bashrc managed by Server-Tools

# If not running interactively, do nothing.
case $- in
  *i*) ;;
  *) return ;;
esac

# Source global definitions.
if [ -f /etc/bash.bashrc ]; then
  . /etc/bash.bashrc
fi

export EDITOR=vim
export HISTSIZE=50000
export HISTFILESIZE=100000
export HISTCONTROL=ignoredups:erasedups
export HISTTIMEFORMAT='%F %T '
shopt -s histappend
shopt -s checkwinsize

alias ls='ls --color=auto'
alias ll='ls --color=auto -alF'
alias la='ls --color=auto -A'
alias l='ls --color=auto -CF'

__last_status=0
__set_prompt() {
  local status git branch

  if [ "$__last_status" -eq 0 ]; then
    status=''
  else
    status="\[\e[1;31m\]ERR:${__last_status}\[\e[0m\] "
  fi

  git=''
  if command -v git >/dev/null 2>&1; then
    branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
    if [ -n "$branch" ] && [ "$branch" != "HEAD" ]; then
      git=" \[\e[1;35m\](${branch})\[\e[0m\]"
    fi
  fi

  PS1="\[\e[1;30m\][\t]\[\e[0m\] ${status}\[\e[1;31m\]\u@\h\[\e[0m\]:\[\e[1;34m\]\w\[\e[0m\]${git}\[\e[1;33m\]\$ \[\e[0m\]"
}

PROMPT_COMMAND='__last_status=$?; history -a; __set_prompt'
