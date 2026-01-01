#!/usr/bin/env bash

# non-interactive, status-only output
# Works on Debian, Arch, and macOS

set -e

core_packages=(
  git
  vim
  zsh
  curl
)

# Color variables
PURPLE='\033[0;35m'
YELLOW='\033[0;93m'
RESET='\033[0m'

# -----------------------------
# Installation functions
# -----------------------------

function install_debian() {
  echo -e "${PURPLE}Installing ${1} via apt${RESET}"
  sudo apt-get update -y
  sudo apt-get install -y "$1"
}

function install_arch() {
  echo -e "${PURPLE}Installing ${1} via pacman${RESET}"
  sudo pacman -S --noconfirm --needed "$1"
}

function install_macos() {
  echo -e "${PURPLE}Installing Xcode Command Line Tools${RESET}"
  # Only install if not already installed
  if ! xcode-select -p >/dev/null 2>&1; then
    # This command triggers the GUI installer
    xcode-select --install
  else
    echo -e "${YELLOW}Xcode Command Line Tools already installed, skipping${RESET}"
  fi
}

# Early termination for mac, mac is a bit special in the head, it doesn't play well with the programmatic way of doing this
if [[ "$(uname)" == "Darwin" ]]; then
  # On macOS, install Xcode CLT once and skip individual packages
  install_macos
  exit 0
fi



# -----------------------------
# Detect system and install
# -----------------------------

function multi_system_install() {
  app=$1
  
  
  if [ -f "/etc/arch-release" ] && command -v pacman >/dev/null 2>&1; then
    install_arch "$app"
  elif [ -f "/etc/debian_version" ] && command -v apt-get >/dev/null 2>&1; then
    install_debian "$app"
  else
    echo -e "${YELLOW}Skipping ${app}, unsupported system${RESET}"
  fi
}

# -----------------------------
# Main loop
# -----------------------------

for app in "${core_packages[@]}"; do
  if ! command -v "$app" >/dev/null 2>&1; then
    multi_system_install "$app"
  else
    echo -e "${YELLOW}${app} already installed, skipping${RESET}"
  fi
done

echo -e "${PURPLE}All packages processed${RESET}"
exit 0
