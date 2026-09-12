#!/usr/bin/env bash

echo "Configuring macOS for AeroSpace..."

# spans-displays = false means "Displays have separate Spaces" is ON. Turned
# on deliberately (hence the flag reading false) so native fullscreen (e.g.
# Chrome/Firefox video) stops blanking every monitor but the one that went
# fullscreen - AeroSpace's own guide documents that blanking as the
# consequence of spans-displays=true. Chrome has no non-native-fullscreen
# flag, so this is the only fix that covers it. Accepted trade-off:
# AeroSpace's guide also warns of "weird focus and performance issues" moving
# windows between monitors with separate Spaces on - if those show up, the
# fallback is to flip this back to true and rely on Firefox's
# full-screen-api.macos-native-full-screen=false pref instead (which leaves
# Chrome still broken, since it has no equivalent pref).
defaults write com.apple.spaces spans-displays -bool false

# Stop macOS reordering Spaces underneath AeroSpace.
defaults write com.apple.dock mru-spaces -bool false

# Disable the macOS "Invert colors" hotkey (symbolic hotkey 21, bound to
# ⌃⌥⌘8 by default) - it collides with aerospace.toml's ctrl-alt-cmd-8 summon
# binding. Explicit rather than relying on it already being off: a fresh
# install would still have it enabled.
defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 21 '{enabled = 0;}'

# Apply changes
killall Dock

echo "NOTE: log out and back in for spans-displays and the ⌃⌥⌘8 change to take effect."
echo "NOTE: grant Accessibility to AeroSpace in System Settings > Privacy & Security."
