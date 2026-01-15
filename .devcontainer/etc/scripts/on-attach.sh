#!/bin/bash
set -e

# Load environment variables from root .env if it exists
if [ -f ".env" ]; then
    set -a
    source .env
    set +a
fi

BREW_PREFIX="/home/linuxbrew/.linuxbrew"
SCRIPTS_DIR="$HOME/.devcontainer/etc/scripts"
ALIASES_FILE="$SCRIPTS_DIR/aliases.sh"
ZSHRC_RP="$HOME/.zshrc_rp"

# Generate managed zshrc file (regenerated each attach to pick up changes)
cat > "$ZSHRC_RP" << 'EOFZSHRC'
# Managed by devcontainer - do not edit directly
# This file is regenerated on container attach

# Scrollback buffer
export HISTSIZE=500000
export SAVEHIST=500000

# Homebrew
BREW_PREFIX="/home/linuxbrew/.linuxbrew"
test -d $BREW_PREFIX && eval "$($BREW_PREFIX/bin/brew shellenv)"
export HOMEBREW_NO_AUTO_UPDATE=1

# Homebrew mysql-client
export PATH="$BREW_PREFIX/opt/mysql-client/bin:$PATH"

# Devcontainer scripts
export PATH="$HOME/.devcontainer/etc/scripts:$PATH"

# Devcontainer aliases
[ -f "$HOME/.devcontainer/etc/scripts/aliases.sh" ] && source "$HOME/.devcontainer/etc/scripts/aliases.sh"

# fzf
[ -f $BREW_PREFIX/opt/fzf/shell/completion.zsh ] && source $BREW_PREFIX/opt/fzf/shell/completion.zsh
[ -f $BREW_PREFIX/opt/fzf/shell/key-bindings.zsh ] && source $BREW_PREFIX/opt/fzf/shell/key-bindings.zsh

# fnm (Fast Node Manager)
command -v fnm &> /dev/null && eval "$(fnm env --use-on-cd --shell zsh)"
EOFZSHRC

# Ensure .zshrc sources our managed file at the end
if [ -f "$HOME/.zshrc" ] && ! grep -q "zshrc_rp" "$HOME/.zshrc"; then
    echo '' >> "$HOME/.zshrc"
    echo '# Devcontainer managed config (keep at end of file)' >> "$HOME/.zshrc"
    echo '[ -f "$HOME/.zshrc_rp" ] && source "$HOME/.zshrc_rp"' >> "$HOME/.zshrc"
fi

# Configure environment for current session
if [ -f "${BREW_PREFIX}/bin/brew" ]; then
    eval "$("${BREW_PREFIX}/bin/brew" shellenv)"
fi
export PATH="${BREW_PREFIX}/opt/mysql-client/bin:$SCRIPTS_DIR:$PATH"
[ -f "$ALIASES_FILE" ] && source "$ALIASES_FILE"

# Check for issues
WARNINGS=()


if ! redis-cli -h "${REDIS_HOST}" -p "${REDIS_PORT}" ping &>/dev/null; then
    WARNINGS+=("Redis service not reachable")
fi

if ! MYSQL_PWD="${MYSQL_PASSWORD}" mysql -h "${MYSQL_HOST}" -P "${MYSQL_PORT}" -u "${MYSQL_USER}" -e "SELECT 1;" &>/dev/null; then
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
fi

# Display next steps
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📋 Quick Start"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Test environment connectivity:"
echo "  dc test-env"
echo ""
echo "Clone repositories:"
echo "  dc clone-repos batch,common,schema,webstore"
echo ""
echo "Run schema migrations:"
echo "  dc schema bootstrap"
echo ""
echo "Link with common repository:"
echo "  dc link-common"
echo ""
echo "Verify with tests that use all local services:"
echo "  cd /workspace/common && composer run test:src:feature"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
