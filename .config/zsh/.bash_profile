# vim: ft=sh

# the default umask is set in /etc/profile; for setting the umask
# for ssh logins, install and configure the libpam-umask package.
umask 022 # sets default permissions: folders 755, files 644

# so Perl doesn't throw an error
export LANGUAGE=en_US.UTF-8

# if running bash
if [ -n "$BASH_VERSION" ]; then
	# include .bashrc if it exists
	if [ -f "$HOME/.bashrc" ]; then
		. "$HOME/.bashrc"
	fi
fi

# boomi
export BOOMI_HOME="$HOME/projects/boomi-groovy-2/"

# for Homebrew - Needs to be before PATH
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"

# PATH Additions
[ -d "$HOME/bin" ] && PATH="$PATH:$HOME/bin"
[ -d "$HOME/.local/bin" ] && PATH="$PATH:$HOME/.local/bin"
[ -d "$HOME/.emacs.d/bin" ] && PATH="$PATH:$HOME/.emacs.d/bin"
[ -d "$HOME/.local/bin/neovim/bin" ] && PATH="$PATH:$HOME/.local/bin/neovim/bin"

# wsl
if [[ -n "$WSL_DISTRO_NAME" ]]; then
	# For Xwindows
	# export DISPLAY=:0
	# export DISPLAY=$(cat /etc/resolv.conf | grep nameserver | awk '{print $2; exit;}'):0.0
	export DISPLAY=$(ip route | awk '{print $3; exit}'):0
	export LIBGL_ALWAYS_INDIRECT=1
	export GDK_SCALE=0.5
	export GDK_DPI_SCALE=2
	#sudo /etc/init.d/dbus start &> /dev/null

	# windows pulse server
	export PULSE_SERVER=tcp:127.0.0.1

	# remove windows dirs with lots of items which slow down completion
	PATH=$(echo "$PATH" | sed 's|:/mnt/c/WINDOWS:|:|')
	PATH=$(echo "$PATH" | sed 's|:/mnt/c/WINDOWS/system32:|:|')
fi

# Add completion for github cli
eval "$(gh completion -s bash)"

#THIS MUST BE AT THE END OF THE FILE FOR SDKMAN TO WORK!!!
export SDKMAN_DIR="/Users/petermariani/.sdkman"
[[ -s "/Users/petermariani/.sdkman/bin/sdkman-init.sh" ]] && source "/Users/petermariani/.sdkman/bin/sdkman-init.sh"
