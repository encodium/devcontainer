#!/bin/bash
set -e

# PACKAGES comes as a JSON array from devcontainer features
# Format: ["package1","package2","package3"]
PACKAGES="${PACKAGES:-[]}"

# Parse JSON array - remove brackets and quotes, split by comma
if [ "$PACKAGES" = "[]" ] || [ -z "$PACKAGES" ]; then
    echo "No packages specified, skipping installation"
    exit 0
fi

# Remove brackets and quotes, then split by comma
# Handle JSON array format: ["pkg1","pkg2"] -> pkg1 pkg2
PACKAGES_CLEAN=$(echo "$PACKAGES" | sed 's/\[//g' | sed 's/\]//g' | sed 's/"//g' | sed 's/,/ /g')

if [ -z "$PACKAGES_CLEAN" ]; then
    echo "No packages specified, skipping installation"
    exit 0
fi

echo "Installing Homebrew packages: ${PACKAGES}"

# Determine target user (vscode user for devcontainer)
TARGET_USER="${_REMOTE_USER:-vscode}"
TARGET_HOME="/home/${TARGET_USER}"

# If running as root, switch to target user
if [ "$(id -u)" -eq 0 ]; then
    if id -u "${TARGET_USER}" > /dev/null 2>&1; then
        # Run as target user with proper environment
        runuser -u "${TARGET_USER}" -- env HOME="${TARGET_HOME}" PACKAGES="${PACKAGES}" bash << 'EOF'
            set -e
            
            # Source Homebrew environment
            BREW_PREFIX="/home/linuxbrew/.linuxbrew"
            if [ -f "${BREW_PREFIX}/bin/brew" ]; then
                eval "$("${BREW_PREFIX}/bin/brew" shellenv)"
            elif [ -f "${HOME}/.linuxbrew/bin/brew" ]; then
                eval "$("${HOME}/.linuxbrew/bin/brew" shellenv)"
            fi
            
            # Ensure Homebrew is available
            if ! command -v brew >/dev/null 2>&1; then
                echo "Error: Homebrew not found. Ensure homebrew feature is installed first."
                exit 1
            fi
            
            # Parse packages
            PACKAGES_CLEAN=$(echo "$PACKAGES" | sed 's/\[//g' | sed 's/\]//g' | sed 's/"//g' | sed 's/,/ /g')
            
            # Install each package
            for package in $PACKAGES_CLEAN; do
                # Trim whitespace
                package=$(echo "${package}" | xargs)
                if [ -n "${package}" ]; then
                    echo "Installing ${package}..."
                    brew install "${package}" || {
                        echo "Warning: Failed to install ${package}, but continuing..."
                    }
                fi
            done
            
            echo "Homebrew packages installed successfully"
EOF
    else
        echo "Error: Target user ${TARGET_USER} does not exist"
        exit 1
    fi
else
    # Already running as target user
    # Source Homebrew environment
    BREW_PREFIX="/home/linuxbrew/.linuxbrew"
    if [ -f "${BREW_PREFIX}/bin/brew" ]; then
        eval "$("${BREW_PREFIX}/bin/brew" shellenv)"
    elif [ -f "${HOME}/.linuxbrew/bin/brew" ]; then
        eval "$("${HOME}/.linuxbrew/bin/brew" shellenv)"
    fi
    
    # Ensure Homebrew is available
    if ! command -v brew >/dev/null 2>&1; then
        echo "Error: Homebrew not found. Ensure homebrew feature is installed first."
        exit 1
    fi
    
    # Install each package
    for package in $PACKAGES_CLEAN; do
        # Trim whitespace
        package=$(echo "${package}" | xargs)
        if [ -n "${package}" ]; then
            echo "Installing ${package}..."
            brew install "${package}" || {
                echo "Warning: Failed to install ${package}, but continuing..."
            }
        fi
    done
    
    echo "Homebrew packages installed successfully"
fi

