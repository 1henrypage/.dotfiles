
zsh_dir=${${ZDOTDIR}:-$HOME/.config/zsh}

if [[ $- != *i* ]]; then
    echo "Non-interactive execution not permitted" >&2
    return 1
fi


if [[ -d $zsh_dir ]]; then
  # Source all alias files
  for file in "$zsh_dir"/aliases/*.zsh; do
    [[ -f $file ]] && source "$file"
  done
  
  # Setup Antigen
  source ${zsh_dir}/setup-antigen.zsh
  
  # Source all lib files
  for file in "$zsh_dir"/lib/*.zsh; do
    [[ -f $file ]] && source "$file"
  done
fi

eval "$(zoxide init zsh)"
eval "$(starship init zsh)"
eval "$(jenv init -)"

# Corporate installs move a pre-existing ~/.zshrc aside to ~/.zshrc.local instead of
# overwriting it (see install.sh) so nothing IT-managed is lost. Source it last so it wins on
# any conflicting assignment above.
if [[ -f "$HOME/.zshrc.local" ]]; then
  source "$HOME/.zshrc.local"
fi

