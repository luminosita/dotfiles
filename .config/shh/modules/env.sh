#!/bin/bash
# --- ENV MODULE ---
# Usage: load_secret_env <var_name>
load_secret_env() {
    local var_name="$1"
    
    if [[ -z "$var_name" ]]; then
        echo "Error: No variable name provided" >&2
        return 1
    fi
    
    if [[ -z "${!var_name}" ]]; then
        echo "Error: Environment variable '$var_name' is not set" >&2
        return 1
    fi
    
    echo "$var_name=${!var_name}"
}