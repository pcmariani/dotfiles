typeset -U path

path=(
  "/opt/homebrew/bin"
  "/opt/homebrew/sbin"
  "$HOME/.local/bin"
  "$HOME/scripts"
  "$HOME/.cargo/bin"
  "$HOME/projects/boomi-groovy-2"
  "$path[@]"
)

export ZDOTDIR=$HOME/.config/zsh
export BOOMI_GROOVY_HOME=$HOME/projects/boomi-groovy-2/
export RIPGREP_CONFIG_PATH=$HOME/.config/.ripgreprc
export EDITOR="nvim"
export VISUAL="nvim"
export BROWSER="lynx"
export MANPAGER='nvim +Man!'
