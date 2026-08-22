#!/bin/sh
# install.sh - run all macos-*.sh scripts under common/ (always) and personal/ (only when
# DOTFILES_PROFILE=personal). POSIX compliant.

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
FAILED=0

run_dir() {
    dir="$1"
    for script in "$dir"/macos-*.sh; do
        # Skip if no files match
        [ -f "$script" ] || continue
        echo "Running $script..."
        if ! sh "$script"; then
            echo "Failed: $script" >&2
            FAILED=$((FAILED + 1))
        fi
    done
}

run_dir "$SCRIPT_DIR/common"
if [ "$DOTFILES_PROFILE" = "personal" ]; then
    run_dir "$SCRIPT_DIR/personal"
fi

exit $FAILED
