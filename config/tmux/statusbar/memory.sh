#!/bin/sh
# Memory-usage widget for tmux status-right. TTL-cached. bash 3.2-safe: this is /bin/sh.
# macOS has no single "used %" figure (like Activity Monitor, treats free+inactive as
# available); Linux's /proc/meminfo already gives that directly via MemAvailable.

CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/tmux-statusbar"
CACHE_FILE="$CACHE_DIR/memory"
TTL=10

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

case "$(uname)" in
Darwin)
  total=$(sysctl -n hw.memsize)
  page_size=$(vm_stat | awk -F'[^0-9]+' 'NR==1{print $2}')
  free_pages=$(vm_stat | awk '/Pages free/{gsub(/\./,"",$3); print $3}')
  inactive_pages=$(vm_stat | awk '/Pages inactive/{gsub(/\./,"",$3); print $3}')
  [ -n "$total" ] && [ -n "$page_size" ] && [ -n "$free_pages" ] && [ -n "$inactive_pages" ] || exit 0
  avail=$(((free_pages + inactive_pages) * page_size))
  pct=$(((total - avail) * 100 / total))
  ;;
Linux)
  [ -r /proc/meminfo ] || exit 0
  total=$(awk '/^MemTotal:/{print $2}' /proc/meminfo)
  avail=$(awk '/^MemAvailable:/{print $2}' /proc/meminfo)
  [ -n "$total" ] && [ -n "$avail" ] || exit 0
  pct=$(((total - avail) * 100 / total))
  ;;
*)
  exit 0
  ;;
esac

out="󰍛 ${pct}%"
printf '%s' "$out" >"$CACHE_FILE"
printf '%s' "$out"
