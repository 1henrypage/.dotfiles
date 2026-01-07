#!/usr/bin/env bash

echo "Configuring Dock..."

# Dock size
defaults write com.apple.dock tilesize -int 64

# Auto-hide Dock
defaults write com.apple.dock autohide -bool true

# Remove delay when showing Dock
defaults write com.apple.dock autohide-delay -float 0
defaults write com.apple.dock autohide-time-modifier -float 0.15

# Position Dock (left, bottom, right)
defaults write com.apple.dock orientation -string "bottom"

# Minimize windows into app icon
defaults write com.apple.dock minimize-to-application -bool true

# Show only open apps
defaults write com.apple.dock static-only -bool true

# Disable recent apps
defaults write com.apple.dock show-recents -bool false

# Apply changes
killall Dock
