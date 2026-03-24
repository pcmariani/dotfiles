typeset -U path

export ZDOTDIR=$HOME/.config/zsh
export BOOMI_GROOVY_HOME=$HOME/projects/best/
export RIPGREP_CONFIG_PATH=$HOME/.config/.ripgreprc
export EDITOR="nvim"
export VISUAL="nvim"
export BROWSER="lynx"
export MANPAGER='nvim +Man!'
# export NODE_EXTRA_CA_CERTS="/opt/homebrew/etc/ca-certificates/cert.pem"
export NODE_EXTRA_CA_CERTS="$HOME/.certs/zscaler_root.pem"

path=(
  "/opt/homebrew/bin"
  "/opt/homebrew/sbin"
  "$HOME/.local/bin"
  "$HOME/scripts"
  "$HOME/.cargo/bin"
  "$HOME/projects/best"
  "$path[@]"
)
