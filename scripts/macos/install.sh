#!/bin/sh
# install.sh - run all macos-*.sh scripts in the script's directory (POSIX compliant)

# Get the directory of this script
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

# Loop through all macos-*.sh scripts
for script in "$SCRIPT_DIR"/macos-*.sh; do
    # Skip if no files match
    [ -f "$script" ] || continue
    echo "Running $script..."
    sh "$script"
done
