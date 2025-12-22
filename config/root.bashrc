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
export HISTSIZE=10000
export HISTFILESIZE=20000
export HISTCONTROL=ignoredups:erasedups
shopt -s histappend
shopt -s checkwinsize

alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'

# Red prompt for root.
PS1='\[\e[1;31m\]\u@\h\[\e[0m\]:\w\$ '
