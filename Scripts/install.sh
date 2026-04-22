#!/usr/bin/env bash

################################################################################
# TymeHelper Install Script
#
# Builds TymeHelper in release mode and installs it to /usr/local/bin.
#
# Usage:
#   Scripts/install.sh              # Build and install
#   Scripts/install.sh --uninstall  # Remove from /usr/local/bin
################################################################################

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
INSTALL_PATH="/usr/local/bin/tymehelper"

if [[ "${1:-}" == "--uninstall" ]]; then
    if [ -f "$INSTALL_PATH" ]; then
        rm "$INSTALL_PATH"
        echo "Removed $INSTALL_PATH"
    else
        echo "tymehelper is not installed."
    fi
    exit 0
fi

echo "Building TymeHelper (release)..."
cd "$PROJECT_ROOT"
swift build -c release 2>&1 | tail -3

BINARY="$PROJECT_ROOT/.build/release/TymeHelper"

if [ ! -f "$BINARY" ]; then
    echo "Build failed — binary not found."
    exit 1
fi

echo "Installing to $INSTALL_PATH (may require sudo)..."
sudo cp "$BINARY" "$INSTALL_PATH"
sudo chmod +x "$INSTALL_PATH"

echo "Done. Run 'tymehelper' from any Xcode project directory."
