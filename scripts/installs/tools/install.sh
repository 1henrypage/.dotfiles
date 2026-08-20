#!/bin/sh
# install.sh - run all tool-*.sh installers under common/ (always) and personal/ (unless
# DOTFILES_PROFILE=corporate). Cross-platform curl/script-based installs for tools with no
# brew/pacman formula. POSIX compliant.

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
FAILED=0

run_dir() {
    dir="$1"
    for script in "$dir"/tool-*.sh; do
        [ -f "$script" ] || continue
        echo "Running $script..."
        if ! sh "$script"; then
            echo "Failed: $script" >&2
            FAILED=$((FAILED + 1))
        fi
    done
}

run_dir "$SCRIPT_DIR/common"
if [ "$DOTFILES_PROFILE" != "corporate" ]; then
    run_dir "$SCRIPT_DIR/personal"
fi

exit $FAILED
