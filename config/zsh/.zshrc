
zsh_dir=${${ZDOTDIR}:-$HOME/.config/zsh}

if [[ $- != *i* ]]; then
    echo "Non-interactive execution not permitted" >&2
    return 1
fi

# macOS /etc/zprofile runs path_helper, which rebuilds PATH from /etc/paths and pushes
# /opt/homebrew/bin behind /usr/bin - undoing .zshenv's prepend for every login shell. Re-assert
# it here, since .zshrc runs after .zprofile. Without this, `env bash` finds Apple's bash 3.2,
# whose lack of associative arrays makes tokyo-night-tmux collapse every theme color to one
# orange. The -d guard makes this a no-op anywhere without Homebrew (e.g. Arch), and Intel macs
# need no fix at all since path_helper already puts /usr/local/bin first.
if [[ -d /opt/homebrew/bin ]]; then
  typeset -U path          # dedupe, keeping the first occurrence
  path=(/opt/homebrew/bin $path)
fi

# kitty is purely a tmux frontend (see .claude/ARCHITECTURE.md): its tab/window keys are no_op'd
# because tmux owns all window management. kitty runs the login shell, so tmux is resolved from
# the real login PATH rather than an absolute path, which is what makes this work on any OS.
# Guards: $TMUX prevents recursion (KITTY_WINDOW_ID is inherited into panes, so it cannot be the
# recursion guard); command -v degrades to a plain shell if tmux is missing, rather than leaving
# a terminal that will not open.
if [[ -n "$KITTY_WINDOW_ID" && -z "$TMUX" ]] && command -v tmux > /dev/null; then
  exec tmux
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

