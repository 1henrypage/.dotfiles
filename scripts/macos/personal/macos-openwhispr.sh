#!/usr/bin/env bash

echo "Installing OpenWhispr..."

set -e

# Config
REPO="OpenWhispr/openwhispr"
APP="OpenWhispr.app"
APPDIR="$HOME/Applications"

# Idempotency: skip if already installed
if [ -d "$APPDIR/$APP" ]; then
    echo "OpenWhispr already installed at $APPDIR/$APP"
    exit 0
fi

# Dependency guard: jq is required to parse the releases API
if ! command -v jq >/dev/null 2>&1; then
    echo "Warning: jq not found; skipping OpenWhispr install."
    exit 0
fi

# Arch detect: pick the matching .dmg asset
case "$(uname -m)" in
    arm64)
        # Apple Silicon: OpenWhispr-<ver>-arm64.dmg
        ARCH_TEST='(.name | test("arm64"))'
        ;;
    x86_64)
        # Intel: plain OpenWhispr-<ver>.dmg (no arm64, no .blockmap)
        ARCH_TEST='(.name | test("arm64") | not)'
        ;;
    *)
        echo "Unsupported architecture: $(uname -m); skipping OpenWhispr install."
        exit 0
        ;;
esac

# Resolve the download URL from the latest release
API="https://api.github.com/repos/$REPO/releases/latest"
URL=$(curl -fsSL "$API" | jq -r ".assets[] | select((.name | endswith(\".dmg\")) and $ARCH_TEST) | .browser_download_url" | head -n 1)

if [ -z "$URL" ]; then
    echo "Could not resolve OpenWhispr download URL; skipping."
    exit 0
fi

# Download to a temp dir, cleaning up on exit
TMPDIR=$(mktemp -d)
MOUNT=""
cleanup() {
    [ -n "$MOUNT" ] && hdiutil detach "$MOUNT" >/dev/null 2>&1 || true
    rm -rf "$TMPDIR"
}
trap cleanup EXIT

DMG="$TMPDIR/OpenWhispr.dmg"
echo "Downloading $URL"
curl -fsSL -o "$DMG" "$URL"

# Mount, copy the app, unmount (grab the /Volumes/... mount point from the last line)
MOUNT=$(hdiutil attach -nobrowse -readonly "$DMG" | grep '/Volumes/' | sed -n 's#.*\(/Volumes/.*\)#\1#p' | tail -n 1)
mkdir -p "$APPDIR"
cp -R "$MOUNT"/*.app "$APPDIR"/
hdiutil detach "$MOUNT" >/dev/null 2>&1
MOUNT=""

# De-quarantine so Gatekeeper doesn't block the unsigned app
xattr -dr com.apple.quarantine "$APPDIR/$APP"

echo "OpenWhispr installed to $APPDIR/$APP"
