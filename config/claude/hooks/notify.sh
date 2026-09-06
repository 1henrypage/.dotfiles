#!/bin/sh
# Cross-platform desktop notification: notify.sh [title] [message].
# Called by claude-tmux-state.sh on the "blocked" state, only when the requesting tmux
# window isn't focused. Exits 0 silently if no notifier is available - a missing notifier
# must never fail the hook that called this.

title="${1:-Claude Code}"
message="${2:-Claude Code needs your attention}"

osa_escape() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

case "$(uname)" in
Darwin)
  esc_title=$(osa_escape "$title")
  esc_message=$(osa_escape "$message")
  osascript -e "display notification \"${esc_message}\" with title \"${esc_title}\"" >/dev/null 2>&1
  ;;
Linux)
  if command -v notify-send >/dev/null 2>&1; then
    notify-send "$title" "$message" >/dev/null 2>&1
  elif command -v dunstify >/dev/null 2>&1; then
    dunstify "$title" "$message" >/dev/null 2>&1
  fi
  ;;
esac

exit 0
