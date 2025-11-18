#!/bin/bash
set -e

# Load environment variables from root .env if it exists
if [ -f ".env" ]; then
    set -a
    source .env
    set +a
fi

# Load environment variables from .env.run if it exists (contains runtime secrets like tokens)
if [ -f ".devcontainer/.env.run" ]; then
    set -a
    source .devcontainer/.env.run
    set +a
fi

# Create workspace directory if it doesn't exist
if [ ! -d "/workspace" ]; then
    mkdir -p /workspace
fi

# Create logs directory for devcontainer/infrastructure logging (xdebug, etc.)
LOGS_DIR="$HOME/.devcontainer/logs"
mkdir -p "$LOGS_DIR"

# Ensure essential directories exist with correct permissions in the persistent home volume
mkdir -p "$HOME/.composer"
mkdir -p "$HOME/.config/gh"
chmod 755 "$HOME/.composer"
chmod 755 "$HOME/.config/gh"

# Update git exclude to prevent git-in-git issues
GIT_EXCLUDE_FILE="/workspace/../.git/info/exclude"
if [ -f "$GIT_EXCLUDE_FILE" ]; then
    if ! grep -q "^workspace/$" "$GIT_EXCLUDE_FILE"; then
        echo "workspace/" >> "$GIT_EXCLUDE_FILE"
    fi
fi

# Configure git to use GitHub CLI credentials and HTTPS URLs
git config --global 'credential.https://github.com.helper' '!gh auth git-credential' 2>/dev/null || true
git config --global url."https://github.com/".insteadOf git@github.com: 2>/dev/null || true
git config --global url."https://".insteadOf git:// 2>/dev/null || true
git config --global --add safe.directory /workspace

# Configure zsh scrollback
if [ -f "$HOME/.zshrc" ] && ! grep -q "scrollback" "$HOME/.zshrc"; then
    echo '' >> "$HOME/.zshrc"
    echo '# Increase scrollback buffer' >> "$HOME/.zshrc"
    echo "export HISTSIZE=500000" >> "$HOME/.zshrc"
    echo "export SAVEHIST=500000" >> "$HOME/.zshrc"
fi

# Setup fzf for zsh (if installed via Homebrew)
BREW_PREFIX="${BREW_PREFIX:-/home/linuxbrew/.linuxbrew}"
if [ -f "${BREW_PREFIX}/opt/fzf/shell/completion.zsh" ]; then
    # Source fzf completion and key bindings in zshrc if not already present
    if [ -f "$HOME/.zshrc" ] && ! grep -q "fzf/shell/completion.zsh" "$HOME/.zshrc"; then
        echo '' >> "$HOME/.zshrc"
        echo '# fzf' >> "$HOME/.zshrc"
        echo "[ -f ${BREW_PREFIX}/opt/fzf/shell/completion.zsh ] && source ${BREW_PREFIX}/opt/fzf/shell/completion.zsh" >> "$HOME/.zshrc"
        echo "[ -f ${BREW_PREFIX}/opt/fzf/shell/key-bindings.zsh ] && source ${BREW_PREFIX}/opt/fzf/shell/key-bindings.zsh" >> "$HOME/.zshrc"
    fi
fi

# Setup fnm (Fast Node Manager) for zsh
if command -v fnm &> /dev/null; then
    # Add fnm initialization to zshrc if not already present
    if [ -f "$HOME/.zshrc" ] && ! grep -q "fnm env" "$HOME/.zshrc"; then
        echo '' >> "$HOME/.zshrc"
        echo '# fnm (Fast Node Manager)' >> "$HOME/.zshrc"
        echo 'eval "$(fnm env --use-on-cd --shell zsh)"' >> "$HOME/.zshrc"
    fi
fi

# Fix ownership for Homebrew directories, installer gives uid/gid of 999 at this time
sudo chown -R vscode:vscode /home/linuxbrew /home/vscode/.cache

# Symlink PHP to standard location for compatibility. Batch uses this path in its shebang
if [ ! -L /usr/bin/php ] || [ "$(readlink -f /usr/bin/php)" != "/usr/local/bin/php" ]; then
    sudo ln -sf /usr/local/bin/php /usr/bin/php
fi

# Check for issues and collect warnings
WARNINGS=()
MISSING_AUTH=()

# Check SSH agent forwarding
if [ -z "$SSH_AUTH_SOCK" ] || [ ! -S "$SSH_AUTH_SOCK" ]; then
    WARNINGS+=("SSH agent forwarding not available")
