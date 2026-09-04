typeset -gU cdpath fpath path
autoload -Uz add-zsh-hook

# ----- opts -----

setopt menucomplete
setopt interactivecomments # Comments in the interactive shell
setopt autocd # Changing directories
setopt globdots
setopt auto_pushd
setopt pushd_ignore_dups
setopt pushd_silent
unsetopt listtypes # removes / from directories

# History
export HISTFILE="$ZDOTDIR/.zhistory"
export HISTSIZE=10000
export SAVEHIST=10000
setopt hist_expire_dups_first # delete duplicates first when HISTFILE size exceeds HISTSIZE
setopt hist_ignore_dups # Don't add duplicate entries
setopt hist_ignore_all_dups # Don't add duplicate entries
setopt hist_ignore_space # ignore commands that start with space
setopt hist_save_no_dups # don't write duplicates to history file
setopt hist_reduce_blanks # remove superfluous blanks
setopt hist_find_no_dups # don't display duplicates in reverse search
setopt hist_verify # show command with history expansion to user before running it
setopt share_history # share command history data

# ----- sources -----

source "$ZDOTDIR/zsh-functions"
source "$ZDOTDIR/aliases"
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

# ----- mise -----

eval "$(mise activate zsh)"

# ----- zoxide -----

eval "$(zoxide init zsh)"

# ---- starship ----

eval "$(starship init zsh)"


# ----- stale agent session env -----

# A window opened from inside a Claude Code session used to inherit that
# session's whole CLAUDE_* block, CLAUDE_CODE_CHILD_SESSION=1 included. A
# `claude` that believes it is a child session writes NO transcript, so
# `claude -c` in that window answers "no conversation found" and the
# conversation is simply gone -- for the life of the window, long after the
# session that spawned it died. Measured 2026-09-04, and isolated to that one
# variable by experiment: CLAUDECODE=1 and a stale CLAUDE_PID are both
# harmless on their own.
#
# The launcher that leaked it is fixed (context-based-mac, context/childenv.py),
# but windows opened BEFORE that fix keep the bad block until they are
# relaunched. This repairs new shells in them.
#
# Only when the owning session is really gone: a `claude` started from inside
# a live session's tool call IS nested and must keep the flag. Checking the
# pid is alive is not enough -- pids get recycled -- so the process has to
# still be a claude.
# >>> stale-agent-env guard >>>
if [[ -n "$CLAUDE_CODE_CHILD_SESSION" ]]; then
  _stale_agent_env=1
  if [[ -n "$CLAUDE_PID" ]] && kill -0 "$CLAUDE_PID" 2>/dev/null; then
    if [[ "$(ps -o comm= -p "$CLAUDE_PID" 2>/dev/null)" == *claude* ]]; then
      _stale_agent_env=0
    fi
  fi
  if (( _stale_agent_env )); then
    unset CLAUDECODE CLAUDE_CODE_CHILD_SESSION CLAUDE_PID CLAUDE_CODE_SESSION_ID \
          CLAUDE_CODE_ENTRYPOINT CLAUDE_CODE_EXECPATH CLAUDE_CODE_MESSAGING_SOCKET \
          CLAUDE_CODE_MESSAGING_TOKEN CLAUDE_EFFORT AI_AGENT
  fi
  unset _stale_agent_env
fi
# <<< stale-agent-env guard <<<

# gpg-agent draws its passphrase prompt on a terminal it has to be told about.
# Without this, anything that pipes data to gpg on stdin -- `yadm encrypt`
# being the one that bites -- fails with:
#   gpg: problem with the agent: Inappropriate ioctl for device
# Guarded, so a non-tty shell neither pays for `tty` nor exports "not a tty".
if [[ -o interactive ]] && tty -s; then
  export GPG_TTY="$(tty)"
fi
