zsh_dir=${XDG_CONFIG_HOME:-$HOME/.config}/zsh
antigen_dir=${ADOTDIR:-$XDG_DATA_HOME/zsh/antigen}
antigen_git="https://raw.githubusercontent.com/zsh-users/antigen/master/bin/antigen.zsh"
antigen_bin="${ADOTDIR}/antigen.zsh"

# Install Antigen if missing
if [[ ! -f $antigen_bin ]]; then
  if read -q "choice?Would you like to install Antigen now? (y/N)"; then
    echo
    mkdir -p "$antigen_dir"
    curl -L "$antigen_git" > "$antigen_bin"
  fi
fi

# Source Antigen if it exists
[[ -f $antigen_bin ]] && source "$antigen_bin"

# Set the ZSH prompt


