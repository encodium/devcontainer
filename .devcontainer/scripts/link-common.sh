#!/bin/bash
set -e

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

# Use environment variable with default fallback
COMMON_REPO_PATH="${COMMON_REPO_PATH:-/workspace/common}"

echo "🔗 Setting up composer-link for common repo..."

# Check if common repo exists
if [ ! -d "$COMMON_REPO_PATH" ]; then
    echo "❌ ERROR: Common repo not found at $COMMON_REPO_PATH"
    echo "   Please ensure the 'common' repo is cloned or mounted in /workspace/common"
    exit 1
fi

# Check if common repo has composer.json
if [ ! -f "$COMMON_REPO_PATH/composer.json" ]; then
    echo "❌ ERROR: composer.json not found in common repo at $COMMON_REPO_PATH"
    echo "   The common repo must be a valid Composer package"
    exit 1
fi

# Get all repos in workspace (excluding common)
repos=()
for dir in /workspace/*; do
    if [ -d "$dir" ] && [ -d "$dir/.git" ] && [ "$(basename "$dir")" != "common" ]; then
        repos+=("$dir")
    fi
done

if [ ${#repos[@]} -eq 0 ]; then
    echo "⚠️  No other repositories found in /workspace to link"
    exit 0
fi

echo "Found ${#repos[@]} repository/repositories to link:"
for repo in "${repos[@]}"; do
    echo "  - $(basename "$repo")"
done

# Link common to each repo
for repo in "${repos[@]}"; do
    repo_name=$(basename "$repo")
    echo ""
    echo "📦 Linking common to $repo_name..."
    
    # Check if repo has composer.json
    if [ ! -f "$repo/composer.json" ]; then
        echo "⚠️  Skipping $repo_name: no composer.json found"
        continue
    fi
    
    # Change to repo directory and link common
    cd "$repo"
    
    if composer link "$COMMON_REPO_PATH"; then
        echo "✅ Successfully linked common to $repo_name"
    else
        echo "❌ ERROR: Failed to link common to $repo_name"
        echo "   Make sure composer-link plugin is installed: composer global require sandersander/composer-link"
        exit 1
    fi
done

echo ""
echo "✅ All repositories linked successfully!"


