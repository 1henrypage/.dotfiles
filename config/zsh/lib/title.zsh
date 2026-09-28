#!/usr/bin/env zsh

# Reset the terminal title to the host name at every prompt.
#
# Load-bearing for nested tmux (see "Nested tmux" in config/tmux/tmux.conf): a remote tmux
# marks the title it sends with "tmux@<host>: ". When it detaches, the remote prompt clears the
# mark; when ssh exits, the local prompt does. Either way tmux's pane-title-changed hook fires
# and the local status bar and agentmux sidebar come back. %M, the full host name, is also
# tmux's default pane title, so nothing else changes visibly.
_title_reset() {
  print -Pn '\e]2;%M\a'
}

autoload -Uz add-zsh-hook
add-zsh-hook precmd _title_reset
