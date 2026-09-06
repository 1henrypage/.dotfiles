#!/bin/sh
# Claude Code hook -> tmux pane-option bridge. Single entry point, dispatched by $1:
#   SessionStart/SessionEnd -> "idle"   UserPromptSubmit -> "working"
#   PermissionRequest       -> "blocked"  Stop            -> "done"
# See tmux.conf's status-line section for the format side of this contract: it reads
# @claude_state / @claude_start / @claude_project back with zero forks.
#
# Hooks inherit whatever environment Claude Code itself started with, not a login shell
# (same class of problem config/aerospace/window-picker.sh solves) - so PATH may be minimal
# even though this machine normally has tmux on PATH already.

state="$1"
[ -n "$state" ] || exit 0
[ -n "$TMUX" ] || exit 0
[ -n "$TMUX_PANE" ] || exit 0

tmux_bin=$(command -v tmux 2>/dev/null)
if [ -z "$tmux_bin" ]; then
  for candidate in /opt/homebrew/bin/tmux /usr/local/bin/tmux /usr/bin/tmux; do
    if [ -x "$candidate" ]; then
      tmux_bin="$candidate"
      break
    fi
  done
fi
[ -n "$tmux_bin" ] || exit 0

input=$(cat)

project=""
if command -v jq >/dev/null 2>&1; then
  cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)
  if [ -n "$cwd" ]; then
    root=$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null)
    [ -n "$root" ] || root="$cwd"
    project=$(basename "$root")
  fi
fi

"$tmux_bin" set -p -t "$TMUX_PANE" @claude_state "$state" >/dev/null 2>&1
[ -n "$project" ] && "$tmux_bin" set -p -t "$TMUX_PANE" @claude_project "$project" >/dev/null 2>&1

case "$state" in
working)
  "$tmux_bin" set -p -t "$TMUX_PANE" @claude_start "$(date +%s)" >/dev/null 2>&1
  ;;
done|idle)
  "$tmux_bin" set -pu -t "$TMUX_PANE" @claude_start >/dev/null 2>&1
  ;;
blocked)
  # Only notify when the requesting window isn't the one you're looking at - with several
  # concurrent Claude sessions, notifying on every permission prompt would just spam.
  active=$("$tmux_bin" display-message -p -t "$TMUX_PANE" '#{window_active}' 2>/dev/null)
  if [ "$active" != "1" ]; then
    tool=""
    command -v jq >/dev/null 2>&1 && tool=$(printf '%s' "$input" | jq -r '.tool_name // empty' 2>/dev/null)
    label="${project:-Claude Code}"
    if [ -n "$tool" ]; then
      message="${label} wants to run ${tool}"
    else
      message="${label} needs your attention"
    fi
    hook_dir=$(cd "$(dirname "$0")" && pwd)
    "$hook_dir/notify.sh" "Claude Code" "$message" >/dev/null 2>&1
  fi
  ;;
esac

# refresh-client's implicit "current client" targeting only applies when bound to a key;
# a hook has no client context, so refresh every attached client explicitly instead of
# relying on that fallback. Cheap even with several clients; a no-op badge update would
# otherwise just wait for the next status-interval tick (5s) instead of showing instantly.
"$tmux_bin" list-clients -F '#{client_name}' 2>/dev/null | while IFS= read -r client; do
  "$tmux_bin" refresh-client -S -t "$client" >/dev/null 2>&1
done

exit 0
