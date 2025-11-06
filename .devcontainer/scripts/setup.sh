#!/bin/bash
set -e

echo "🚀 Starting devcontainer setup..."

# Load environment variables from root .env if it exists
if [ -f "/workspace/.env" ]; then
    set -a
    source /workspace/.env
    set +a
elif [ -f ".env" ]; then
    set -a
    source .env
    set +a
fi

# Set defaults
REPOS_TO_CLONE="${REPOS_TO_CLONE:-batch,common}"
COMPOSER_LINK_COMMON="${COMPOSER_LINK_COMMON:-true}"

# Create workspace directory if it doesn't exist
if [ ! -d "/workspace" ]; then
    mkdir -p /workspace
fi

# Update git exclude to prevent git-in-git issues
GIT_EXCLUDE_FILE="/workspace/../.git/info/exclude"
if [ -f "$GIT_EXCLUDE_FILE" ]; then
    if ! grep -q "^workspace/$" "$GIT_EXCLUDE_FILE"; then
        echo "workspace/" >> "$GIT_EXCLUDE_FILE"
        echo "✅ Updated .git/info/exclude to exclude workspace/"
    fi
fi

# Handle SSH agent forwarding
if [ -n "$SSH_AUTH_SOCK" ] && [ -S "$SSH_AUTH_SOCK" ]; then
    echo "✅ SSH agent forwarding available"
else
    echo "⚠️  SSH agent forwarding not available"
fi

# Handle auth configuration
# Check for mounted/copied configs from host, or use storage volume

# GitHub CLI auth
if [ -d "$HOME/.config/gh" ] && [ -f "$HOME/.config/gh/hosts.yml" ]; then
    echo "✅ GitHub CLI config found"
    gh auth status || {
        echo "⚠️  GitHub CLI not authenticated. Run 'gh auth login' when ready."
    }
else
    echo "⚠️  GitHub CLI not configured. You may need to run 'gh auth login'"
fi

# Composer auth (private Packagist)
if [ -f "$HOME/.composer/auth.json" ]; then
    echo "✅ Composer auth.json found"
elif [ -n "$COMPOSER_AUTH" ]; then
    echo "✅ Composer auth token found in environment"
else
    echo "⚠️  Composer auth not configured. Set COMPOSER_AUTH or create ~/.composer/auth.json"
fi

# npm auth
if [ -f "$HOME/.npmrc" ]; then
    echo "✅ npm config found"
elif [ -n "$NPM_TOKEN" ]; then
    echo "//registry.npmjs.org/:_authToken=${NPM_TOKEN}" > "$HOME/.npmrc"
    echo "✅ npm token configured from environment"
else
    echo "⚠️  npm auth not configured. Set NPM_TOKEN or create ~/.npmrc"
fi

# SSH keys
if [ -d "$HOME/.ssh" ] && [ "$(ls -A $HOME/.ssh 2>/dev/null)" ]; then
    echo "✅ SSH keys available"
fi

# Clone repos if not already present
IFS=',' read -ra REPOS <<< "$REPOS_TO_CLONE"
for repo in "${REPOS[@]}"; do
    repo=$(echo "$repo" | xargs) # trim whitespace
    repo_path="/workspace/$repo"
    
    if [ -d "$repo_path" ] && [ -d "$repo_path/.git" ]; then
        echo "✅ Repository '$repo' already exists at $repo_path"
    else
        echo "📦 Cloning repository: encodium/$repo"
        if gh repo clone "encodium/$repo" "$repo_path"; then
            echo "✅ Successfully cloned encodium/$repo"
        else
            echo "❌ Failed to clone encodium/$repo. Make sure you're authenticated with 'gh auth login'"
            exit 1
        fi
    fi
done

# Source aliases
ALIASES_FILE="/workspace/../.devcontainer/scripts/aliases.sh"
if [ -f "$ALIASES_FILE" ]; then
    source "$ALIASES_FILE"
    # Add to zshrc for persistence
    if [ -f "$HOME/.zshrc" ] && ! grep -q "aliases.sh" "$HOME/.zshrc"; then
        echo '' >> "$HOME/.zshrc"
        echo '# Devcontainer aliases' >> "$HOME/.zshrc"
        echo "source \"$ALIASES_FILE\"" >> "$HOME/.zshrc"
    fi
    echo "✅ Shell aliases configured"
fi

# Link common repo if enabled
LINK_SCRIPT="/workspace/../.devcontainer/scripts/link-common.sh"
if [ "$COMPOSER_LINK_COMMON" = "true" ]; then
    if [ -f "$LINK_SCRIPT" ]; then
        echo "🔗 Linking common repo..."
        bash "$LINK_SCRIPT" || {
            echo "❌ Failed to link common repo"
            exit 1
        }
    fi
fi

# Use environment variables with defaults for display
VALKEY_HOST="${VALKEY_HOST:-valkey}"
VALKEY_PORT="${VALKEY_PORT:-6379}"
MYSQL_HOST="${MYSQL_HOST:-mysql}"
MYSQL_PORT="${MYSQL_PORT:-3306}"
MYSQL_USER="${MYSQL_USER:-dev}"
MYSQL_PASSWORD="${MYSQL_PASSWORD:-dev}"
MYSQL_DATABASE="${MYSQL_DATABASE:-dev}"
LOCALSTACK_PORT="${LOCALSTACK_PORT:-4566}"

# Display service connection info
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📋 Service Connection Information"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Valkey (Redis):"
echo "  Host: ${VALKEY_HOST}"
echo "  Port: ${VALKEY_PORT}"
echo "  Command: redis-cli"
echo ""
echo "MySQL:"
echo "  Host: ${MYSQL_HOST}"
echo "  Port: ${MYSQL_PORT}"
echo "  User: ${MYSQL_USER}"
echo "  Password: ${MYSQL_PASSWORD}"
echo "  Database: ${MYSQL_DATABASE}"
echo "  Command: mysql-cli"
echo ""
echo "LocalStack (AWS Services):"
echo "  Endpoint: http://localstack:${LOCALSTACK_PORT}"
echo "  External: http://localhost:${LOCALSTACK_PORT}"
echo "  Services: S3, SQS, SNS"
echo "  Command: aws-cli"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Devcontainer setup complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
