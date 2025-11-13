#!/bin/bash
# Clone repositories configured in REPOS_TO_CLONE environment variable
# Usage: clone-repos [repo1,repo2,...]
# If no arguments provided, uses REPOS_TO_CLONE from .env or defaults to "batch,common"

set -euo pipefail

# Load environment variables from root .env if it exists
if [ -f "/workspace/.env" ]; then
    set -a
    source /workspace/.env
    set +a
fi

# Determine which repos to clone
if [ $# -gt 0 ]; then
    REPOS_TO_CLONE="$*"
else
    REPOS_TO_CLONE="${REPOS_TO_CLONE:-batch,common}"
fi

echo "📦 Cloning repositories..."
echo "   Configured repos: $REPOS_TO_CLONE"
echo ""

# Check GitHub CLI authentication
if ! gh auth status &>/dev/null; then
    echo "❌ ERROR: GitHub CLI authentication required to clone repositories"
    echo ""
    echo "   To configure GitHub CLI authentication:"
    echo "   1. Mount ~/.config/gh from host (if you have it configured on host), or"
    echo "   2. Run the following command:"
    echo "      gh auth login"
    echo ""
    exit 1
fi

# Ensure workspace directory exists
if [ ! -d "/workspace" ]; then
    mkdir -p /workspace
    echo "✅ Created /workspace directory"
fi

# Clone repos
IFS=',' read -ra REPOS <<< "$REPOS_TO_CLONE"
SUCCESS_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0

for repo in "${REPOS[@]}"; do
    repo=$(echo "$repo" | xargs) # trim whitespace
    if [ -z "$repo" ]; then
        continue
    fi
    
    repo_path="/workspace/$repo"
    
    if [ -d "$repo_path" ] && [ -d "$repo_path/.git" ]; then
        echo "✅ Repository '$repo' already exists at $repo_path"
        SKIP_COUNT=$((SKIP_COUNT + 1))
    else
        echo "📦 Cloning repository: encodium/$repo..."
        if gh repo clone "encodium/$repo" "$repo_path" 2>&1; then
            echo "✅ Successfully cloned encodium/$repo"
            SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
        else
            echo "❌ Failed to clone encodium/$repo"
            echo "   This may be due to:"
            echo "   - Repository doesn't exist or you don't have access"
            echo "   - GitHub CLI authentication issue (run 'gh auth login')"
            echo "   - Network connectivity issue"
            FAIL_COUNT=$((FAIL_COUNT + 1))
        fi
        echo ""
    fi
done

# Summary
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 Clone Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "   Successfully cloned: $SUCCESS_COUNT"
echo "   Already existed: $SKIP_COUNT"
echo "   Failed: $FAIL_COUNT"
echo ""

if [ $FAIL_COUNT -gt 0 ]; then
    echo "⚠️  Some repositories failed to clone. Check the errors above."
    echo "   You can retry cloning specific repos: clone-repos repo1,repo2"
    exit 1
elif [ $SUCCESS_COUNT -gt 0 ]; then
    echo "✅ All repositories cloned successfully!"
    echo ""
    echo "   Next step: Link common repo to other repositories:"
    echo "      link-common"
fi

