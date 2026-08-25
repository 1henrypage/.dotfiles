#!/bin/sh
# Remap the non-US backslash key (left of Z on ISO keyboards) to backtick/tilde, via hidutil -
# first-party Apple binary, no cask, no system extension, no Input Monitoring prompt, no sudo.
# Replaces Karabiner Elements on both profiles.
#
# 0x700000064 = non_us_backslash, 0x700000035 = grave_accent_and_tilde (HID usage IDs).

echo "Applying hidutil key remap..."
hidutil property --set '{"UserKeyMapping":[
  {"HIDKeyboardModifierMappingSrc":0x700000064,
   "HIDKeyboardModifierMappingDst":0x700000035}]}' >/dev/null
