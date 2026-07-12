#!/bin/sh
# install.sh - run all tool-*.sh installers in this directory (POSIX compliant).
# Cross-platform curl/script-based installs for tools with no brew/pacman formula.
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
for script in "$SCRIPT_DIR"/tool-*.sh; do
    [ -f "$script" ] || continue
    echo "Running $script..."
    sh "$script"
done
