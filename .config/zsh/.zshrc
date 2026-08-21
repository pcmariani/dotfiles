typeset -gU cdpath fpath path
autoload -Uz add-zsh-hook

# ----- opts -----

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

# ----- env -----

export BOOMI_GROOVY_HOME="$HOME/projects/best/"
export RIPGREP_CONFIG_PATH="$HOME/.config/.ripgreprc"
export EDITOR="nvim"
export VISUAL="nvim"
export BROWSER="lynx"
export MANPAGER='nvim +Man!'
export NODE_EXTRA_CA_CERTS="$HOME/.certs/zscaler_root.pem"
export BW_SERVER="http://localhost:8087"

path=(
  "/opt/homebrew/bin"
  "/opt/homebrew/sbin"
  "$HOME/.local/bin"
  "$HOME/scripts"
  "$HOME/.cargo/bin"
  "$HOME/projects/best"
  "$path[@]"
)

eval "$(mise activate zsh)"

# ----- sources -----

source "$ZDOTDIR/zsh-functions"
source "$HOME/.config/aliases"
source /opt/homebrew/share/zsh-vi-mode/zsh-vi-mode.zsh
source /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh
source /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# ----- completion -----

autoload -Uz compinit
zmodload zsh/complist
compinit -C  # skip re-validation for faster startup; run 'compinit' to refresh
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list '' 'm:{a-zA-Z}={A-Za-z}' 'r:|[._-]=* r:|=*' 'l:|=* r:|=*'
export LS_COLORS='no=00;37:fi=00:di=00;33:ln=04;36:pi=40;33:so=01;35:bd=40;33;01:'
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
bindkey -M menuselect '\e' send-break
bindkey -M menuselect 'h' vi-backward-char
bindkey -M menuselect 'k' vi-up-line-or-history
bindkey -M menuselect 'l' vi-forward-char
bindkey -M menuselect 'j' vi-down-line-or-history
source "$ZDOTDIR/zsh-completions"

# Edit line in vim with ctrl-e:
autoload edit-command-line
zle -N edit-command-line
bindkey '^e' edit-command-line

# ---- fzf -----

# Set up fzf key bindings and fuzzy completion after zsh-vi-mode initializes
zvm_after_init_commands+=( 'eval "$(fzf --zsh)"' )

# Use fd instead of fzf
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

# ----- hooks -----

# herdr
if [[ -n "$HERDR_TAB_ID" ]]; then
  herdr_rename_tab() {
    herdr tab rename "$HERDR_TAB_ID" "$(basename "$PWD")" >/dev/null 2>&1
  }
  add-zsh-hook chpwd herdr_rename_tab
  herdr_rename_tab  # set it on shell start too
fi

# ls after cd
_ls_after_cd() {
    ls -a
}
add-zsh-hook chpwd _ls_after_cd

# ----- zoxide -----

eval "$(zoxide init zsh)"

# ---- starship ----

eval "$(starship init zsh)"

