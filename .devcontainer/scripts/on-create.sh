#!/bin/bash
set -e

# Load environment variables from root .env if it exists
if [ -f ".env" ]; then
    set -a
    source .env
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

# GitHub CLI authentication is available via ~/.github mount from host
# No additional setup needed - the mount provides authentication automatically

# Check GitHub CLI authentication
GH_CONFIG_DIR="$HOME/.config/gh"
GH_HOSTS_FILE="$GH_CONFIG_DIR/hosts.yml"
GH_AUTH_VALID=false

if [ -d "$GH_CONFIG_DIR" ] && [ -f "$GH_HOSTS_FILE" ]; then
    if gh auth status &>/dev/null; then
        GH_AUTH_VALID=true
    else
        WARNINGS+=("GitHub CLI config found but authentication is invalid or expired")
        MISSING_AUTH+=("github-cli")
    fi
else
    MISSING_AUTH+=("github-cli")
fi

# Check Composer authentication
COMPOSER_AUTH_DIR="$HOME/.composer"
COMPOSER_AUTH_FILE="$COMPOSER_AUTH_DIR/auth.json"
COMPOSER_AUTH_VALID=false

if [ -f "$COMPOSER_AUTH_FILE" ]; then
    if grep -q "repo.packagist.com" "$COMPOSER_AUTH_FILE" 2>/dev/null; then
        COMPOSER_AUTH_VALID=true
    else
        WARNINGS+=("Composer auth.json found but Private Packagist config not detected")
        MISSING_AUTH+=("packagist")
    fi
else
    MISSING_AUTH+=("packagist")
fi

# Check npm authentication
NPMRC_FILE="$HOME/.npmrc"
NPM_AUTH_VALID=false

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
echo "Verification:"
echo "  • Test environment: dc test-env"
echo "  • Verify using tests in common repo that connect to services: cd /workspace/common && composer run test:src:feature"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
