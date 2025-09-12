#!/bin/bash
# --- VAULT MODULE ---
# Usage: load_secret_vault <path> <key>
load_secret_vault() {
    local path="$1"
    local key="${2:-value}"
    
    # Check if vault CLI is available
    if ! command -v vault &> /dev/null; then
        echo "Error: HashiCorp Vault CLI not installed" >&2
        return 1
    fi
    
    # Check if vault is configured
    if [[ -z "$VAULT_ADDR" ]] && [[ -z "$VAULT_TOKEN" ]]; then
        echo "Error: Vault address or token not configured. Set VAULT_ADDR and VAULT_TOKEN" >&2
        return 1
    fi
    
    # Get secret (assuming KV v2)
    local secret_json
    secret_json=$(vault kv get -format=json "$path" 2>&1)
    local exit_code=$?
    
    if [[ $exit_code -ne 0 ]]; then
        echo "Error: Failed to get secret at path '$path': $secret_json" >&2
        return 1
    fi
    
    # Extract data
    local value
    if [[ "$key" == "value" ]]; then
        # Return entire data block as JSON
        value=$(echo "$secret_json" | jq -r '.data.data' 2>/dev/null)
    else
        # Return specific key from data
        value=$(echo "$secret_json" | jq -r ".data.data.\"$key\"" 2>/dev/null)
    fi
    
    if [[ -z "$value" ]] || [[ "$value" == "null" ]]; then
        echo "Error: Key '$key' not found in vault path '$path'" >&2
        return 1
    fi
    
    # Format as KEY=VALUE
    echo "${path//\//_}_${key}=$value"
}
