#!/bin/sh

# Summon a workspace onto the focused monitor with a true two-way swap: the
# workspace that was on the focused monitor goes to wherever the target used
# to live. Plain `summon-workspace` doesn't swap - the vacated monitor is
# handed some other workspace by the same "first free" rule that invents
# stray workspaces >= 11 in normalize-workspaces.sh. See
# https://github.com/nikitabobko/AeroSpace/discussions/1962.
#
# One argument: the target workspace. Bound from aerospace.toml's
# ctrl-alt-cmd-* block, one call per binding, e.g.
# summon-workspace-swap.sh 3 or summon-workspace-swap.sh A.
#
# Absolute path required - see normalize-workspaces.sh for why.
#
# Order matters: summon first, then push the previously-focused workspace
# outward. Doing it the other way round leaves the focused monitor
# momentarily workspace-less, which is exactly what triggers AeroSpace to
# invent a stub workspace there. As written, any stub AeroSpace invents
# during the summon ends up empty and is immediately displaced.

AEROSPACE=/opt/homebrew/bin/aerospace

target=$1
[ -n "$target" ] || exit 1

cur=$("$AEROSPACE" list-workspaces --focused)
[ "$cur" = "$target" ] && exit 0

visible=$("$AEROSPACE" list-workspaces --monitor all --visible --format '%{workspace}|%{monitor-id}')
target_mon=""
while IFS='|' read -r ws mon; do
  [ "$ws" = "$target" ] && target_mon=$mon
done <<EOF
$visible
EOF

focused_mon=$("$AEROSPACE" list-monitors --focused --format '%{monitor-id}')

"$AEROSPACE" summon-workspace -- "$target"

# Only if $target was visible on some other monitor: send what *was* here
# over there. If $target wasn't visible anywhere, summon-workspace just
# pulled it in from nowhere and there's nothing to swap back.
if [ -n "$target_mon" ] && [ "$target_mon" != "$focused_mon" ]; then
  "$AEROSPACE" move-workspace-to-monitor --workspace "$cur" -- "$target_mon"
fi
