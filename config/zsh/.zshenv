# ~/.zhsenv
# stolen from github.com/Lissy93/dotfiles
# Core environmental variables

# Set XDG directories
export XDG_CONFIG_HOME="${HOME}/.config"
export XDG_DATA_HOME="${HOME}/.local/share"
export XDG_BIN_HOME="${HOME}/.local/bin"
export XDG_LIB_HOME="${HOME}/.local/lib"
export XDG_CACHE_HOME="${HOME}/.cache"

# Set default applications
export EDITOR="vim"
export VISUAL="vim"
export TERMINAL="kitty"
export BROWSER="firefox"

## Respect XDG directories
export ADOTDIR="${XDG_CACHE_HOME}/zsh/antigen"
export TMUX_CONF="${XDG_CONFIG_HOME}/tmux/tmux.conf"
export CARGO_HOME="${XDG_DATA_HOME}/cargo"
export CURL_HOME="${XDG_CONFIG_HOME}/curl"
export DOCKER_CONFIG="${XDG_CONFIG_HOME}/docker"
export TMUX_PLUGIN_MANAGER_PATH="${XDG_DATA_HOME}/tmux/plugins"


export LANG='en_US.UTF-8'
export LC_ALL='en_US.UTF-8'
export PYTHONIOENCODING='UTF-8'

# User Binaries
if [[ -d "$XDG_BIN_HOME" ]]; then
  export PATH="$XDG_BIN_HOME:$PATH"
fi

# MacOS-specific services
if [ "$(uname -s)" = "Darwin" ]; then
  # Add Brew to path, if it's installed
  if [[ -d /opt/homebrew/bin ]]; then
    export PATH=/opt/homebrew/bin:$PATH
  fi
fi


# Rust / Cargo
if [[ -d "$CARGO_HOME/bin" ]]; then
  export PATH="$CARGO_HOME/bin:$PATH"
fi


# Point binaries to brew THIS MIGHT NEED TO BE CHANGED TO SUPPORT ARCH
export PATH="$HOME/.rustup/toolchains/$(rustup show active-toolchain | cut -d' ' -f1)/bin:$PATH"

#if command -v rustup >/dev/null 2>&1; then
#fi

# Neovim (bob)
if [[ -d "$XDG_DATA_HOME/bob/nvim-bin" ]]; then
  export PATH="$XDG_DATA_HOME/bob/nvim-bin:$PATH"
fi





