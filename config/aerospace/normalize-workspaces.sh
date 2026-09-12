#!/bin/sh

# Evicts any workspace outside the bound ctrl-alt-* set (see aerospace.toml's
# MODIFIER LAYER CONTRACT) from whatever monitor is showing it.
#
# AeroSpace requires each monitor to show a *distinct* visible workspace, and
# has no config option that caps the workspace list. So once every configured
# workspace is already owned by some monitor, attaching another one makes
# AeroSpace materialise workspace 11, 12, ... - permanently unreachable, since
# no binding names them. Upstream: https://github.com/nikitabobko/AeroSpace/issues/651,
# closed with no fix. This script is the only thing standing between that and
# a stuck workspace: delete it and workspace 11 comes back next time a monitor
# is attached or focus moves to a monitor that already has every bound
# workspace taken elsewhere.
#
# Wired from aerospace.toml's after-startup-command, on-focused-monitor-changed,
# and the service-mode `n` binding. Absolute path required in all three -
# exec-and-forget inherits AeroSpace's launchd environment, whose PATH is
# /usr/bin:/bin:/usr/sbin:/sbin, so a bare `aerospace` is silently not found.
# Same truncated-GUI-PATH class of bug that window-picker.sh documents.
#
# Known gap: AeroSpace has no monitor-hotplug event (`subscribe` only exposes
# focus-changed, focused-monitor-changed, focused-workspace-changed,
# mode-changed, window-detected, binding-triggered), so a monitor docked
# mid-session can show a stray workspace until focus first lands on it - at
# which point on-focused-monitor-changed fires this script and heals it. Not
# worked around: that's the first thing you do with a new monitor anyway.

AEROSPACE=/opt/homebrew/bin/aerospace

LOCK=/tmp/.aerospace-normalize-workspaces.lock
mkdir "$LOCK" 2>/dev/null || exit 0
trap 'rmdir "$LOCK" 2>/dev/null' EXIT INT TERM

# Every workspace reachable from a ctrl-alt-* binding in aerospace.toml.
BOUND='1 2 3 4 5 6 7 8 9 10 A C D E G I M N O P Q S T U V W X Y Z'

in_bound() {
  for b in $BOUND; do
    [ "$b" = "$1" ] && return 0
  done
  return 1
}

visible=$("$AEROSPACE" list-workspaces --monitor all --visible --format '%{workspace}|%{monitor-id}')

strays=""
taken=""
while IFS='|' read -r ws mon; do
  [ -n "$ws" ] || continue
  taken="$taken $ws"
  in_bound "$ws" || strays="$strays $ws:$mon"
done <<EOF
$visible
EOF

# Common case: nothing stray. Exit here, having made exactly one CLI call.
[ -n "$strays" ] || exit 0

for entry in $strays; do
  stray=${entry%%:*}
  mon=${entry##*:}

  replacement=""
  # Prefer the workspace named after the monitor's own index - this is what
  # gives "monitor 1 -> ws 1, monitor 2 -> ws 2, ..." on a fresh dock - but
  # only if it's a 1-10 workspace and nobody else currently has it visible.
  case "$mon" in
    1|2|3|4|5|6|7|8|9|10)
      case " $taken " in
        *" $mon "*) ;;
        *) replacement=$mon ;;
      esac
      ;;
  esac

  if [ -z "$replacement" ]; then
    for n in 1 2 3 4 5 6 7 8 9 10; do
      case " $taken " in
        *" $n "*) ;;
        *) replacement=$n; break ;;
      esac
    done
  fi

  # No free 1-10 workspace anywhere - bail silently rather than clobber one.
  [ -n "$replacement" ] || continue

  taken="$taken $replacement"

  "$AEROSPACE" list-windows --workspace "$stray" --format '%{window-id}' |
    while IFS= read -r wid; do
      [ -n "$wid" ] || continue
      "$AEROSPACE" move-node-to-workspace --window-id "$wid" -- "$replacement"
    done

  # Does not move focus - moves the (now window-less) replacement workspace
  # onto the stray's monitor, so the stray itself is left empty, invisible,
  # and absent from persistent-workspaces, and AeroSpace drops it.
  "$AEROSPACE" move-workspace-to-monitor --workspace "$replacement" -- "$mon"
done
