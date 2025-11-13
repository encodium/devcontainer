#!/bin/bash
set -e

# Load environment variables from root .env if it exists
if [ -f ".env" ]; then
    set -a
    source .env
    set +a
fi

# Configure Homebrew environment
BREW_PREFIX="/home/linuxbrew/.linuxbrew"
if [ -f "${BREW_PREFIX}/bin/brew" ]; then
    eval "$("${BREW_PREFIX}/bin/brew" shellenv)"
    # Add to shell configs for persistence
    for shell_config in "$HOME/.zshrc" "$HOME/.bashrc"; do
        if [ -f "$shell_config" ] && ! grep -q "brew shellenv" "$shell_config"; then
            echo '' >> "$shell_config"
            echo '# Homebrew' >> "$shell_config"
            echo "test -d ${BREW_PREFIX} && eval \"\$(${BREW_PREFIX}/bin/brew shellenv)\"" >> "$shell_config"
            echo 'export HOMEBREW_NO_AUTO_UPDATE=1' >> "$shell_config"
        fi
    done
fi

# Add mysql-client to PATH (installed via Homebrew)
if [ -d "${BREW_PREFIX}/opt/mysql-client/bin" ]; then
    export PATH="${BREW_PREFIX}/opt/mysql-client/bin:$PATH"
    # Add to shell configs for persistence
    for shell_config in "$HOME/.zshrc" "$HOME/.bashrc"; do
        if [ -f "$shell_config" ] && ! grep -q "mysql-client/bin" "$shell_config"; then
            echo '' >> "$shell_config"
            echo '# Homebrew mysql-client' >> "$shell_config"
            echo "export PATH=\"${BREW_PREFIX}/opt/mysql-client/bin:\$PATH\"" >> "$shell_config"
        fi
    done
fi

# Add devcontainer scripts to PATH
SCRIPTS_DIR="$HOME/.devcontainer/scripts"
if [ -d "$SCRIPTS_DIR" ]; then
    export PATH="$SCRIPTS_DIR:$PATH"
    # Add to shell configs for persistence
    for shell_config in "$HOME/.zshrc" "$HOME/.bashrc"; do
        if [ -f "$shell_config" ] && ! grep -q "\.devcontainer/scripts" "$shell_config"; then
            echo '' >> "$shell_config"
            echo '# Devcontainer scripts' >> "$shell_config"
            echo "export PATH=\"$SCRIPTS_DIR:\$PATH\"" >> "$shell_config"
        fi
    done
fi

# Source aliases
ALIASES_FILE="$HOME/.devcontainer/scripts/aliases.sh"
if [ -f "$ALIASES_FILE" ]; then
    source "$ALIASES_FILE"
    # Add to zshrc for persistence
    if [ -f "$HOME/.zshrc" ] && ! grep -q "aliases.sh" "$HOME/.zshrc"; then
        echo '' >> "$HOME/.zshrc"
        echo '# Devcontainer aliases' >> "$HOME/.zshrc"
        echo "source \"$ALIASES_FILE\"" >> "$HOME/.zshrc"
    fi
fi

# Check for issues
WARNINGS=()

# Check service connectivity (non-blocking, just warn)
REDIS_HOST="${REDIS_HOST:-redis}"
MYSQL_HOST="${MYSQL_HOST:-mysql}"
MYSQL_USER="${MYSQL_USER:-dev}"
MYSQL_PASSWORD="${MYSQL_PASSWORD:-dev}"
MYSQL_DATABASE="${MYSQL_DATABASE:-dev}"

if ! redis-cli -h "${REDIS_HOST}" -p 6379 ping &>/dev/null; then
    WARNINGS+=("Redis service not reachable")
fi

if ! MYSQL_PWD="${MYSQL_PASSWORD}" mysql -h "${MYSQL_HOST}" -P 3306 -u "${MYSQL_USER}" -e "SELECT 1;" "${MYSQL_DATABASE}" &>/dev/null; then
    WARNINGS+=("MySQL service not reachable")
fi

if ! curl -sf http://localstack:4566/_localstack/health | grep -q '"services":' 2>/dev/null; then
    WARNINGS+=("LocalStack service not reachable")
fi

# Display warnings if any
if [ ${#WARNINGS[@]} -gt 0 ]; then
    echo ""
    echo "⚠️  Warnings:"
    for warning in "${WARNINGS[@]}"; do
        echo "   - $warning"
    done
    echo ""
    echo "   Services may still be starting. Run 'test-services' to check connectivity."
    echo ""
fi

# Display quick reference
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📋 Quick Reference"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Available Commands:"
echo "  setup <command>     - Run setup functions (packagist-auth, npmrc, composer-link, github-cli)"
echo "  clone-repos         - Clone repositories configured in REPOS_TO_CLONE"
echo "  link-common         - Link common repo to all workspace repositories"
echo "  test-services       - Test connectivity to all services"
echo ""
echo "Available Aliases:"
echo "  redis               - Connect to Redis at ${REDIS_HOST}:6379"
echo "  mysql               - Connect to MySQL at ${MYSQL_HOST}:3306"
echo "  awslocal            - AWS CLI with LocalStack endpoint (http://localstack:4566)"
echo "  k                   - kubectl shortcut"
echo ""
echo "Service Connection Info:"
echo "  Redis:     ${REDIS_HOST}:6379 (internal Docker network) / localhost:${REDIS_EXTERNAL_PORT:-6379} (external host)"
echo "  MySQL:     ${MYSQL_HOST}:3306 (internal Docker network) / localhost:${MYSQL_EXTERNAL_PORT:-3306} (external host)"
echo "  LocalStack: http://localstack:4566 (internal Docker network) / http://localhost:${LOCALSTACK_EXTERNAL_PORT:-4566} (external host)"
echo ""
echo "For more information, see: ~/.devcontainer/README.md"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
