#!/usr/bin/env bash

# stolen from Lissy93/dotfiles
# non-interactive, status-only output

set -e

core_packages=(
  git
  vim
  zsh
)

# Color variables
PURPLE='\033[0;35m'
YELLOW='\033[0;93m'
RESET='\033[0m'

function install_debian () {
  echo -e "${PURPLE}Installing ${1} via apt${RESET}"
  sudo apt-get update -y
  sudo apt-get install -y "$1"
}

function install_arch () {
  echo -e "${PURPLE}Installing ${1} via pacman${RESET}"
  sudo pacman -S --noconfirm --needed "$1"
}

function install_mac () {
  echo -e "${PURPLE}Installing ${1} via Homebrew${RESET}"
  brew install "$1"
}

function get_homebrew () {
  echo -e "${PURPLE}Installing Homebrew${RESET}"
  NONINTERACTIVE=1 /bin/bash -c \
    "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  export PATH=/opt/homebrew/bin:/usr/local/bin:$PATH
}

function multi_system_install () {
  app=$1

  if [ "$(uname -s)" = "Darwin" ]; then
    if ! command -v brew >/dev/null 2>&1; then
      get_homebrew
    fi
    install_mac "$app"

  elif [ -f "/etc/arch-release" ] && command -v pacman >/dev/null 2>&1; then
    install_arch "$app"

  elif [ -f "/etc/debian_version" ] && command -v apt-get >/dev/null 2>&1; then
    install_debian "$app"

  else
    echo -e "${YELLOW}Skipping ${app}, unsupported system${RESET}"
  fi
}

for app in "${core_packages[@]}"; do
  if ! command -v "$app" >/dev/null 2>&1; then
    multi_system_install "$app"
  else
    echo -e "${YELLOW}${app} already installed, skipping${RESET}"
  fi
done

echo -e "${PURPLE}All packages processed${RESET}"
exit 0
