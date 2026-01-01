
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

# Add Zoxide (for cd, quick jump) to shell
if hash zoxide 2> /dev/null; then
    eval "$(zoxide init zsh)"
fi

# Add starship 
if hash starship 2> /dev/null; then
   eval "$(starship init zsh)"
fi






