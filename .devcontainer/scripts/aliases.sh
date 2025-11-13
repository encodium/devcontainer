#!/bin/bash
# Shell aliases for connecting to devcontainer services

# Load environment variables from root .env if it exists
if [ -f ".env" ]; then
    set -a
    source .env
    set +a
fi

# Use environment variables with defaults
REDIS_HOST="${REDIS_HOST:-redis}"
MYSQL_HOST="${MYSQL_HOST:-mysql}"
MYSQL_USER="${MYSQL_USER:-dev}"
MYSQL_PASSWORD="${MYSQL_PASSWORD:-dev}"
MYSQL_DATABASE="${MYSQL_DATABASE:-dev}"

# Redis (Valkey) - uses standard port 6379 inside container
alias redis='redis-cli -h "${REDIS_HOST}" -p 6379'

# MySQL - uses standard port 3306 inside container
alias mysql='mysql -h "${MYSQL_HOST}" -P 3306 -u "${MYSQL_USER}" -p"${MYSQL_PASSWORD}" "${MYSQL_DATABASE}"'

# AWS CLI with LocalStack endpoint
alias awslocal='AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test AWS_DEFAULT_REGION=us-east-1 aws --endpoint-url=http://localstack:4566'

# Kubectl shortcut
alias k='kubectl'

# Helper function to test service connectivity
test-services() {
    echo "Testing service connectivity..."
    
    echo -n "Redis: "
    if redis-cli -h "${REDIS_HOST}" -p "${REDIS_PORT}" ping &>/dev/null; then
        echo "✅"
    else
        echo "❌"
    fi
    
    echo -n "MySQL: "
    if mysql -e "SELECT 1;" &>/dev/null; then
        echo "✅"
    else
        echo "❌"
    fi
    
    echo -n "LocalStack: "
    if curl -sf http://localstack:4566/_localstack/health | grep -q '"services":' 2>/dev/null; then
        echo "✅"
    else
        echo "❌"
    fi
}


