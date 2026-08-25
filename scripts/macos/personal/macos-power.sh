#!/usr/bin/env bash

echo "Configuring power management..."

# Disable Power Nap on battery
sudo pmset -b powernap 0

# Disable TCP Keep Alive (prevents network maintenance wakes during sleep)
sudo pmset -a tcpkeepalive 0

# Disable Wake on LAN on battery
sudo pmset -b womp 0

# Disable Bluetooth wake
sudo defaults write /Library/Preferences/com.apple.Bluetooth RemoteWake -bool NO
