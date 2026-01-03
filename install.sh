#!/bin/sh

# Dotfiles Install Script: 1henrypage
# Clone/update dotfiles and setup symlink 
# Compatibility for macOS, arch will be supported in future.

# ---------- UTILITY --------------------
CYAN='\033[1;96m'
YELLOW='\033[1;93m'
RED='\033[1;31m'
GREEN='\033[0;32m'
PURPLE='\033[0;35m'
RESET='\033[0m'

make_banner() {
    text="$1"
    color="${2:-$CYAN}"
    len=$(echo "$text" | wc -c)
    line=""
    i=0
    while [ $i -lt $len ]; do
        line="$line─"
        i=$((i + 1))
    done
    printf "\n${color}╭${line}╮\n│ ${text} │\n╰${line}╯${RESET}\n"
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

terminate() {
    make_banner "Installation failed. Terminating..." "$RED"
    exit 1
}

system_verify() {
    pkg="$1"
    required="$2"
    if ! command_exists "$pkg"; then
        if [ "$required" = "true" ]; then
            echo "${RED}Error:${RESET} $pkg is not installed"
            terminate
        else
            echo "${YELLOW}Warning:${RESET} $pkg is not installed"
        fi
    fi
}

# ------------- VARS ---------------------------

ORIG_PWD=$(pwd)
SRC_DIR="$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd)"

cd "$SRC_DIR" || terminate

cleanup() {
  # Restore original wd
  cd "$ORIG_PWD" || exit 1
}

trap cleanup EXIT

# Load environment variables from zshenv
if [ -f "$SRC_DIR/config/zsh/.zshenv" ]; then
    . "$SRC_DIR/config/zsh/.zshenv" || terminate
fi

SYSTEM_TYPE=$(uname -s)
START_TIME=$(date +%s)
SYMLINK_FILE="${SYMLINK_FILE:-symlinks.yaml}"
DOTBOT_DIR="lib/dotbot"
DOTBOT_BIN="bin/dotbot"

# ---- PRE - SETUP
make_banner "1henrypage Setup" "$CYAN"

# Ensure XDG directories are set
: "${XDG_CONFIG_HOME:=$HOME/.config}"
: "${XDG_DATA_HOME:=$HOME/.local/share}"

# Verify required commands
system_verify git true
system_verify zsh false
system_verify vim false
system_verify nvim false
system_verify tmux false

echo "Updating dotfiles from remote..."
git pull origin main || terminate
git submodule update --recursive --remote --init

echo "Setting up symlinks..."
chmod +x "$DOTBOT_DIR/$DOTBOT_BIN"
"$DOTBOT_DIR/$DOTBOT_BIN" -d . -c "$SYMLINK_FILE"

# --- Install Packages ---
if [ "$SYSTEM_TYPE" = "Darwin" ]; then
    # macOS Homebrew
    if ! command_exists brew; then
        echo "Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        export PATH=/opt/homebrew/bin:$PATH
    fi
    if [ -f "$HOME/.Brewfile" ]; then
        echo "Updating Homebrew and installing packages..."
        brew update
        brew upgrade
        brew bundle --global --verbose
        brew cleanup
    fi


    
    echo "Running MacOS specific setup scripts"
    macos_script="$SRC_DIR/scripts/macos/install.sh"
    chmod +x "$macos_script" && "$macos_script"
# debian is shit, setup arch 
#elif [ -f "/etc/debian_version" ]; then
#    echo "Installing packages via apt..."
#    apt update && apt upgrade -y
#    if [ -f "$DOTFILES_DIR/scripts/installs/debian-apt.sh" ]; then
#        sh "$DOTFILES_DIR/scripts/installs/debian-apt.sh"
#    fi
fi

# --- POST INSTALL --- This is stuff that can't be installed via standard methods
# Ensure Rust default toolchain is stable (non-interactive)
if command_exists rustup; then
    echo "Setting Rust default toolchain to stable..."
    rustup default stable 
fi

# Neovim using 0.10.4
curl -fsSL https://raw.githubusercontent.com/MordechaiHadad/bob/master/scripts/install.sh | bash
bob use v0.11.5

# --- Apply Preferences ---
echo "Applying ZSH, Vim, TMUX plugins..."
[ -f "$XDG_DATA_HOME/tmux/tpm" ] && sh "$XDG_DATA_HOME/tmux/tpm/bin/install_plugins"
[ -x "$(command -v zsh)" ] && /bin/zsh -i -c "antigen update && antigen-apply"

# --- Finishing Up ---
# source "$HOME/.zshenv" 2>/dev/null

elapsed=$(( $(date +%s) - START_TIME ))
if [ $elapsed -gt 60 ]; then
    elapsed="$((elapsed / 60)) minutes"
else
    elapsed="$elapsed seconds"
fi

make_banner "✨ Dotfiles configured successfully in $elapsed" "$GREEN"
exit 0




