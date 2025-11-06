#!/bin/bash
set -e

echo "Installing composer-link plugin"

# Ensure composer is available
if ! command -v composer >/dev/null 2>&1; then
    echo "Error: composer not found in PATH"
    exit 1
fi

# Determine target user (vscode user for devcontainer)
TARGET_USER="${_REMOTE_USER:-vscode}"
TARGET_HOME="/home/${TARGET_USER}"

# Set HOME to target user's home so composer installs to the correct location
export HOME="${TARGET_HOME}"

# Ensure composer global directory exists
mkdir -p "${HOME}/.composer"

# Install composer-link plugin globally
composer global config --no-plugins allow-plugins.sandersander/composer-link true
composer global require sandersander/composer-link

# Verify installation
composer global show sandersander/composer-link || {
    echo "Failed to verify composer-link plugin installation"
    exit 1
}

echo "Composer link plugin installed successfully"

