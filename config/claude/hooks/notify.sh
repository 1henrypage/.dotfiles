#!/bin/bash
if [[ "$OSTYPE" == "darwin"* ]]; then
  osascript -e 'display notification "Claude Code needs your attention" with title "Claude Code"'
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
  notify-send "Claude Code" "Claude Code needs your attention"
elif [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" ]]; then
  powershell -Command "Add-Type –AssemblyName System.Windows.Forms; [System.Windows.Forms.MessageBox]::Show('Claude Code needs your attention', 'Claude Code')"
fi
