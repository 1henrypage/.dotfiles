#!/usr/bin/env bash

# Bootstrap script
# Purpose:
# 1. Install minimal system dependencies (git, etc.)
# 2. Clone dotfiles repo via SSH
# 3. Run install script

set -e

REPO_SSH="git@github.com:1henrypage/.dotfiles.git"
REPO_DIR="$HOME/.dotfiles"

PURPLE='\033[0;35m'
YELLOW='\033[0;93m'
GREEN='\033[0;32m'
RESET='\033[0m'

echo -e "${PURPLE}Bootstrapping system...${RESET}"

# ---- Step 1: Install prerequisites ----
echo -e "${PURPLE}Installing system prerequisites...${RESET}"

curl -fsSL \
  https://raw.githubusercontent.com/1henrypage/.dotfiles/main/scripts/installs/prerequisites.sh \
  | bash

# ---- Step 2: Verify SSH access to GitHub ----
echo -e "${PURPLE}Checking GitHub SSH access...${RESET}"

SSH_OUTPUT="$(ssh -T git@github.com 2>&1 || true)"

case "$SSH_OUTPUT" in
  *"successfully authenticated"*)
    echo -e "${GREEN}GitHub SSH authentication successful${RESET}"
    ;;
  *)
    echo -e "${YELLOW}Warning:${RESET} GitHub SSH authentication could not be verified."
    echo -e "${YELLOW}If cloning fails, ensure your public SSH key is added to GitHub.${RESET}"
    ;;
esac


# ---- Step 3: Clone repo via SSH ----
if [ -d "$REPO_DIR" ]; then
  echo -e "${YELLOW}Dotfiles repo already exists at $REPO_DIR, skipping clone${RESET}"
else
  echo -e "${PURPLE}Cloning dotfiles repository via SSH...${RESET}"
  git clone "$REPO_SSH" "$REPO_DIR"
fi

# ---- Step 4: Run install ----
echo -e "${PURPLE}Running install script...${RESET}"
cd "$REPO_DIR"
./install.sh

echo -e "${GREEN}Bootstrap complete${RESET}"
