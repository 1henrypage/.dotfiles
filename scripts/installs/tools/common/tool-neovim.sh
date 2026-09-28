#!/bin/sh
echo "Installing Neovim via bob..."
# bob = Neovim version manager. config/bob/config.toml (linked by dotbot, which runs before this)
# keeps its installs under ~/.local/share/bob, which config/zsh/.zshenv puts on PATH, and pins
# the version in config/nvim/nvim.version next to the plugin lockfile it was tested with.
curl -fsSL https://raw.githubusercontent.com/MordechaiHadad/bob/master/scripts/install.sh | bash
# bob refuses a configured downloads_location that does not exist yet.
mkdir -p "$HOME/.local/share/bob"
# The installer links bob into ~/.local/bin, which is not on PATH until the next login shell.
"$HOME/.local/bin/bob" sync
