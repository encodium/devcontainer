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
    echo "   Copying the example file..."
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

COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME:-devcontainer}"

# Function to check if a port is in use
check_port_in_use() {
    local port=$1
    # Try different methods to check if port is in use
    if command -v ss &> /dev/null; then
        ss -tuln 2>/dev/null | grep -q ":${port} " && return 0
    elif command -v lsof &> /dev/null; then
        lsof -i ":${port}" &>/dev/null && return 0
    elif command -v netstat &> /dev/null; then
        netstat -tuln 2>/dev/null | grep -q ":${port} " && return 0
    fi
    return 1
}

# Check all _EXTERNAL_ ports from .env file
PORT_CONFLICTS=()

# Check explicitly defined _EXTERNAL_ port variables
for var in REDIS_EXTERNAL_PORT MYSQL_EXTERNAL_PORT LOCALSTACK_EXTERNAL_PORT LOCALSTACK_EXTERNAL_PORT_RANGE_START LOCALSTACK_EXTERNAL_PORT_RANGE_END; do
    port_value="${!var}"
    if [[ -n "$port_value" ]] && [[ "$port_value" =~ ^[0-9]+$ ]]; then
        if check_port_in_use "$port_value"; then
            PORT_CONFLICTS+=("$var=$port_value")
        fi
    fi
done

# Also check for any other _EXTERNAL_ variables in the .env file
while IFS='=' read -r key value || [ -n "$key" ]; do
    # Remove any comments and whitespace
    key=$(echo "$key" | sed 's/#.*//' | xargs)
    value=$(echo "$value" | sed 's/#.*//' | xargs)
    
    # Skip empty lines and already processed variables
    [[ -z "$key" ]] && continue
    [[ "$key" == "REDIS_EXTERNAL_PORT" ]] && continue
    [[ "$key" == "MYSQL_EXTERNAL_PORT" ]] && continue
    [[ "$key" == "LOCALSTACK_EXTERNAL_PORT" ]] && continue
    [[ "$key" == "LOCALSTACK_EXTERNAL_PORT_RANGE_START" ]] && continue
    [[ "$key" == "LOCALSTACK_EXTERNAL_PORT_RANGE_END" ]] && continue
    
    # Check if this is an _EXTERNAL_ port variable
    if [[ "$key" == *"_EXTERNAL_"* ]] && [[ -n "$value" ]] && [[ "$value" =~ ^[0-9]+$ ]]; then
        if check_port_in_use "$value"; then
            PORT_CONFLICTS+=("$key=$value")
        fi
    fi
done < "$ENV_FILE"

# If there are port conflicts, report them
if [ ${#PORT_CONFLICTS[@]} -gt 0 ]; then
    echo "❌ The following external ports are already in use on your host machine:"
    echo ""
    for conflict in "${PORT_CONFLICTS[@]}"; do
        var_name="${conflict%%=*}"
        port_value="${conflict#*=}"
        echo "   - ${var_name}=${port_value}"
    done
    echo ""
    echo "   To fix this, update the following variables in $ENV_FILE:"
    for conflict in "${PORT_CONFLICTS[@]}"; do
        var_name="${conflict%%=*}"
        echo "     ${var_name}"
    done
    echo ""
    echo "   Suggested pattern: Increment the hundreds place of each port number."
    echo "   For example, if a port is 6379, change it to 6479"
    echo ""
    exit 1
fi

# Check if there's already a devcontainer running with the same project name
if command -v docker &> /dev/null; then
    # Check for running containers with this project name
    # Docker Compose prefixes container names with the project name (e.g., "projectname-shell-1")
    # We check for containers that start with the project name followed by a hyphen
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
else
    echo "❌ Docker is not installed."
    echo ""
    echo "   Install it first. Check the README for installation instructions."
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

