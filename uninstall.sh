#!/bin/bash

# Default installation directory
INSTALL_DIR="$HOME/local/bin"

# Check if review-this exists in the installation directory
if [ ! -f "$INSTALL_DIR/review-this" ]; then
    echo "review-this not found in $INSTALL_DIR"
    exit 1
fi

# Remove the script
rm "$INSTALL_DIR/review-this"

echo "review-this has been uninstalled successfully!"
echo "Note: The PATH entry in your shell configuration was not removed."
echo "You may want to manually remove the following line from your shell config:"
echo "export PATH=\"\$PATH:$INSTALL_DIR\""

