#!/bin/sh
echo "Installing no-mistakes..."

# Idempotency: skip if already installed
if command -v no-mistakes >/dev/null 2>&1; then
    echo "no-mistakes already installed at $(command -v no-mistakes)"
    exit 0
fi

# Dependency guards (needed at runtime for the push-gate; warn, don't hard-fail)
command -v git >/dev/null 2>&1 || echo "Warning: git not found; no-mistakes needs it."
command -v gh  >/dev/null 2>&1 || echo "Warning: gh not found; no-mistakes needs it for PRs."

# Force the symlink into ~/.local/bin (already on PATH via config/zsh/.zshenv:32) so the
# installer never falls back to /usr/local/bin and prompts for sudo.
: "${XDG_BIN_HOME:=$HOME/.local/bin}"
mkdir -p "$XDG_BIN_HOME"
export NO_MISTAKES_LINK_DIR="$XDG_BIN_HOME"

curl -fsSL https://raw.githubusercontent.com/kunchenguid/no-mistakes/main/docs/install.sh | sh

echo "no-mistakes installed. Run 'no-mistakes init' inside a repo to set up its gate."
