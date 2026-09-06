#!/usr/bin/env bash

echo "Configuring macOS for AeroSpace..."

# AeroSpace manages monitors itself; separate Spaces per display prevents a
# workspace moving cleanly between them.
defaults write com.apple.spaces spans-displays -bool true

# Stop macOS reordering Spaces underneath AeroSpace.
defaults write com.apple.dock mru-spaces -bool false

# Apply changes
killall Dock

echo "NOTE: log out and back in for spans-displays to take effect."
echo "NOTE: grant Accessibility to AeroSpace in System Settings > Privacy & Security."
