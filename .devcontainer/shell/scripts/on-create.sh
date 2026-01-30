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
mkdir -p "$HOME/.aws"
mkdir -p "$HOME/.composer"
mkdir -p "$HOME/.config/gh"
chmod 755 "$HOME/.aws"
chmod 755 "$HOME/.composer"
chmod 755 "$HOME/.config/gh"

# Setup AWS CLI config as symlink (no secrets, avoids drift)
AWS_CONFIG_SOURCE="/devcontainer/config/aws-config"
if [ -f "$AWS_CONFIG_SOURCE" ]; then
    ln -sf "$AWS_CONFIG_SOURCE" "$HOME/.aws/config"
fi

# Setup AWS CLI credentials from template if not present (copy, may contain secrets)
AWS_CREDS_TEMPLATE="/devcontainer/config/aws-credentials.example"
if [ ! -f "$HOME/.aws/credentials" ] && [ -f "$AWS_CREDS_TEMPLATE" ]; then
    cp "$AWS_CREDS_TEMPLATE" "$HOME/.aws/credentials"
    chmod 600 "$HOME/.aws/credentials"
    echo "✅ AWS CLI credentials initialized from template"
fi

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
git config --global init.defaultBranch main

# Setup fnm and install Node.js if needed
BREW_PREFIX="${BREW_PREFIX:-/home/linuxbrew/.linuxbrew}"
if command -v fnm &> /dev/null; then
    eval "$(fnm env)"
    if ! fnm list | grep -q "lts-latest"; then
        echo "📦 Installing latest LTS Node.js via fnm..."
        fnm install --lts
        fnm default lts-latest
        echo "✅ Node.js $(node --version) installed and set as default"
    fi
    
    # Create symlinks for node/npm/npx in ~/.local/bin for non-interactive shells (e.g., MCP scripts)
    # These chain through fnm's default alias, so they update when you run `fnm default <version>`
    FNM_DEFAULT_BIN="$HOME/.local/share/fnm/aliases/default/bin"
    if [ -d "$FNM_DEFAULT_BIN" ]; then
        mkdir -p "$HOME/.local/bin"
        ln -sf "$FNM_DEFAULT_BIN/node" "$HOME/.local/bin/node"
        ln -sf "$FNM_DEFAULT_BIN/npm" "$HOME/.local/bin/npm"
        ln -sf "$FNM_DEFAULT_BIN/npx" "$HOME/.local/bin/npx"
    fi
fi

# Fix ownership for Homebrew directories
# Check UID/GID instead of username since cache mounts may create files with unmapped UIDs
# Only run chown if ownership is incorrect to avoid slow recursive operations
VSCODE_UID=$(id -u vscode 2>/dev/null || echo "")
VSCODE_GID=$(id -g vscode 2>/dev/null || echo "")

if [ -n "$VSCODE_UID" ] && [ -n "$VSCODE_GID" ]; then
    if [ -d "/home/linuxbrew" ]; then
        DIR_UID=$(stat -c "%u" /home/linuxbrew 2>/dev/null || stat -f "%u" /home/linuxbrew 2>/dev/null || echo "")
        DIR_GID=$(stat -c "%g" /home/linuxbrew 2>/dev/null || stat -f "%g" /home/linuxbrew 2>/dev/null || echo "")
        if [ "$DIR_UID" != "$VSCODE_UID" ] || [ "$DIR_GID" != "$VSCODE_GID" ]; then
            sudo chown -R vscode:vscode /home/linuxbrew
        fi
    fi
    if [ -d "/home/vscode/.cache" ]; then
        DIR_UID=$(stat -c "%u" /home/vscode/.cache 2>/dev/null || stat -f "%u" /home/vscode/.cache 2>/dev/null || echo "")
        DIR_GID=$(stat -c "%g" /home/vscode/.cache 2>/dev/null || stat -f "%g" /home/vscode/.cache 2>/dev/null || echo "")
        if [ "$DIR_UID" != "$VSCODE_UID" ] || [ "$DIR_GID" != "$VSCODE_GID" ]; then
            sudo chown -R vscode:vscode /home/vscode/.cache
        fi
    fi
fi

# Symlink PHP to standard location for compatibility. Batch uses this path in its shebang
if [ ! -L /usr/bin/php ] || [ "$(readlink -f /usr/bin/php)" != "/usr/local/bin/php" ]; then
    sudo ln -sf /usr/local/bin/php /usr/bin/php
fi

# Install Cursor CLI (agent command)
if ! command -v agent &> /dev/null; then
    echo "📦 Installing Cursor CLI..."
    curl https://cursor.com/install -fsS | bash
fi

# Install rp CLI from private GitHub repo (requires gh auth)
RP_CLI_BIN="$HOME/.local/bin/rp"
if gh auth status &>/dev/null; then
    # Check if rp needs updating by comparing versions
    LATEST_RP_VERSION=$(gh release view --repo encodium/rp-cli-zero --json tagName -q '.tagName' 2>/dev/null || echo "")
    CURRENT_RP_VERSION=""
    if [ -x "$RP_CLI_BIN" ]; then
        CURRENT_RP_VERSION=$("$RP_CLI_BIN" --version 2>/dev/null | head -1 || echo "")
    fi
    
    if [ -z "$CURRENT_RP_VERSION" ] || [ "$LATEST_RP_VERSION" != "$CURRENT_RP_VERSION" ]; then
        echo "📦 Installing rp CLI..."
        mkdir -p "$HOME/.local/bin"
        if gh release download --repo encodium/rp-cli-zero --pattern 'rp' --output "$RP_CLI_BIN" --clobber 2>/dev/null; then
            chmod +x "$RP_CLI_BIN"
            echo "✅ rp CLI installed ($LATEST_RP_VERSION)"
        else
            echo "⚠️  Failed to download rp CLI from encodium/rp-cli-zero"
        fi
    fi
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
    # Check if auth is already configured correctly to avoid slow composer config operations
    NEEDS_PACKAGIST_CONFIG=true
    if [ -f "$COMPOSER_AUTH_FILE" ]; then
        EXISTING_USERNAME=$(composer config --global http-basic.repo.packagist.com.username 2>/dev/null || echo "")
        if [ "$EXISTING_USERNAME" = "$PACKAGIST_USERNAME" ]; then
            NEEDS_PACKAGIST_CONFIG=false
        fi
    fi
    
    if [ "$NEEDS_PACKAGIST_CONFIG" = true ]; then
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
    else
        COMPOSER_AUTH_VALID=true
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
# Check for host .npmrc in the mounted config directory
NPMRC_HOST_FILE="/devcontainer/config/.npmrc.host"
NPM_AUTH_VALID=false

if [ -f "$NPMRC_HOST_FILE" ]; then
    # Only copy if files differ to avoid unnecessary file operations
    if [ ! -f "$NPMRC_FILE" ] || ! cmp -s "$NPMRC_HOST_FILE" "$NPMRC_FILE" 2>/dev/null; then
        echo "📦 Importing .npmrc from host..."
        cp "$NPMRC_HOST_FILE" "$NPMRC_FILE"
        chmod 600 "$NPMRC_FILE"
        echo "✅ Host .npmrc imported to container"
    fi
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
