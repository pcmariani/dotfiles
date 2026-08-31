# ~/.bashrc: executed by bash(1) for non-login shells.

# If not running interactively, don't do anything
case $- in
*i*) ;;
*) return ;;
esac

# Don't allow redirection to overwrite an existing file
set -o noclobber

export TERM=xterm-256color

# Write & read history after every command (reduces problems with multiple terminal sessions)
#PROMPT_COMMAND="history -a; history -n"
export PROMPT_COMMAND='history -a; history -n; echo -ne "\033]0;WSL ${USER}@${HOSTNAME}: ${PWD}\007"'

# only directories will be shown after cd <TAB>
complete -d cd
complete -F _todo do # completion for todo.txt alias do

# Remove the ^S ^Q mappings. See all mappings: stty -a
stty stop undef
stty start undef

# Bash settings
shopt -s cdspell        # Autocorrects cd misspellings
shopt -s checkwinsize   # update the value of LINES and COLUMNS after each command if altered
shopt -s cmdhist        # Save multi-line commands in history as single line
shopt -s dotglob        # Include dotfiles in pathname expansion
shopt -s expand_aliases # Expand aliases
shopt -s extglob        # Enable extended pattern-matching features
#shopt -s histreedit     # Add failed commands to the bash history
shopt -s histappend # Append each session's history to $HISTFILE
shopt -s histverify # Edit a recalled history line before executing

# History settings
export HISTSIZE=10000
export HISTFILESIZE=800000
export HISTIGNORE='pwd:jobs:ll:ls:la:l:fg:history:clear:exit'
export HISTCONTROL=ignoreboth # don't put duplicate lines or lines starting with space in the history.
export HISTCONTROL=$HOME/.config/bash_history
# export HISTTIMEFORMAT='[%F %T] '

# Default programs
export EDITOR=nvim
export VISUAL=nvim
export PAGER='nvim +Man!'
export BROWSER=lynx
# export BROWSER='/mnt/c/Windows/System32/cmd.exe /c "C:\Program Files\Google\Chrome\Application\chrome.exe" '

# To have colors for ls and all grep commands such as grep, egrep and zgrep
export CLICOLOR=1
#export LS_COLORS='no=00:fi=00:di=00;34:ln=01;36:pi=40;33:so=01;35:do=01;35:bd=40;33;01:cd=40;33;01:or=40;31;01:ex=01;32:*.tar=01;31:*.tgz=01;31:*.arj=01;31:*.taz=01;31:*.lzh=01;31:*.zip=01;31:*.z=01;31:*.Z=01;31:*.gz=01;31:*.bz2=01;31:*.deb=01;31:*.rpm=01;31:*.jar=01;31:*.jpg=01;35:*.jpeg=01;35:*.gif=01;35:*.bmp=01;35:*.pbm=01;35:*.pgm=01;35:*.ppm=01;35:*.tga=01;35:*.xbm=01;35:*.xpm=01;35:*.tif=01;35:*.tiff=01;35:*.png=01;35:*.mov=01;35:*.mpg=01;35:*.mpeg=01;35:*.avi=01;35:*.fli=01;35:*.gl=01;35:*.dl=01;35:*.xcf=01;35:*.xwd=01;35:*.ogg=01;35:*.mp3=01;35:*.wav=01;35:*.xml=00;31:'

# If set, the pattern "**" used in a pathname expansion context will
# match all files and zero or more directories and subdirectories.
shopt -s globstar

# Load directory and file colors for GNU ls
[ -f ~/.direcolors ] && eval "$(dircolors -b ~/.dircolors)"

# Sources
[ -f ~/.config/aliases ] && . ~/.config/aliases
[ -f ~/.config/bash_functions ] && . ~/.config/bash_functions
[ -f ~/.config/local_exports ] && . ~/.config/local_exports

# enable programmable completion features (you don't need to enable
# this, if it's already enabled in /etc/bash.bashrc and /etc/profile
# sources /etc/bash.bashrc).
if ! shopt -oq posix; then
	if [ -f /usr/share/bash-completion/bash_completion ]; then
		. /usr/share/bash-completion/bash_completion
	elif [ -f /etc/bash_completion ]; then
		. /etc/bash_completion
	fi
fi

