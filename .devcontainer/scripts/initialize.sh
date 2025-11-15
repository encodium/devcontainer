#!/bin/bash
# Initialize command for devcontainer
# This script runs on the host machine before the container is created
# It checks for GitHub CLI installation and authentication, and .env file

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEVCONTAINER_DIR="$(dirname "$SCRIPT_DIR")"
ENV_FILE="$DEVCONTAINER_DIR/.env"
ENV_EXAMPLE="$DEVCONTAINER_DIR/.env.example"

# Check if .env file exists
if [ ! -f "$ENV_FILE" ]; then
    echo "⚠️ .env file not found at $ENV_FILE"
    echo ""
    echo "   Copying the example/defaults .env file..."
    echo ""
    cp $ENV_EXAMPLE $ENV_FILE
    echo "✅ .env $ENV_FILE copied from $ENV_EXAMPLE"
    echo ""
    exit 0
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

# Check if GitHub CLI is authenticated
if ! gh auth status &> /dev/null; then
    echo "❌ GitHub CLI is not authenticated."
    echo ""
    echo "   Run: gh auth login"
    exit 1
fi

echo "✅ GitHub CLI is installed and authenticated."
echo "✅ .env file found."

