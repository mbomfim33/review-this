#!/bin/bash

INSTALL_DIR="/usr/local/bin"

# Create installation directory if it doesn't exist
mkdir -p "$INSTALL_DIR"

# Check if review-this is in the current directory
if [ ! -f "review-this" ]; then
    echo "Error: review-this script not found in current directory"
    exit 1
fi

# Copy the script to installation directory
cp review-this "$INSTALL_DIR/review-this"
chmod +x "$INSTALL_DIR/review-this"

echo "review-this has been installed successfully!"
