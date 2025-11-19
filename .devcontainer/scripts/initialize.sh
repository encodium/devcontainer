#!/bin/bash
# Initialize command for devcontainer
# This script runs on the host machine before the container is created
# It checks for GitHub CLI installation and authentication, and .env file

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEVCONTAINER_DIR="$(dirname "$SCRIPT_DIR")"
ENV_FILE="$DEVCONTAINER_DIR/.env"
ENV_EXAMPLE="$DEVCONTAINER_DIR/.env.example"
ENV_RUN_FILE="$DEVCONTAINER_DIR/.env.run"

# Source shared functions
source "$SCRIPT_DIR/functions.sh"

# Check if .env file exists
if [ ! -f "$ENV_FILE" ]; then
    echo "⚠️ .env file not found at $ENV_FILE"
    echo "Copying the example/defaults .env file..."
    cp $ENV_EXAMPLE $ENV_FILE
    echo "✅ .env $ENV_FILE copied from $ENV_EXAMPLE"
    echo ""
fi

# Load .env file to get port variables
set -a
source "$ENV_FILE" 2>/dev/null || true
set +a

# Check if Docker is installed before proceeding
if ! command -v docker &> /dev/null; then
    echo "❌ Docker is not installed."
    echo ""
    echo "   Install it first. Check the README for installation instructions."
    exit 1
fi

# Check if there's already a devcontainer running with the same project name
ALL_CONTAINERS=$(docker ps --format "{{.Names}}" 2>/dev/null || true)
RUNNING_CONTAINERS=$(echo "$ALL_CONTAINERS" | grep "^${COMPOSE_PROJECT_NAME}-" || true)

if [ -n "$RUNNING_CONTAINERS" ]; then
    echo "❌ It appears a devcontainer is already running with the same project name. COMPOSE_PROJECT_NAME=${COMPOSE_PROJECT_NAME}"
    echo ""
    echo "   Running containers:"
    echo "$RUNNING_CONTAINERS" | sed 's/^/     /'
    echo ""
    echo "   To fix this:"
    echo "   1. Stop the existing devcontainer, or"
    echo "   2. Change COMPOSE_PROJECT_NAME in $ENV_FILE to a unique value (will create new, empty separate services like redis, mysql, localstack, etc. without shared data)"
    echo ""
    exit 1
fi


# Check if GitHub CLI is installed
if ! command -v gh &> /dev/null; then
    echo "❌ GitHub CLI (gh) is not installed."
    echo ""
    echo "   Install it first. Check the README for installation instructions."
    exit 1
fi

# Check if GitHub CLI is authenticated with retries (handles suspend/first launch scenarios)
# Retry up to 5 times over 5 seconds
if ! retry_with_backoff "gh auth status" 5 5; then
    echo "❌ GitHub CLI is not authenticated."
    echo ""
    echo "   This can happen after system suspend or on first launch."
    echo "   The credential store may not be accessible yet."
    echo ""
    echo "   Run: gh auth login"
    exit 1
fi

# Get token from gh CLI with retries (works with both config file and macOS keyring)
# Retry up to 5 times over 5 seconds
TOKEN=""
if ! retry_with_backoff "gh auth token" 5 5 "TOKEN"; then
    echo "❌ Failed to retrieve GitHub token from GitHub CLI."
    echo ""
    echo "   This can happen after system suspend or on first launch."
    echo "   The credential store may not be accessible yet."
    echo ""
    echo "   Run: gh auth login"
    exit 1
fi

# Verify token scopes using gh auth status
REQUIRED_SCOPES=("gist" "read:org" "repo")
MISSING_SCOPES=()

# Get scopes from gh auth status (with retries)
AUTH_STATUS=""
SCOPES_HEADER=""
if retry_with_backoff "gh auth status" 5 5; then
    AUTH_STATUS=$(gh auth status 2>&1 || true)
    SCOPES_HEADER=$(echo "$AUTH_STATUS" | grep -i "token scopes:" | sed 's/.*token scopes: *//i' | tr -d '\r\n' || echo "")
fi

if [ -z "$SCOPES_HEADER" ]; then
    echo "❌ Could not verify token scopes from gh auth status."
    echo ""
    echo "   Required scopes: ${REQUIRED_SCOPES[*]}"
    echo ""
    echo "   Run: gh auth refresh -s gist,read:org,repo"
    exit 1
fi

# Normalize scopes: remove spaces and convert to lowercase for comparison
SCOPES_NORMALIZED=$(echo "$SCOPES_HEADER" | tr ',' ' ' | tr '[:upper:]' '[:lower:]')

# Check each required scope
for scope in "${REQUIRED_SCOPES[@]}"; do
    if ! echo "$SCOPES_NORMALIZED" | grep -qw "$scope"; then
        MISSING_SCOPES+=("$scope")
    fi
done

if [ ${#MISSING_SCOPES[@]} -gt 0 ]; then
    echo "❌ GitHub token is missing required scopes."
    echo ""
    echo "   Required scopes: ${REQUIRED_SCOPES[*]}"
    echo "   Missing scopes: ${MISSING_SCOPES[*]}"
    echo "   Current scopes: $SCOPES_HEADER"
    echo ""
    echo "   Run: gh auth refresh -s gist,read:org,repo"
    exit 1
fi

# Write token to .env.run file for the container to use
set_env_var "$ENV_RUN_FILE" "GITHUB_TOKEN" "$TOKEN"

echo "✅ GitHub CLI is installed and authenticated."
if [ -n "$SCOPES_HEADER" ]; then
    echo "✅ Token scopes verified: $SCOPES_HEADER"
fi
echo "✅ Token prepared for container authentication."

# Check for Composer/Packagist authentication
if command -v composer &> /dev/null; then
    PACKAGIST_USERNAME=$(composer config --global http-basic.repo.packagist.com.username 2>/dev/null || echo "")
    PACKAGIST_PASSWORD=$(composer config --global http-basic.repo.packagist.com.password 2>/dev/null || echo "")
    
    if [ -n "$PACKAGIST_USERNAME" ] && [ -n "$PACKAGIST_PASSWORD" ]; then
        set_env_var "$ENV_RUN_FILE" "PACKAGIST_USERNAME" "$PACKAGIST_USERNAME"
        set_env_var "$ENV_RUN_FILE" "PACKAGIST_PASSWORD" "$PACKAGIST_PASSWORD"
        echo "✅ Packagist credentials prepared for container authentication."
    fi
fi

# Check for host .npmrc file and prepare it for container
HOST_NPMRC="${HOME}/.npmrc"
NPMRC_SCRIPTS_FILE="$DEVCONTAINER_DIR/scripts/.npmrc.host"
if [ -f "$HOST_NPMRC" ]; then
    cp "$HOST_NPMRC" "$NPMRC_SCRIPTS_FILE"
    chmod 600 "$NPMRC_SCRIPTS_FILE"
    echo "✅ Host .npmrc file prepared for container import."
fi

echo "✅ .env file found."

