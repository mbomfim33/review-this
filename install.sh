#!/bin/bash

INSTALL_DIR="/usr/local/bin"

# Create installation directory if it doesn't exist
if [ ! -d "$INSTALL_DIR" ]; then
    mkdir -p "$INSTALL_DIR"
fi

# Check if review-this is in the current directory
if [ ! -f "review-this" ]; then
    echo "Error: review-this script not found in current directory"
    exit 1
fi

# Copy the script to installation directory
sudo cp review-this "$INSTALL_DIR/review-this"
chmod +x "$INSTALL_DIR/review-this"

# Check if INSTALL_DIR is in PATH
if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
    echo "Adding $INSTALL_DIR to PATH in your shell configuration..."
    
    # Detect shell and update appropriate config file
    if [ -n "$ZSH_VERSION" ]; then
        SHELL_RC="$HOME/.zshrc"
    elif [ -n "$BASH_VERSION" ]; then
        SHELL_RC="$HOME/.bashrc"
    else
        echo "Warning: Unsupported shell. Please add $INSTALL_DIR to your PATH manually."
        SHELL_RC=""
    fi
    
    if [ -n "$SHELL_RC" ]; then
        echo "export PATH=\"\$PATH:$INSTALL_DIR\"" >> "$SHELL_RC"
        echo "Added $INSTALL_DIR to PATH in $SHELL_RC"
        echo "Please restart your shell or run: source $SHELL_RC"
    fi
fi

echo "review-this has been installed successfully!"
echo "You can now use 'review-this' from anywhere in your system."
