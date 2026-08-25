#!/bin/sh
echo "Installing Neovim via bob..."
# bob = neovim version manager (installs to $XDG_DATA_HOME/bob, on PATH via config/zsh/.zshenv:58).
curl -fsSL https://raw.githubusercontent.com/MordechaiHadad/bob/master/scripts/install.sh | bash
bob use v0.11.5
