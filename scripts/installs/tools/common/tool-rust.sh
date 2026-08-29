#!/bin/sh
echo "Installing Rust toolchain components..."
# rustup itself comes from scripts/installs/Brewfile.
rustup default stable
rustup component add rust-analyzer clippy rustfmt
