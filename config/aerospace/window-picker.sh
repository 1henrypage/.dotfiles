#!/bin/sh

# Fuzzy-pick any window on any workspace and focus it. Bound to ctrl-alt-space
# in aerospace.toml, which launches this inside its own kitty window.
#
# kitty runs this script directly rather than through a login shell, so none of
# .zshenv/.zshrc applies and PATH is minimal. Every binary is therefore called
# by absolute path - same class of bug as the borders daemon in aerospace.toml.

AEROSPACE=/opt/homebrew/bin/aerospace
FZF=/opt/homebrew/bin/fzf

sel=$("$AEROSPACE" list-windows --all \
        --format '%{window-id}%{right-padding}| %{app-name} - %{window-title}' \
      | "$FZF" --reverse --height=100% --prompt='window> ') || exit 0

[ -n "$sel" ] || exit 0

# Strip the right-padding as well as the delimiter.
id=$(printf '%s' "$sel" | cut -d'|' -f1 | tr -d '[:space:]')
[ -n "$id" ] || exit 0

exec "$AEROSPACE" focus --window-id "$id"
