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
    echo "❌ .env file not found at $ENV_FILE"
    echo ""
    echo "   Copy the example file:"
    echo "   cp $ENV_EXAMPLE $ENV_FILE"
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

