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


# Point binaries to the active rustup toolchain THIS MIGHT NEED TO BE CHANGED TO SUPPORT ARCH
#
# Read the default toolchain straight out of rustup's settings.toml instead of asking rustup
# (e.g. via `rustup show active-toolchain`) - resolving the active toolchain is what triggers
# rustup's auto-install of a full toolchain (~1.3GB), and it does this even for a plain `show`
# if $PWD (or an ancestor) has a rust-toolchain.toml override pinning an uninstalled channel.
# `command -v rustup` alone (the old guard here) doesn't help: the binary existing says nothing
# about whether a default toolchain is configured. Skip entirely - no PATH entry, no rustup
# invocation - when none is configured yet.
_rustup_home="${RUSTUP_HOME:-$HOME/.rustup}"
# Prefer an explicit RUSTUP_TOOLCHAIN override when set and its toolchain is installed - cheap,
# zero-risk, no rustup invocation. rust-toolchain.toml directory-level overrides are
# intentionally NOT resolved here: that requires walking up the cwd tree and is exactly the
# auto-install trigger this whole block exists to avoid.
if [[ -n "$RUSTUP_TOOLCHAIN" && -d "$_rustup_home/toolchains/$RUSTUP_TOOLCHAIN/bin" ]]; then
  export PATH="$_rustup_home/toolchains/$RUSTUP_TOOLCHAIN/bin:$PATH"
elif [[ -f "$_rustup_home/settings.toml" ]]; then
  _rustup_default_toolchain="$(sed -n 's/^default_toolchain = "\(.*\)"$/\1/p' "$_rustup_home/settings.toml")"
  if [[ -n "$_rustup_default_toolchain" && -d "$_rustup_home/toolchains/$_rustup_default_toolchain/bin" ]]; then
    export PATH="$_rustup_home/toolchains/$_rustup_default_toolchain/bin:$PATH"
  fi
  unset _rustup_default_toolchain
fi
unset _rustup_home

# Neovim (bob)
if [[ -d "$XDG_DATA_HOME/bob/nvim-bin" ]]; then
  export PATH="$XDG_DATA_HOME/bob/nvim-bin:$PATH"
fi

# Corporate installs move a pre-existing ~/.zshenv aside to ~/.zshenv.local instead of
# overwriting it (see install.sh) so nothing IT-managed is lost. Source it last so it wins on
# any conflicting assignment above.
if [[ -f "$HOME/.zshenv.local" ]]; then
  source "$HOME/.zshenv.local"
fi

