#!/usr/bin/env bash
set -euo pipefail

pane_id="${1:-}"
cwd="${2:-$HOME}"
plans_dir="$HOME/.claude/plans"

# 1) Read the plan path straight from the pane's visible TUI footer.
plan=""
if [ -n "$pane_id" ]; then
  plan="$(tmux capture-pane -p -t "$pane_id" 2>/dev/null \
    | grep -oE '[^[:space:]]*\.claude/plans/[^[:space:]]+\.md' \
    | tail -n 1 || true)"
fi

# Expand a leading ~ (the footer prints ~/.claude/...).
case "$plan" in
  "~/"*) plan="$HOME/${plan#\~/}" ;;
esac

# 2) Fallback: newest plan file (slug filenames have no spaces/newlines, so ls is safe).
if [ -z "$plan" ] || [ ! -f "$plan" ]; then
  plan="$(ls -t "$plans_dir"/*.md 2>/dev/null | head -n 1 || true)"
fi

# 3) Nothing found -> tell the user in the status line, don't spawn an empty nvim.
if [ -z "$plan" ] || [ ! -f "$plan" ]; then
  tmux display-message "open-plan: no plan file found in $plans_dir"
  exit 0
fi

# 4) Open in a new, cwd-aware window named 'plan'.
tmux new-window -c "$cwd" -n plan "nvim '$plan'"
