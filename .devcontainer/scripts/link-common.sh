#!/bin/bash
# Link common repo to all workspace repositories using composer-link
# Usage: link-common

set -euo pipefail

# Load environment variables from root .env if it exists
if [ -f "/workspace/.env" ]; then
    set -a
    source /workspace/.env
    set +a
fi

# Use environment variable with default fallback
COMMON_REPO_PATH="${COMMON_REPO_PATH:-/workspace/common}"

echo "🔗 Linking common repo to workspace repositories..."
echo ""

# Check if composer-link plugin is available
if ! composer help link &>/dev/null; then
    echo "❌ ERROR: composer-link plugin not found"
    echo ""
    echo "   The composer-link plugin should be installed in the Dockerfile."
    echo "   If it's missing, install it with:"
    echo "      composer global require sandersander/composer-link"
    echo ""
    exit 1
fi

# Check if common repo exists
if [ ! -d "$COMMON_REPO_PATH" ]; then
    echo "❌ ERROR: Common repo not found at $COMMON_REPO_PATH"
    echo ""
    echo "   The common repo must be cloned first. Run:"
    echo "      clone-repos common"
    echo ""
    echo "   Or ensure the common repo exists at: $COMMON_REPO_PATH"
    exit 1
fi

# Check if common repo has composer.json
if [ ! -f "$COMMON_REPO_PATH/composer.json" ]; then
    echo "❌ ERROR: composer.json not found in common repo at $COMMON_REPO_PATH"
    echo ""
    echo "   The common repo must be a valid Composer package with a composer.json file."
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
    echo ""
    echo "   Clone some repositories first:"
    echo "      clone-repos batch"
    echo ""
    exit 0
fi

echo "Found ${#repos[@]} repository/repositories to link:"
for repo in "${repos[@]}"; do
    echo "  - $(basename "$repo")"
done
echo ""

# Link common to each repo
SUCCESS_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0

for repo in "${repos[@]}"; do
    repo_name=$(basename "$repo")
    echo "📦 Linking common to $repo_name..."
    
    # Check if repo has composer.json
    if [ ! -f "$repo/composer.json" ]; then
        echo "⚠️  Skipping $repo_name: no composer.json found"
        SKIP_COUNT=$((SKIP_COUNT + 1))
        echo ""
        continue
    fi
    
    # Check if already linked
    if [ -L "$repo/vendor/common" ] || [ -d "$repo/vendor/common" ]; then
        if [ -L "$repo/vendor/common" ] && [ "$(readlink -f "$repo/vendor/common")" = "$(readlink -f "$COMMON_REPO_PATH")" ]; then
            echo "✅ $repo_name already linked to common"
            SKIP_COUNT=$((SKIP_COUNT + 1))
            echo ""
            continue
        fi
    fi
    
    # Change to repo directory and link common
    cd "$repo"
    
    if composer link "$COMMON_REPO_PATH" 2>&1; then
        echo "✅ Successfully linked common to $repo_name"
        SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
    else
        echo "❌ Failed to link common to $repo_name"
        echo "   This may be due to:"
        echo "   - Composer dependency conflicts"
        echo "   - Missing composer.json or invalid configuration"
        echo "   - Permission issues"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
    echo ""
done

# Summary
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 Link Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "   Successfully linked: $SUCCESS_COUNT"
echo "   Already linked: $SKIP_COUNT"
echo "   Failed: $FAIL_COUNT"
echo ""

if [ $FAIL_COUNT -gt 0 ]; then
    echo "⚠️ Some repositories failed to link. Check the errors above."
    exit 1
elif [ $SUCCESS_COUNT -gt 0 ]; then
    echo "✅ All repositories linked successfully!"
fi
