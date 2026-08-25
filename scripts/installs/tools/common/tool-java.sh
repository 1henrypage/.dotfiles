#!/bin/sh
# jenv is a version *switcher*, not an installer or a discoverer - it never scans for or
# downloads JDKs. The openjdk@NN formulae install them keg-only (never symlinked into
# /Library/Java/JavaVirtualMachines/), so without this, jenv initializes but `jenv versions`
# shows only `system` until each JDK is registered by hand with `jenv add`.
#
# Idempotent: `jenv add` on an already-registered JDK is a no-op.

echo "Registering installed JDKs with jenv..."

if ! command -v jenv >/dev/null 2>&1; then
    echo "Warning: jenv not found; skipping Java toolchain registration."
    exit 0
fi

if ! command -v brew >/dev/null 2>&1; then
    echo "Warning: brew not found; skipping Java toolchain registration."
    exit 0
fi

BREW_PREFIX=$(brew --prefix)
registered=0

for jdk in "$BREW_PREFIX"/opt/openjdk@*/libexec/openjdk.jdk/Contents/Home; do
    [ -d "$jdk" ] || continue
    echo "  jenv add $jdk"
    jenv add "$jdk"
    registered=$((registered + 1))
done

if [ "$registered" -eq 0 ]; then
    echo "Warning: no openjdk@* kegs found under $BREW_PREFIX/opt; nothing registered."
    exit 0
fi

if ! jenv global 21; then
    echo "Warning: jenv global 21 failed - is openjdk@21 installed?"
    exit 1
fi
