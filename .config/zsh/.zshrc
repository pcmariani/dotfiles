# some opts
setopt menucomplete
setopt interactivecomments # Comments in the interactive shell
unsetopt listtypes # removes / from directories

# Changing directories
setopt autocd
setopt globdots
setopt auto_pushd
setopt pushd_ignore_dups
setopt pushd_silent

# History
export HISTFILE="$ZDOTDIR/.zhistory"
export HISTSIZE=1000000
export SAVEHIST=1000000
setopt inc_append_history # add commands to HISTFILE in order of execution
setopt share_history # share command history data
setopt hist_expire_dups_first # delete duplicates first when HISTFILE size exceeds HISTSIZE
setopt hist_find_no_dups # don't display duplicates in reverse search
setopt hist_reduce_blanks # remove superfluous blanks
setopt hist_ignore_space # ignore commands that start with space
setopt hist_ignore_dups # Don't add duplicate entries
setopt hist_verify # show command with history expansion to user before running it

# Sources
source $(brew --prefix)/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
source $(brew --prefix)/share/zsh-autosuggestions/zsh-autosuggestions.zsh
source $(brew --prefix)/share/zsh-vi-mode/zsh-vi-mode.zsh
source $(brew --prefix)/share/zsh-autopair/autopair.zsh
source "$ZDOTDIR/zsh-functions"
source "$ZDOTDIR/zsh-aliases"

# Completion
autoload -Uz compinit
zmodload zsh/complist
compinit
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list '' 'm:{a-zA-Z}={A-Za-z}' 'r:|[._-]=* r:|=*' 'l:|=* r:|=*'
export LS_COLORS='no=00;37:fi=00:di=00;33:ln=04;36:pi=40;33:so=01;35:bd=40;33;01:'
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
bindkey -M menuselect '\e' send-break
bindkey -M menuselect 'h' vi-backward-char
bindkey -M menuselect 'k' vi-up-line-or-history
bindkey -M menuselect 'l' vi-forward-char
bindkey -M menuselect 'j' vi-down-line-or-history

# do ls after cd
function chpwd() {
    emulate -L zsh
    ls -a
}

# Edit line in vim with ctrl-e:
autoload edit-command-line
zle -N edit-command-line
bindkey '^e' edit-command-line

# eliminates duplicates in *paths
typeset -gU cdpath fpath path



# ---- FZF -----

# Set up fzf key bindings and fuzzy completion
eval "$(fzf --zsh)"

# -- setup fzf theme --
# fg="#CBE0F0"
# bg="#011628"
# bg_highlight="#143652"
# purple="#B388FF"
# blue="#06BCE4"
# cyan="#2CF9ED"

# export FZF_DEFAULT_OPTS="--color=fg:${fg},bg:${bg},hl:${purple},fg+:${fg},bg+:${bg_highlight},hl+:${purple},info:${blue},prompt:${cyan},pointer:${cyan},marker:${cyan},spinner:${cyan},header:${cyan}"

# -- Use fd instead of fzf --

export FZF_DEFAULT_COMMAND="fd --hidden --strip-cwd-prefix --exclude .git"
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_ALT_C_COMMAND="fd --type=d --hidden --strip-cwd-prefix --exclude .git"

# Use fd (https://github.com/sharkdp/fd) for listing path candidates.
# - The first argument to the function ($1) is the base path to start traversal
# - See the source code (completion.{bash,zsh}) for the details.
_fzf_compgen_path() {
  fd --hidden --exclude .git . "$1"
}

# Use fd to generate the list for directory completion
_fzf_compgen_dir() {
  fd --type=d --hidden --exclude .git . "$1"
}

# untangle fzf with zsh-vi-mode
zvm_after_init_commands+=('[ -f $HOME/.fzf.zsh ] && source $HOME/.fzf.zsh')
# source ~/fzf-git.sh/fzf-git.sh


show_file_or_dir_preview="if [ -d {} ]; then eza --tree --color=always {} | head -200; else bat -n --color=always --line-range :500 {}; fi"

export FZF_CTRL_T_OPTS="--preview '$show_file_or_dir_preview'"
export FZF_ALT_C_OPTS="--preview 'eza --tree --color=always {} | head -200'"

# Advanced customization of fzf options via _fzf_comprun function
# - The first argument to the function is the name of the command.
# - You should make sure to pass the rest of the arguments to fzf.
_fzf_comprun() {
  local command=$1
  shift

  case "$command" in
    cd)           fzf --preview 'eza --tree --color=always {} | head -200' "$@" ;;
    export|unset) fzf --preview "eval 'echo \${}'"         "$@" ;;
    ssh)          fzf --preview 'dig {}'                   "$@" ;;
    *)            fzf --preview "$show_file_or_dir_preview" "$@" ;;
  esac
}

# --- Sesh ---
zle     -N             sesh-sessions
bindkey -M emacs '\es' sesh-sessions
bindkey -M vicmd '\es' sesh-sessions
bindkey -M viins '\es' sesh-sessions


# ---- Bat (better cat) ----

# export BAT_THEME=tokyonight_night

# ---- Eza (better ls) -----

# alias ls="eza --icons=always"

# # ---- Zoxide (better cd) ----

eval "$(zoxide init zsh)"
alias cd="z"

# ---- Yazi ----

function y() {
	local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
	yazi "$@" --cwd-file="$tmp"
	if cwd="$(command cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
		builtin cd -- "$cwd"
	fi
	rm -f -- "$tmp"
}

# ---- Starship ----
eval "$(starship init zsh)"

# ---- SDKMAN - THIS MUST BE AT THE END OF THE FILE FOR SDKMAN TO WORK!!! ----
export SDKMAN_DIR="$HOME/.sdkman"
[[ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]] && source "$HOME/.sdkman/bin/sdkman-init.sh"







# ---- VIM MODE (OLD) ----

# # Edit line in vim with ctrl-e:
# autoload edit-command-line
# zle -N edit-command-line
# bindkey '^e' edit-command-line
#
# bindkey -v # vim mode
# export KEYTIMEOUT=1 # Reduces delay when entering vi-mode
#
# # Change cursor shape for different vi modes.
# function zle-keymap-select () {
#     case $KEYMAP in
#         vicmd) echo -ne '\e[1 q';;      # block
#         viins|main) echo -ne '\e[5 q';; # beam
#     esac
# }
# zle -N zle-keymap-select
# zle-line-init() {
#     zle -K viins # initiate `vi insert` as keymap (can be removed if `bindkey -V` has been set elsewhere)
#     # echo -ne "\e[5 q"
#     echo -ne "\e[1 q"
# }
# zle -N zle-line-init
# # echo -ne '\e[5 q' # Use beam shape cursor on startup.
# # preexec() { echo -ne '\e[5 q' ;} # Use beam shape cursor for each new prompt.


# vim: ft=zsh

