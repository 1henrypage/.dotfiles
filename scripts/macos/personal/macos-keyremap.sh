#!/bin/sh
# Swap the physical key left of 1 (printed ^ / °) with the physical key left of Y (printed < / >)
# on this machine's German QWERTZ ISO built-in keyboard, via hidutil - first-party Apple binary,
# no cask, no system extension, no sudo. Personal profile only: this assumes ISO hardware, and on
# an ANSI keyboard the key left of 1 is the only source of `/~, so this swap would make backtick
# untypeable there. Replaces Karabiner Elements.
#
# Querying the active ABC (US) input source directly via UCKeyTranslate (LMGetKbdType() = 92)
# shows vk 10 (kVK_ISO_Section, the key left of 1) already produces §/±, and vk 50
# (kVK_ANSI_Grave, the key left of Y) produces `/~ - both characters already exist in the layout,
# this is purely about which physical key reaches which keycode. HID usage 0x700000035
# (grave_accent_and_tilde) is what reaches vk 50, and 0x700000064 (non_us_backslash) is what
# reaches vk 10 on this ISO layout, so swapping those two usage codes swaps which physical key
# lands on which keycode. The swap is two-way (not a one-way remap of just one direction): a
# one-way map is many-to-one and either collapses both keys onto the same character or makes one
# of the two characters untypeable.
#
# Requires Input Monitoring permission (System Settings > Privacy & Security > Input Monitoring)
# for whatever process invokes this script - without it, hidutil silently *stores* the mapping
# (`hidutil property --get "UserKeyMapping"` looks correct) but does not actually rewrite key
# events, and there is no interactive prompt or error to signal that.

echo "Applying hidutil key remap..."
hidutil property --set '{"UserKeyMapping":[
  {"HIDKeyboardModifierMappingSrc":0x700000035,
   "HIDKeyboardModifierMappingDst":0x700000064},
  {"HIDKeyboardModifierMappingSrc":0x700000064,
   "HIDKeyboardModifierMappingDst":0x700000035}]}' >/dev/null
