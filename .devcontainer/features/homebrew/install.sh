#!/usr/bin/env bash
set -e

# Get options from environment variables (set by devcontainer features)
# Options are converted to uppercase: brewPrefix -> BREW_PREFIX, shallowClone -> SHALLOWCLONE
BREW_PREFIX="${BREW_PREFIX:-/home/linuxbrew/.linuxbrew}"
TARGET_USER="${_REMOTE_USER:-vscode}"

echo "Installing Homebrew..."
echo "Prefix: ${BREW_PREFIX}"
echo "Target user: ${TARGET_USER}"

# Ensure we're running as root
if [ "$(id -u)" -ne 0 ]; then
  echo "Error: Script must be run as root during container build"
  exit 1
fi

# Install build dependencies
echo "Installing build dependencies..."
apt-get update -y
apt-get install -y --no-install-recommends \
  build-essential \
  procps \
  curl \
  file \
  git

# Clean up apt cache
rm -rf /var/lib/apt/lists/*

# The official installer installs to /home/linuxbrew/.linuxbrew by default
# If we need a different prefix, we can set it, but the default is recommended
BREW_PREFIX="/home/linuxbrew/.linuxbrew"

# Ensure target user has sudo access (Homebrew installer needs it)
echo "Ensuring ${TARGET_USER} has sudo access..."
if ! grep -q "^${TARGET_USER}" /etc/sudoers.d/* 2>/dev/null && ! grep -q "^${TARGET_USER}" /etc/sudoers 2>/dev/null; then
  echo "${TARGET_USER} ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/${TARGET_USER}"
  chmod 0440 "/etc/sudoers.d/${TARGET_USER}"
fi

# Install Homebrew using the official installer
# See: https://github.com/Homebrew/install/#install-homebrew-on-macos-or-linux
echo "Installing Homebrew using official installer..."

# Set NONINTERACTIVE to avoid prompts during installation
# Run the installer as the target user
# The installer will use sudo internally to install to /home/linuxbrew/.linuxbrew
runuser -u "${TARGET_USER}" -- env NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || {
  echo "Error: Homebrew installation failed"
  exit 1
}

# Determine actual brew prefix (installer may have created it)
if [ -f "${BREW_PREFIX}/bin/brew" ]; then
  ACTUAL_BREW_PREFIX="${BREW_PREFIX}"
elif command -v brew >/dev/null 2>&1; then
  ACTUAL_BREW_PREFIX=$(brew --prefix 2>/dev/null || echo "${BREW_PREFIX}")
else
  ACTUAL_BREW_PREFIX="${BREW_PREFIX}"
fi

# Ensure ownership is correct after installation
echo "Ensuring ownership is set to ${TARGET_USER}..."
if [ -d "${ACTUAL_BREW_PREFIX}" ]; then
  chown -R "${TARGET_USER}:${TARGET_USER}" "${ACTUAL_BREW_PREFIX}"
fi

# Configure Homebrew shell environment for the target user
TARGET_HOME="/home/${TARGET_USER}"
if [ -d "${TARGET_HOME}" ]; then
  echo "Configuring shell environment for ${TARGET_USER}..."
  
  # Add to .bashrc
  BASHRC="${TARGET_HOME}/.bashrc"
  if [ -f "${BASHRC}" ]; then
    if ! grep -q "brew shellenv" "${BASHRC}"; then
      echo '' >> "${BASHRC}"
      echo '# Homebrew' >> "${BASHRC}"
      echo 'test -d ~/.linuxbrew && eval "$(~/.linuxbrew/bin/brew shellenv)"' >> "${BASHRC}"
      echo "test -d ${ACTUAL_BREW_PREFIX} && eval \"\$(${ACTUAL_BREW_PREFIX}/bin/brew shellenv)\"" >> "${BASHRC}"
    fi
  fi
  
  # Add to .zshrc
  ZSHRC="${TARGET_HOME}/.zshrc"
  if [ -f "${ZSHRC}" ]; then
    if ! grep -q "brew shellenv" "${ZSHRC}"; then
      echo '' >> "${ZSHRC}"
      echo '# Homebrew' >> "${ZSHRC}"
      echo 'test -d ~/.linuxbrew && eval "$(~/.linuxbrew/bin/brew shellenv)"' >> "${ZSHRC}"
      echo "test -d ${ACTUAL_BREW_PREFIX} && eval \"\$(${ACTUAL_BREW_PREFIX}/bin/brew shellenv)\"" >> "${ZSHRC}"
    fi
  fi
  
  # Disable auto-update (useful for containers/CI)
  if [ -f "${BASHRC}" ] && ! grep -q "HOMEBREW_NO_AUTO_UPDATE" "${BASHRC}"; then
    echo 'export HOMEBREW_NO_AUTO_UPDATE=1' >> "${BASHRC}"
  fi
  if [ -f "${ZSHRC}" ] && ! grep -q "HOMEBREW_NO_AUTO_UPDATE" "${ZSHRC}"; then
    echo 'export HOMEBREW_NO_AUTO_UPDATE=1' >> "${ZSHRC}"
  fi  
fi

# Verify installation
"${ACTUAL_BREW_PREFIX}/bin/brew" config || {
  echo "Warning: brew config check failed, but continuing..."
}

echo "Homebrew installed successfully at ${ACTUAL_BREW_PREFIX}"

