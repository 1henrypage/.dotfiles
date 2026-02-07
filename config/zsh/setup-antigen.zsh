#!/usr/bin/env zsh

# Directories
zsh_dir=${XDG_CONFIG_HOME:-$HOME/.config}/zsh
antigen_dir=${ADOTDIR:-${XDG_DATA_HOME:-$HOME/.local/share}/zsh/antigen}
antigen_git="https://raw.githubusercontent.com/zsh-users/antigen/master/bin/antigen.zsh"
antigen_bin="${antigen_dir}/antigen.zsh"

# Install Antigen if missing
if [[ ! -f $antigen_bin ]]; then
  if read -q "choice?Antigen not found. Install it now? (y/N) "; then
    echo
    mkdir -p "$antigen_dir"
    curl -L "$antigen_git" -o "$antigen_bin"
  fi
fi

# Source Antigen if it exists
[[ -f $antigen_bin ]] && source "$antigen_bin"

# Load bundles
antigen bundle zsh-users/zsh-syntax-highlighting
antigen bundle zsh-users/zsh-completions
antigen bundle zsh-users/zsh-autosuggestions
antigen bundle supercrabtree/k
antigen bundle 1henrypage/zsh-treehouse

# Apply Antigen
antigen apply

