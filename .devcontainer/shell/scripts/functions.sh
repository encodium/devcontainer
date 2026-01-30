#!/bin/bash
# Shared shell functions for devcontainer scripts
# Source this file in other scripts to use these functions

# Function to set or update an environment variable in a file
# Usage: set_env_var <file_path> <VAR_NAME> <VAR_VALUE>
set_env_var() {
    local file_path="$1"
    local var_name="$2"
    local var_value="$3"
    
    if [ -z "$file_path" ] || [ -z "$var_name" ] || [ -z "$var_value" ]; then
        return 1
    fi
    
    if [ -f "$file_path" ]; then
        if grep -q "^${var_name}=" "$file_path" 2>/dev/null; then
            # Update existing variable
            if sed -i.bak "s|^${var_name}=.*|${var_name}=${var_value}|" "$file_path" 2>/dev/null; then
                rm -f "${file_path}.bak"
            else
                # Fallback if sed -i doesn't work (e.g., on macOS)
                sed "s|^${var_name}=.*|${var_name}=${var_value}|" "$file_path" > "${file_path}.tmp" && mv "${file_path}.tmp" "$file_path"
            fi
        else
            # Append variable if it doesn't exist
            echo "${var_name}=${var_value}" >> "$file_path"
        fi
    else
        # Create new file with variable
        echo "${var_name}=${var_value}" > "$file_path"
    fi
    chmod 600 "$file_path"
}

# Retry function for commands that may fail temporarily (e.g., after suspend or on first launch)
# Usage: retry_with_backoff <command> <max_attempts> <total_seconds> [output_var]
# If output_var is provided, the command output will be captured in that variable
retry_with_backoff() {
    local cmd="$1"
    local max_attempts="$2"
    local total_seconds="$3"
    local output_var="$4"
    local attempt=1
    local result
    
    # Calculate delay between attempts (spread evenly over total_seconds)
    # Use integer division for simplicity - rounds down but close enough
    local delay=0
    if [ "$max_attempts" -gt 1 ]; then
        delay=$((total_seconds / (max_attempts - 1)))
    fi
    
    while [ $attempt -le $max_attempts ]; do
        if [ -n "$output_var" ]; then
            # Capture output
            result=$(eval "$cmd" 2>/dev/null)
            local exit_code=$?
            if [ $exit_code -eq 0 ] && [ -n "$result" ]; then
                eval "$output_var=\"\$result\""
                return 0
            fi
        else
            # Just check exit code
            if eval "$cmd" 2>/dev/null; then
                return 0
            fi
        fi
        
        if [ $attempt -lt $max_attempts ]; then
            sleep "$delay"
        fi
        attempt=$((attempt + 1))
    done
    
    return 1
}
