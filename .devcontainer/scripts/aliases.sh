#!/bin/bash
# Shell aliases for connecting to devcontainer services

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

# Use environment variables with defaults
VALKEY_HOST="${VALKEY_HOST:-valkey}"
VALKEY_PORT="${VALKEY_PORT:-6379}"
MYSQL_HOST="${MYSQL_HOST:-mysql}"
MYSQL_PORT="${MYSQL_PORT:-3306}"
MYSQL_USER="${MYSQL_USER:-dev}"
MYSQL_PASSWORD="${MYSQL_PASSWORD:-dev}"
MYSQL_DATABASE="${MYSQL_DATABASE:-dev}"

# Valkey (Redis-compatible)
alias redis='redis-cli -h "${VALKEY_HOST}" -p "${VALKEY_PORT}"'

# MySQL
alias mysql='mysql -h "${MYSQL_HOST}" -P "${MYSQL_PORT}" -u "${MYSQL_USER}" -p"${MYSQL_PASSWORD}" "${MYSQL_DATABASE}"'

# AWS CLI with LocalStack endpoint
alias aws='AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test AWS_DEFAULT_REGION=us-east-1 aws --endpoint-url=http://localstack:4566'

# Kubectl shortcut
alias k='kubectl'

# Helper function to test service connectivity
test-services() {
    echo "Testing service connectivity..."
    
    echo -n "Valkey: "
    redis-cli -h "${VALKEY_HOST}" -p "${VALKEY_PORT}" ping 2>/dev/null && echo "✅" || echo "❌"
    
    echo -n "MySQL: "
    mysql -h "${MYSQL_HOST}" -P "${MYSQL_PORT}" -u "${MYSQL_USER}" -p"${MYSQL_PASSWORD}" -e "SELECT 1;" "${MYSQL_DATABASE}" 2>/dev/null && echo "✅" || echo "❌"
    
    echo -n "LocalStack: "
    curl -s http://localstack:4566/_localstack/health > /dev/null 2>&1 && echo "✅" || echo "❌"
}