fi

# Check GitHub CLI authentication status
# GITHUB_TOKEN from .env.run is automatically used by gh CLI if set
GH_AUTH_VALID=false

if gh auth status &>/dev/null; then
    GH_AUTH_VALID=true
else
    MISSING_AUTH+=("github-cli")
fi

# Configure Composer/Packagist authentication if credentials are available
COMPOSER_AUTH_DIR="$HOME/.composer"
COMPOSER_AUTH_FILE="$COMPOSER_AUTH_DIR/auth.json"
COMPOSER_AUTH_VALID=false

if [ -n "$PACKAGIST_USERNAME" ] && [ -n "$PACKAGIST_PASSWORD" ]; then
    echo "🔐 Configuring Composer Packagist authentication..."
    if composer config --global --auth http-basic.repo.packagist.com "$PACKAGIST_USERNAME" "$PACKAGIST_PASSWORD" 2>/dev/null; then
        if grep -q "repo.packagist.com" "$COMPOSER_AUTH_FILE" 2>/dev/null; then
            COMPOSER_AUTH_VALID=true
            echo "✅ Composer Packagist authentication configured successfully"
        else
            WARNINGS+=("Composer Packagist auth configuration completed but verification failed")
            MISSING_AUTH+=("packagist")
        fi
    else
        WARNINGS+=("Failed to configure Composer Packagist authentication")
        MISSING_AUTH+=("packagist")
    fi
fi

# Check Composer authentication status
if [ "$COMPOSER_AUTH_VALID" = false ]; then
    if [ -f "$COMPOSER_AUTH_FILE" ] && grep -q "repo.packagist.com" "$COMPOSER_AUTH_FILE" 2>/dev/null; then
        COMPOSER_AUTH_VALID=true
    else
        MISSING_AUTH+=("packagist")
    fi
fi

# Import host .npmrc if available, otherwise check existing npm authentication
NPMRC_FILE="$HOME/.npmrc"
# Check for host .npmrc in the mounted scripts directory
NPMRC_HOST_FILE="$HOME/.devcontainer/scripts/.npmrc.host"
NPM_AUTH_VALID=false

if [ -f "$NPMRC_HOST_FILE" ]; then
    echo "📦 Importing .npmrc from host..."
    cp "$NPMRC_HOST_FILE" "$NPMRC_FILE"
    chmod 600 "$NPMRC_FILE"
    echo "✅ Host .npmrc imported to container"
fi

# Check npm authentication
if [ -f "$NPMRC_FILE" ]; then
    if grep -q "@encodium:registry" "$NPMRC_FILE" 2>/dev/null && grep -q "npm.pkg.github.com" "$NPMRC_FILE" 2>/dev/null; then
        NPM_AUTH_VALID=true
    else
        WARNINGS+=(".npmrc found but GitHub Packages configuration not detected")
        MISSING_AUTH+=("npm")
    fi
else
    MISSING_AUTH+=("npm")
fi

# Display warnings if any
if [ ${#WARNINGS[@]} -gt 0 ]; then
    echo ""
    echo "⚠️  Warnings:"
    for warning in "${WARNINGS[@]}"; do
        echo "   - $warning"
    done
    echo ""
fi

# Display next steps (only if there are missing auth items)
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📋 Next Steps"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ ${#MISSING_AUTH[@]} -gt 0 ]; then
    echo ""
    echo "Authentication Setup:"
    for auth in "${MISSING_AUTH[@]}"; do
        case "$auth" in
            github-cli)
                echo "  • GitHub CLI: dc github-cli"
                echo "    Or run: gh auth login"
                ;;
            packagist)
                echo "  • Private Packagist: dc packagist-auth"
                echo "    Visit: https://packagist.com/orgs/encodium"
                ;;
            npm)
                echo "  • npm: dc npmrc"
                echo "    Uses GitHub token from gh auth"
                ;;
        esac
    done
fi
echo ""
echo "Repository Setup:"
echo "  • Clone repositories: dc clone-repos [repo1,repo2,...]"
echo "  • Link common repo: dc link-common"
echo ""
echo "You'll find code under /workspace and Cursor/VSCode will show all folders under /workspace as code directories in the IDE."
echo ""
echo "What to do next? The following commands will help you verify that everything is working."
echo "  • Test environment: dc test-env"
echo "  • Verify using tests in common repo that connect to services: cd /workspace/common && composer run test:src:feature"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
