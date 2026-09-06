#!/bin/sh
# Battery widget for tmux status-right. TTL-cached, no GNU coreutils, no `brew --prefix`
# (see ARCHITECTURE.md for why the old tokyo-night-tmux widget forked that unconditionally).
# bash 3.2-safe by construction: this is /bin/sh, not bash.

CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/tmux-statusbar"
CACHE_FILE="$CACHE_DIR/battery"
TTL=30

mtime() {
  stat -f %m "$1" 2>/dev/null || stat -c %Y "$1" 2>/dev/null
}

mkdir -p "$CACHE_DIR"

if [ -f "$CACHE_FILE" ]; then
  now=$(date +%s)
  cached_at=$(mtime "$CACHE_FILE")
  age=$((now - cached_at))
  if [ "$age" -lt "$TTL" ] 2>/dev/null; then
    cat "$CACHE_FILE"
    exit 0
  fi
fi

# nerd-font battery ramp, 10%-100% (flat/minimalist, not an emoji) - verified against
# FantasqueSansMNerdFontMono's cmap.
ramp="󰁺 󰁻 󰁼 󰁽 󰁾 󰁿 󰂀 󰂁 󰂂 󰁹"

case "$(uname)" in
Darwin)
  line=$(pmset -g batt | grep -m1 'InternalBattery')
  [ -n "$line" ] || exit 0
  pct=$(printf '%s\n' "$line" | awk -F'[\t;]' '{print $2}' | tr -dc '0-9')
  ;;
Linux)
  bat_dir=$(printf '%s\n' /sys/class/power_supply/BAT*/ 2>/dev/null | head -n1)
  [ -d "$bat_dir" ] || exit 0
  pct=$(cat "${bat_dir}capacity" 2>/dev/null)
  ;;
*)
  exit 0
  ;;
esac

[ -n "$pct" ] || exit 0

idx=$((pct / 10))
[ "$idx" -gt 9 ] && idx=9
icon=$(printf '%s' "$ramp" | awk -v i="$idx" '{print $(i+1)}')

if [ "$pct" -lt 20 ] 2>/dev/null; then
  color="#f7768e"
else
  color="#73daca"
fi

out="#[fg=${color}]${icon} ${pct}%#[fg=#a9b1d6]"
printf '%s' "$out" >"$CACHE_FILE"
printf '%s' "$out"
