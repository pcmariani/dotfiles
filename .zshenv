export SYSTEM=$(uname -s)
export TERM=xterm-256color

# for Homebrew - Needs to be before PATH
if [ "$(uname)" != 'Darwin' ]; then
  eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
fi

# Path
typeset -U path
path=("$HOME/.local/bin" "$HOME/scripts" "$HOME/.cargo/bin" "$HOME/projects/boomi-groovy-2" "$path[@]")
if [ "$(uname)" = 'Darwin' ]; then
  path=("/opt/homebrew/bin" "/opt/homebrew/sbin" "$path[@]")
fi

# Path variables
export ZDOTDIR=$HOME/.config/zsh
export HISTFILE="$ZDOTDIR/.zhistory"    # History filepath
export HISTSIZE=1000000                   # Maximum events for internal history
export SAVEHIST=1000000                   # Maximum events in history file

export BOOMI_GROOVY_HOME=$HOME/projects/boomi-groovy-2/

# Default programs
export EDITOR="nvim"
export VISUAL="nvim"
export BROWSER="lynx"
export MANPAGER='nvim +Man!'
export MANWIDTH=999
# export PAGER="less"

# Color manpages
# export LESS=-R
# export LESS_TERMCAP_mb="$(printf '%b' '[1;31m')"
# export LESS_TERMCAP_md="$(printf '%b' '[1;36m')"
# export LESS_TERMCAP_me="$(printf '%b' '[0m')"
# export LESS_TERMCAP_so="$(printf '%b' '[01;44;33m')"
# export LESS_TERMCAP_se="$(printf '%b' '[0m')"
# export LESS_TERMCAP_us="$(printf '%b' '[1;32m')"
# export LESS_TERMCAP_ue="$(printf '%b' '[0m')"

# [ -f "$HOME/.config/aliases" ] && source "$HOME/.config/aliases"

# export SCRIPTS=$HOME/scripts
# export INPUTRC="$HOME/.config/inputrc"
# export LESSHISTFILE="-"
# export KEEDIR="/mnt/c/Users/peter_mariani/Documents"
# export ENVDIR="$HOME/env"
# export DISPLAY=:0 # for wsl windows x server
# export PULSE_SERVER=tcp:127.0.0.1 # for wsl windows pulse server

# Lang: may be unnessecary
# export LANG='en_US.UTF-8'
# export LANGUAGE=en_US.UTF-8
# export LC_COLLATE=en_US.UTF-8
# export LC_CTYPE=en_US.UTF-8
# export LC_MESSAGES=en_US.UTF-8
# export LC_MONETARY=en_US.UTF-8
# export LC_NUMERIC=en_US.UTF-8
# export LC_TIME=en_US.UTF-8
# export LC_ALL=en_US.UTF-8
# export LESSCHARSET=utf-8

# # Start blinking
# export LESS_TERMCAP_mb=$(tput bold; tput setaf 2) # green
# # Start bold
# export LESS_TERMCAP_md=$(tput bold; tput setaf 2) # green
# # Start stand out
# export LESS_TERMCAP_so=$(tput bold; tput setaf 3) # yellow
# # End standout
# export LESS_TERMCAP_se=$(tput rmso; tput sgr0)
# # Start underline
# export LESS_TERMCAP_us=$(tput smul; tput bold; tput setaf 1) # red
# # End Underline
# export LESS_TERMCAP_ue=$(tput sgr0)
# # End bold, blinking, standout, underline
# export LESS_TERMCAP_me=$(tput sgr0)

# https://github.com/sorin-ionescu/prezto/blob/master/runcoms/zshenv
# Ensure that a non-login, non-interactive shell has a defined environment.
# if [[ ( "$SHLVL" -eq 1 && ! -o LOGIN ) && -s "${ZDOTDIR:-$HOME}/.zprofile" ]]; then
#     source "${ZDOTDIR:-$HOME}/.zprofile"
# fi

# vim: ft=zsh
