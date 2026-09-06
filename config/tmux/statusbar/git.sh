#!/bin/sh
# Git widget for tmux status-right: branch + dirty file count only. No `git fetch`, no
# `git log @{push}..`, no `git ls-files` - this widget never touches the network (see
# ARCHITECTURE.md for why the old tokyo-night-tmux git-status.sh did, silently, every 5min).
# TTL-cached per repo. bash 3.2-safe by construction: this is /bin/sh, not bash.

DIR="${1:-$PWD}"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/tmux-statusbar"
TTL=3

mtime() {
  stat -f %m "$1" 2>/dev/null || stat -c %Y "$1" 2>/dev/null
}

mkdir -p "$CACHE_DIR"

cd "$DIR" 2>/dev/null || exit 0
toplevel=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0

key=$(printf '%s' "$toplevel" | cksum | awk '{print $1}')
cache_file="$CACHE_DIR/git-$key"

if [ -f "$cache_file" ]; then
  now=$(date +%s)
  cached_at=$(mtime "$cache_file")
  age=$((now - cached_at))
  if [ "$age" -lt "$TTL" ] 2>/dev/null; then
    cat "$cache_file"
    exit 0
  fi
fi

branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
[ -n "$branch" ] || exit 0
if [ ${#branch} -gt 25 ]; then
  branch="$(printf '%s' "$branch" | cut -c1-25)…"
fi

dirty=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')

# nerd-font branch glyph (flat/minimalist, not an emoji) - verified against
# FantasqueSansMNerdFontMono's cmap.
if [ "$dirty" -gt 0 ] 2>/dev/null; then
  out="#[fg=#bb9af7] ${branch} #[fg=#e0af68]±${dirty}#[fg=#a9b1d6]"
else
  out="#[fg=#bb9af7] ${branch}#[fg=#a9b1d6]"
fi

printf '%s' "$out" >"$cache_file"
printf '%s' "$out"