# Doom emacs interop fix
fix_wsl2_interop() {
	for i in $(pstree -np -s $$ | grep -o -E '[0-9]+'); do
		if [[ -e "/run/WSL/${i}_interop" ]]; then
			export WSL_INTEROP=/run/WSL/${i}_interop
		fi
	done
}
~/.emacs.d/bin/doom env >/dev/null 2>&1

# FZF - added by fzf install script: $(brew --prefix)/opt/fzf/install
[ -f ~/.fzf.bash ] && source ~/.fzf.bash

# Starship prompt
eval "$(starship init bash)"
# unset PROMPT_COMMAND

# some bling
# curl wttr.in?0
[ -f ~/scripts/bash-startup.sh ] && ~/scripts/bash-startup.sh
# echo '                                                                   '
# echo '                          - -~- --~<>~---~=<< ♰ >>=~---~<>~-- -~- -'
# echo '                                                                   '
# echo '                             ___   LASCIATE OGNI SPERANZE   ___    '
# echo '                                      VOI CHE ENTRATE              '
# echo '                                                                   '
# echo '                          - -~- --~<>~---~=<< ♰ >>=~---~<>~-- -~- -'
# echo '                                                                   '
#
# echo '                                                                      '
# echo '                       - -- -~- --~<>~---~=<< ♰ >>=~---~<>~-- -~- -- -'
# echo '                                                                      '
# echo '                           ___   ἐμοὶ γὰρ τὸ ζῆν Χριστὸς καὶ   ___    '
# echo '                                     τὸ ἀποθανεῖν κέρδος              '
# echo '                                                                      '
# echo '                       - -- -~- --~<>~---~=<< ♰ >>=~---~<>~-- -~- -- -'
# echo '                                                                      '

# SDKMAN - THIS MUST BE AT THE END OF THE FILE FOR SDKMAN TO WORK!!!
export SDKMAN_DIR="$HOME/.sdkman"
[[ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]] && source "$HOME/.sdkman/bin/sdkman-init.sh"

# Source z
# . $HOME/.local/bin/z.sh

# colored GCC warnings and errors
#export GCC_COLORS='error=01;31:warning=01;35:note=01;36:caret=01;32:locus=01:quote=01'

# XDG
#export HISTFILE="$XDG_CACHE_HOME/bash_history"
#source "$XDG_CONFIG_HOME/bash/completion"
#source "$XDG_CONFIG_HOME/bash/aliases"
#source "$XDG_CONFIG_HOME/bash/themes/current"
#source "$XDG_CONFIG_HOME/bash/utils"
#eval "$(dircolors -b "$XDG_CONFIG_HOME/bash/dircolors")"

# export FZF_DEFAULT_OPTS="
# --multi
# --inline-info
# --layout=reverse
# --height=50%
# --color='fg:7,fg+:48,bg+:-1'
# --preview '([[ -f {} ]] && (pygmentize -O style=monokai -f console256 -g {} || cat {})) || ([[ -d {} ]] && (tree -C {} | less)) || echo {} 2> /dev/null | head -200'
# --preview-window=68%:hidden
# --bind '?:toggle-preview'
# --bind 'ctrl-a:select-all'
# --bind 'ctrl-y:execute-silent(echo {+} | pbcopy)'
# --bind 'ctrl-e:execute(echo {+} | xargs -o vim)'
# --bind 'ctrl-v:execute(code {+})'
# "
#--height=80%
#--color='fg:7,hl:148,hl+:154,pointer:032,marker:010,bg+:237'
#--margin=4%,2%

#export FZF_DEFAULT_COMMAND="rg -i --files --hidden --color=auto --glob '!**/{.git,node_modules}/**'"
# export FZF_DEFAULT_COMMAND="fdfind --type f --hidden --follow --exclude .git --exclude node_modules"
# export FZF_CTRL_T_COMMAND="rg -i --files --hidden --no-ignore-vcs --glob '!*{.git,node_modules}/**'"
# export FZF_ALT_C_COMMAND="fdfind -i --type d --hidden --no-ignore-vcs --exclude node_modules --exclude .git"

# . /usr/share/doc/fzf/examples/key-bindings.bash

# vim: set ft=sh ts=4 sw=4 tw=80 noet :
